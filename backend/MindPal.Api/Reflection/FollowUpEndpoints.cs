using System.Diagnostics;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using MindPal.Api.Consents;
using MindPal.Api.Data;

namespace MindPal.Api.Reflection;

public static class FollowUpEndpoints
{
    public static void MapFollowUp(this IEndpointRouteBuilder app) =>
        app.MapPost("/reflect/followup", FollowUp)
           .RequireAuthorization()
           .RequireRateLimiting("reflect")
           .WithTags("Reflection");

    private static IResult Problem(
        int status,
        string code,
        string title,
        string? detail = null,
        Dictionary<string, string[]>? errors = null)
    {
        var ext = new Dictionary<string, object?> { ["code"] = code };
        if (errors is not null) ext["errors"] = errors;
        return Results.Problem(statusCode: status, title: title, detail: detail, extensions: ext);
    }

    private static string LogModel(string model)
    {
        var name = FollowUpLimits.ModelPrefix + model;
        return name.Length > 40 ? name[..40] : name;
    }

    private static async Task<IResult> FollowUp(
        FollowUpRequest req,
        ClaimsPrincipal principal,
        MindPalDbContext db,
        IFollowUpEngine engine,
        IConfiguration config,
        CancellationToken ct)
    {
        // 1. Input and the 10-question rule (checked here, not only in the app).
        var issue = FollowUpRules.Validate(req, out var ctx);
        if (issue is not null || ctx is null)
        {
            issue ??= new FollowUpIssue(400, "validation_failed", "Validation failed.");
            return Problem(
                issue.Status,
                issue.Code,
                issue.Status == 409 ? "Question limit reached" : "Validation failed",
                issue.Message,
                issue.Status == 400
                    ? new Dictionary<string, string[]> { ["message"] = [issue.Message] }
                    : null);
        }

        if (!Guid.TryParse(principal.FindFirstValue("sub"), out var userId))
            return Problem(401, "invalid_token", "Token is invalid");

        // 2. Safety screening: high-risk text is never sent to the AI service.
        if (SafetyScreener.IsHighRisk(ctx.Message))
        {
            db.SafetyEvents.Add(new SafetyEvent { CreatedAt = DateTime.UtcNow });
            await db.SaveChangesAsync(ct);

            return Results.Ok(new
            {
                safety = true,
                reply = SafetyScreener.SupportMessage,
                suggestions = Array.Empty<string>(),
                questionsUsed = FollowUpRules.QuestionsUsed(ctx.History),
                questionsLeft = FollowUpLimits.MaxQuestions - FollowUpRules.QuestionsUsed(ctx.History)
            });
        }

        // 3. Consent (FR-17).
        var hasConsent = await db.Consents.AnyAsync(c =>
            c.UserId == userId &&
            c.Type == ConsentPolicy.AiProcessing &&
            c.RevokedAt == null,
            ct);

        if (!hasConsent)
        {
            return Problem(
                403,
                "consent_required",
                "Consent required",
                "Please allow AI reflections before using this feature.");
        }

        // 4. Per-user limits for follow-ups (separate from reflections).
        var model = config["Gemini:Model"] ?? "unknown";
        var now = DateTime.UtcNow;

        var recent = db.AiUsageLogs.Where(l =>
            l.UserId == userId &&
            l.Status != "rate_limited" &&
            l.Model.StartsWith(FollowUpLimits.ModelPrefix) &&
            l.CreatedAt >= now.AddDays(-1));

        var successes = recent.Where(l => l.Status == "success");
        var inDay = await successes.CountAsync(ct);
        var inHour = await successes.CountAsync(l => l.CreatedAt >= now.AddHours(-1), ct);
        var attemptsInHour = await recent.CountAsync(l => l.CreatedAt >= now.AddHours(-1), ct);

        if (FollowUpLimits.IsExceeded(inHour, inDay) ||
            FollowUpLimits.IsAttemptCapExceeded(attemptsInHour))
        {
            await ReflectionEndpoints.LogUsage(db, userId, LogModel(model), 0, "rate_limited", ct);

            return Problem(
                429,
                "ai_rate_limited",
                "Question limit reached for now",
                "You have asked a lot of questions in a short time. Please try again later.");
        }

        // 5. Ask the AI and record usage (metadata only, never text).
        var sw = Stopwatch.StartNew();
        try
        {
            var reply = await engine.AskAsync(ctx, ct);
            sw.Stop();

            await ReflectionEndpoints.LogUsage(
                db, userId, LogModel(reply.ModelUsed ?? model), sw.ElapsedMilliseconds, "success", ct);

            var used = FollowUpRules.QuestionsUsed(ctx.History) + 1;
            return Results.Ok(new
            {
                safety = false,
                reply = reply.Reply,
                suggestions = reply.Suggestions,
                questionsUsed = used,
                questionsLeft = FollowUpLimits.MaxQuestions - used
            });
        }
        catch (ReflectionException ex)
        {
            sw.Stop();
            await ReflectionEndpoints.LogUsage(db, userId, LogModel(model), sw.ElapsedMilliseconds, ex.Status, ct);

            return ex.Status == "timeout"
                ? Problem(504, "ai_timeout", "The AI service took too long", "Please try again.")
                : Problem(502, "ai_unavailable", "The AI service is unavailable", "Please try again.");
        }
    }
}

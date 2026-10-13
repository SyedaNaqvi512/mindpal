using System.Diagnostics;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using MindPal.Api.Data;

namespace MindPal.Api.Reflection;

public record ReflectRequest(string? Text);

public static class ReflectionEndpoints
{
    public static void MapReflection(this IEndpointRouteBuilder app) =>
        app.MapPost("/reflect", Reflect)
           .RequireAuthorization().RequireRateLimiting("reflect").WithTags("Reflection");

    private static IResult Problem(int status, string code, string title, string? detail = null,
        Dictionary<string, string[]>? errors = null)
    {
        var ext = new Dictionary<string, object?> { ["code"] = code };
        if (errors is not null) ext["errors"] = errors;
        return Results.Problem(statusCode: status, title: title, detail: detail, extensions: ext);
    }

    private static async Task<AiUsageLog> LogUsage(MindPalDbContext db, Guid userId, string model,
        long ms, string status, CancellationToken ct)
    {
        var log = new AiUsageLog
        {
            UserId = userId,
            CreatedAt = DateTime.UtcNow,
            Model = model.Length > 40 ? model[..40] : model,
            DurationMs = (int)Math.Min(ms, int.MaxValue),
            Status = status
        };
        db.AiUsageLogs.Add(log);
        await db.SaveChangesAsync(ct);   // only metadata is stored, never journal text
        return log;
    }

    private static async Task<IResult> Reflect(ReflectRequest req, ClaimsPrincipal principal,
        MindPalDbContext db, IReflectionEngine engine, IConfiguration config, CancellationToken ct)
    {
        // 1. Input validation
        var error = ReflectionInput.Validate(req.Text, out var text);
        if (error is not null)
            return Problem(400, "validation_failed", "Validation failed", error,
                new Dictionary<string, string[]> { ["text"] = [error] });

        if (!Guid.TryParse(principal.FindFirstValue("sub"), out var userId))
            return Problem(401, "invalid_token", "Token is invalid");

        // 2. Safety screening: high-risk text is never sent to the AI service
        if (SafetyScreener.IsHighRisk(text))
        {
            db.SafetyEvents.Add(new SafetyEvent { CreatedAt = DateTime.UtcNow });   // anonymous count
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { safety = true, reflection = SafetyScreener.SupportMessage });
        }

        // 3. Per-user AI limits (10 per hour, 30 per rolling day)
        var model = config["Gemini:Model"] ?? "unknown";
        var now = DateTime.UtcNow;
        var recent = db.AiUsageLogs.Where(l =>
            l.UserId == userId && l.Status != "rate_limited" && l.CreatedAt >= now.AddDays(-1));
        var inDay = await recent.CountAsync(ct);
        var inHour = await recent.CountAsync(l => l.CreatedAt >= now.AddHours(-1), ct);
        if (ReflectionLimits.IsExceeded(inHour, inDay))
        {
            await LogUsage(db, userId, model, 0, "rate_limited", ct);
            return Problem(429, "ai_rate_limited", "Reflection limit reached",
                $"You can request up to {ReflectionLimits.MaxPerHour} reflections per hour and {ReflectionLimits.MaxPerDay} per day. Please try again later.");
        }

        // 4. Core logic: ask the engine, validate its answer, record usage
        var sw = Stopwatch.StartNew();
        try
        {
            var result = await engine.ReflectAsync(text, ct);
            sw.Stop();
            var log = await LogUsage(db, userId, model, sw.ElapsedMilliseconds, "success", ct);
            return Results.Ok(new
            {
                reflectionId = log.Id,
                safety = false,
                reflection = result.ToText(),
                structured = result
            });
        }
        catch (ReflectionException ex)
        {
            sw.Stop();
            await LogUsage(db, userId, model, sw.ElapsedMilliseconds, ex.Status, ct);
            return ex.Status == "timeout"
                ? Problem(504, "ai_timeout", "The AI service took too long", "Please try again.")
                : Problem(502, "ai_unavailable", "The AI service is unavailable", "Please try again.");
        }
    }
}
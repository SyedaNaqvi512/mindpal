using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using MindPal.Api.Data;

namespace MindPal.Api.Reflection;

public record FeedbackRequest(string? Rating, string? ReasonCode);

// Rating rules (FR-24). They match the database check constraints.
public static class FeedbackRules
{
    public const string Helpful = "helpful";
    public const string NotHelpful = "not_helpful";

    public static readonly string[] Reasons =
        ["not_relevant", "too_generic", "felt_wrong", "too_long", "other"];

    // Returns an error message, or null when the rating is valid.
    public static string? Validate(string? rating, string? reason)
    {
        if (rating is not (Helpful or NotHelpful))
            return "Rating must be 'helpful' or 'not_helpful'.";

        if (string.IsNullOrWhiteSpace(reason)) return null;

        if (rating != NotHelpful)
            return "A reason can only be given for 'not_helpful'.";

        return Reasons.Contains(reason) ? null : "Unknown reason.";
    }
}

public static class FeedbackEndpoints
{
    public static void MapFeedback(this IEndpointRouteBuilder app) =>
        app.MapPost("/reflections/{id:guid}/feedback", Submit)
           .RequireAuthorization()
           .RequireRateLimiting("reflect")
           .WithTags("Reflection");

    private static IResult Problem(int status, string code, string title, string? detail = null) =>
        Results.Problem(
            statusCode: status,
            title: title,
            detail: detail,
            extensions: new Dictionary<string, object?> { ["code"] = code });

    // Stores only the rating and a reason category. The entry text is never sent here.
    private static async Task<IResult> Submit(
        Guid id,
        FeedbackRequest req,
        ClaimsPrincipal principal,
        MindPalDbContext db,
        CancellationToken ct)
    {
        if (!Guid.TryParse(principal.FindFirstValue("sub"), out var userId))
            return Problem(401, "invalid_token", "Token is invalid");

        var error = FeedbackRules.Validate(req.Rating, req.ReasonCode);
        if (error is not null)
            return Problem(400, "validation_failed", "Validation failed", error);

        var owns = await db.AiUsageLogs.AnyAsync(
            l => l.Id == id && l.UserId == userId && l.Status == "success", ct);
        if (!owns)
            return Problem(404, "not_found", "Reflection not found");

        var reason = string.IsNullOrWhiteSpace(req.ReasonCode) ? null : req.ReasonCode;

        var existing = await db.ReflectionFeedback.FirstOrDefaultAsync(
            f => f.UsageId == id && f.UserId == userId, ct);

        if (existing is null)
        {
            db.ReflectionFeedback.Add(new ReflectionFeedback
            {
                UserId = userId,
                UsageId = id,
                Rating = req.Rating!,
                ReasonCode = reason,
                CreatedAt = DateTime.UtcNow
            });
        }
        else
        {
            existing.Rating = req.Rating!;
            existing.ReasonCode = reason;
        }

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            // Two requests at once for the same reflection: ask the app to try again.
            return Problem(409, "conflict", "Please try again");
        }

        return Results.NoContent();
    }
}

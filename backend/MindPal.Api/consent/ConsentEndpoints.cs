using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using MindPal.Api.Data;
using Npgsql;

namespace MindPal.Api.Consents;

public record GrantConsentRequest(string? PolicyVersion);

public static class ConsentPolicy
{
    public const string AiProcessing = "ai_processing";

    // Bump this when the consent text changes. The app sends the version it showed.
    public const string CurrentVersion = "1.0";
}

public static class ConsentEndpoints
{
    public static void MapConsents(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/me/consents").RequireAuthorization().WithTags("Consent");

        g.MapGet("", GetConsents);
        g.MapPut("/ai_processing", Grant);
        g.MapDelete("/ai_processing", Revoke);
    }

    private static IResult Problem(int status, string code, string title,
        string? detail = null, Dictionary<string, string[]>? errors = null)
    {
        var ext = new Dictionary<string, object?> { ["code"] = code };
        if (errors is not null) ext["errors"] = errors;
        return Results.Problem(statusCode: status, title: title, detail: detail, extensions: ext);
    }

    private static object Shape(Consent? c) => new
    {
        type = ConsentPolicy.AiProcessing,
        granted = c is not null && c.RevokedAt is null,
        policyVersion = c?.PolicyVersion,
        grantedAt = c?.GrantedAt,
        revokedAt = c?.RevokedAt,
        currentPolicyVersion = ConsentPolicy.CurrentVersion
    };

    private static bool TryUser(ClaimsPrincipal p, out Guid id) =>
        Guid.TryParse(p.FindFirstValue("sub"), out id);

    private static async Task<IResult> GetConsents(
        ClaimsPrincipal principal, MindPalDbContext db, CancellationToken ct)
    {
        if (!TryUser(principal, out var userId))
            return Problem(401, "invalid_token", "Token is invalid");

        var latest = await db.Consents.AsNoTracking()
            .Where(c => c.UserId == userId && c.Type == ConsentPolicy.AiProcessing)
            .OrderByDescending(c => c.GrantedAt)
            .FirstOrDefaultAsync(ct);

        return Results.Ok(new { consents = new[] { Shape(latest) } });
    }

    private static async Task<IResult> Grant(
        GrantConsentRequest? req, ClaimsPrincipal principal, MindPalDbContext db, CancellationToken ct)
    {
        if (!TryUser(principal, out var userId))
            return Problem(401, "invalid_token", "Token is invalid");

        if (req?.PolicyVersion != ConsentPolicy.CurrentVersion)
        {
            const string msg = "Unknown policy version.";
            return Problem(400, "validation_failed", "Validation failed", msg,
                new Dictionary<string, string[]> { ["policyVersion"] = [msg] });
        }

        // Idempotent: an active consent is returned as it is.
        var active = await db.Consents.FirstOrDefaultAsync(c =>
            c.UserId == userId && c.Type == ConsentPolicy.AiProcessing && c.RevokedAt == null, ct);
        if (active is not null) return Results.Ok(Shape(active));

        var consent = new Consent
        {
            UserId = userId,
            Type = ConsentPolicy.AiProcessing,
            PolicyVersion = ConsentPolicy.CurrentVersion,
            GrantedAt = DateTime.UtcNow
        };
        db.Consents.Add(consent);

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: "23505" })
        {
            // Two requests at once: the other one won, so return the stored consent.
            db.Entry(consent).State = EntityState.Detached;
            var existing = await db.Consents.AsNoTracking().FirstOrDefaultAsync(c =>
                c.UserId == userId && c.Type == ConsentPolicy.AiProcessing && c.RevokedAt == null, ct);
            return Results.Ok(Shape(existing));
        }

        return Results.Ok(Shape(consent));
    }

    private static async Task<IResult> Revoke(
        ClaimsPrincipal principal, MindPalDbContext db, CancellationToken ct)
    {
        if (!TryUser(principal, out var userId))
            return Problem(401, "invalid_token", "Token is invalid");

        var now = DateTime.UtcNow;
        await db.Consents
            .Where(c => c.UserId == userId && c.Type == ConsentPolicy.AiProcessing && c.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(c => c.RevokedAt, now), ct);

        return Results.NoContent(); // idempotent
    }
}

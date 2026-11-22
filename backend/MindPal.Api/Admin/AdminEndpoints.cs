using Microsoft.EntityFrameworkCore;
using MindPal.Api.Data;
using MindPal.Api.Reflection;
using MindPal.Api.Services;

namespace MindPal.Api.Admin;

// Admin portal API (FR-54 to FR-61). Every route needs a signed-in admin
// (role claim) and is checked again against the database on each request,
// so a demoted or suspended admin loses access at once. Only counts and
// account facts are returned: never journal or reflection text.
public static class AdminEndpoints
{
    private static IResult Problem(int status, string code, string title) =>
        Results.Problem(
            statusCode: status,
            title: title,
            extensions: new Dictionary<string, object?> { ["code"] = code });

    public static void MapAdmin(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/admin")
            .RequireAuthorization("admin")
            .RequireRateLimiting("admin")
            .WithTags("Admin");

        g.AddEndpointFilter(async (ctx, next) =>
        {
            var http = ctx.HttpContext;
            var ok = Guid.TryParse(http.User.FindFirst("sub")?.Value, out var id);

            if (ok)
            {
                var db = http.RequestServices.GetRequiredService<MindPalDbContext>();
                ok = await db.Users.AsNoTracking().AnyAsync(
                    u => u.Id == id && u.Role == "admin" && u.Status == "active",
                    http.RequestAborted);
            }

            return ok ? await next(ctx) : Problem(403, "forbidden", "Admin access required");
        });

        g.MapGet("/overview", Overview);
        g.MapGet("/users", Users);
        g.MapPost("/users/{id:guid}/suspend", Suspend);
        g.MapPost("/users/{id:guid}/reactivate", Reactivate);
        g.MapPost("/users/{id:guid}/process-deletion", ProcessDeletion);
        g.MapGet("/ai-usage", AiUsage);
        g.MapGet("/safety", Safety);
        g.MapGet("/health", Health);
        g.MapGet("/feedback", Feedback);
        g.MapGet("/exercises", Exercises);

        // App side of FR-61: the phone reports only the exercise type.
        app.MapPost("/telemetry/exercise", ExerciseDone)
            .RequireAuthorization()
            .RequireRateLimiting("telemetry")
            .WithTags("Telemetry");
    }

    private static DateTime SinceUtc(int days, out DateOnly today)
    {
        today = AdminStats.KarachiToday(DateTime.UtcNow);
        return AdminStats.StartOfKarachiDayUtc(today.AddDays(-(days - 1)));
    }

    private static async Task<IResult> Overview(
        MindPalDbContext db, int? days, CancellationToken ct)
    {
        var n = AdminStats.ClampDays(days);
        var since = SinceUtc(n, out var today);

        var total = await db.Users.CountAsync(u => u.Role == "user", ct);
        var active = await db.Users.CountAsync(u => u.Role == "user" && u.Status == "active", ct);
        var suspended = await db.Users.CountAsync(u => u.Status == "suspended", ct);
        var pending = await db.Users.CountAsync(u => u.Status == "pending_deletion", ct);

        var created = await db.Users.AsNoTracking()
            .Where(u => u.Role == "user" && u.CreatedAt >= since)
            .Select(u => u.CreatedAt).ToListAsync(ct);

        var sinceDay = today.AddDays(-(n - 1));
        var activity = await db.UserActivityDays.AsNoTracking()
            .Where(a => a.ActivityDate >= sinceDay)
            .Select(a => a.ActivityDate).ToListAsync(ct);

        var dau = activity.GroupBy(d => d).ToDictionary(x => x.Key, x => x.Count());

        var reflections = await db.AiUsageLogs.AsNoTracking()
            .Where(a => a.Status == "success" && a.CreatedAt >= since)
            .Select(a => a.CreatedAt).ToListAsync(ct);

        return Results.Ok(new
        {
            days = n,
            totalUsers = total,
            activeUsers = active,
            suspendedUsers = suspended,
            pendingDeletion = pending,
            activeToday = dau.TryGetValue(today, out var t) ? t : 0,
            newRegistrations = AdminStats.Series(today, n, AdminStats.CountByDay(created)),
            dailyActiveUsers = AdminStats.Series(today, n, dau),
            reflectionsPerDay = AdminStats.Series(today, n, AdminStats.CountByDay(reflections))
        });
    }

    private static async Task<IResult> Users(
        MindPalDbContext db, string? search, int? page, int? pageSize, CancellationToken ct)
    {
        var term = AdminStats.SearchTerm(search);
        var (p, size) = AdminStats.ClampPage(page, pageSize);

        var q = db.Users.AsNoTracking().AsQueryable();
        if (term.Length > 0) q = q.Where(u => u.Email.ToLower().Contains(term));

        var total = await q.CountAsync(ct);
        var items = await q.OrderByDescending(u => u.CreatedAt)
            .Skip((p - 1) * size).Take(size)
            .Select(u => new
            {
                id = u.Id,
                email = u.Email,
                displayName = u.DisplayName,
                role = u.Role,
                status = u.Status,
                emailVerified = u.EmailVerified,
                createdAt = u.CreatedAt,
                deletionRequestedAt = u.DeletionRequestedAt
            })
            .ToListAsync(ct);

        return Results.Ok(new { total, page = p, pageSize = size, items });
    }

    private static Guid Actor(HttpContext http) =>
        Guid.TryParse(http.User.FindFirst("sub")?.Value, out var id) ? id : Guid.Empty;

    private static async Task<IResult> Suspend(
        Guid id, MindPalDbContext db, HttpContext http,
        ILogger<Program> log, CancellationToken ct)
    {
        var u = await db.Users.FirstOrDefaultAsync(x => x.Id == id, ct);
        if (u is null) return Problem(404, "not_found", "User not found");

        var actor = Actor(http);
        if (!AdminStats.CanSuspend(actor, u.Id, u.Role, u.Status))
            return Problem(409, "not_allowed", "This account cannot be suspended");

        var now = DateTime.UtcNow;
        u.Status = "suspended";
        u.UpdatedAt = now;
        await db.SaveChangesAsync(ct);

        // Sign the person out everywhere.
        await db.RefreshTokens
            .Where(t => t.UserId == id && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now), ct);

        log.LogInformation("Admin {Admin} suspended user {User}", actor, id);
        return Results.NoContent();
    }

    private static async Task<IResult> Reactivate(
        Guid id, MindPalDbContext db, HttpContext http,
        ILogger<Program> log, CancellationToken ct)
    {
        var u = await db.Users.FirstOrDefaultAsync(x => x.Id == id, ct);
        if (u is null) return Problem(404, "not_found", "User not found");
        if (!AdminStats.CanReactivate(u.Status))
            return Problem(409, "not_allowed", "This account is not suspended");

        u.Status = "active";
        u.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);

        log.LogInformation("Admin {Admin} reactivated user {User}", Actor(http), id);
        return Results.NoContent();
    }

    private static async Task<IResult> ProcessDeletion(
        Guid id, MindPalDbContext db, HttpContext http,
        ILogger<Program> log, CancellationToken ct)
    {
        var u = await db.Users.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id, ct);
        if (u is null) return Problem(404, "not_found", "User not found");
        if (!AdminStats.CanProcessDeletion(u.Role, u.Status))
            return Problem(409, "not_allowed", "No deletion request to process");

        await db.Users.Where(x => x.Id == id).ExecuteDeleteAsync(ct);

        log.LogInformation("Admin {Admin} processed deletion of user {User}", Actor(http), id);
        return Results.NoContent();
    }

    private static async Task<IResult> AiUsage(
        MindPalDbContext db, int? days, CancellationToken ct)
    {
        var n = AdminStats.ClampDays(days);
        var since = SinceUtc(n, out var today);

        var rows = await db.AiUsageLogs.AsNoTracking()
            .Where(a => a.CreatedAt >= since)
            .Select(a => new { a.CreatedAt, a.Status, a.DurationMs })
            .ToListAsync(ct);

        var ok = rows.Where(r => r.Status == "success").ToList();

        return Results.Ok(new
        {
            days = n,
            requests = rows.Count,
            successes = ok.Count,
            errors = rows.Count(r => r.Status is "error" or "timeout"),
            rateLimited = rows.Count(r => r.Status == "rate_limited"),
            averageMs = AdminStats.AverageMs(ok.Select(r => r.DurationMs)),
            requestsPerDay = AdminStats.Series(
                today, n, AdminStats.CountByDay(rows.Select(r => r.CreatedAt)))
        });
    }

    private static async Task<IResult> Safety(
        MindPalDbContext db, int? days, CancellationToken ct)
    {
        var n = AdminStats.ClampDays(days);
        var since = SinceUtc(n, out var today);

        var times = await db.SafetyEvents.AsNoTracking()
            .Where(e => e.CreatedAt >= since)
            .Select(e => e.CreatedAt).ToListAsync(ct);

        return Results.Ok(new
        {
            days = n,
            total = times.Count,
            perDay = AdminStats.Series(today, n, AdminStats.CountByDay(times))
        });
    }

    private static async Task<IResult> Health(
        MindPalDbContext db, CancellationToken ct)
    {
        bool dbOk;
        try { dbOk = await db.Database.CanConnectAsync(ct); }
        catch { dbOk = false; }

        var since = DateTime.UtcNow.AddHours(-24);
        var aiErrors = 0;
        var aiLimited = 0;

        if (dbOk)
        {
            aiErrors = await db.AiUsageLogs.CountAsync(
                a => a.CreatedAt >= since && (a.Status == "error" || a.Status == "timeout"), ct);
            aiLimited = await db.AiUsageLogs.CountAsync(
                a => a.CreatedAt >= since && a.Status == "rate_limited", ct);
        }

        return Results.Ok(new
        {
            api = "ok",
            database = dbOk ? "ok" : "down",
            serverErrors24h = ErrorCounter.CountSince(TimeSpan.FromHours(24)),
            aiErrors24h = aiErrors,
            aiRateLimited24h = aiLimited,
            serverTime = DateTime.UtcNow
        });
    }

    private static async Task<IResult> Feedback(
        MindPalDbContext db, CancellationToken ct)
    {
        var rows = await db.ReflectionFeedback.AsNoTracking()
            .Select(f => new { f.Rating, f.ReasonCode }).ToListAsync(ct);

        var helpful = rows.Count(r => r.Rating == "helpful");
        var not = rows.Count(r => r.Rating == "not_helpful");

        var reasons = rows
            .Where(r => r.Rating == "not_helpful" && !string.IsNullOrEmpty(r.ReasonCode))
            .GroupBy(r => r.ReasonCode!)
            .Select(x => new { reason = x.Key, count = x.Count() })
            .OrderByDescending(x => x.count)
            .ToList();

        return Results.Ok(new
        {
            total = rows.Count,
            helpful,
            notHelpful = not,
            helpfulPercent = AdminStats.Percent(helpful, rows.Count),
            reasons
        });
    }

    private static async Task<IResult> Exercises(
        MindPalDbContext db, CancellationToken ct)
    {
        var types = await db.ExerciseEvents.AsNoTracking()
            .Select(e => e.ExerciseType).ToListAsync(ct);

        var items = types.GroupBy(t => t)
            .Select(x => new { type = x.Key, count = x.Count() })
            .OrderByDescending(x => x.count)
            .ToList();

        return Results.Ok(new { total = types.Count, items });
    }

    public record ExerciseDto(string? Type);

    private static async Task<IResult> ExerciseDone(
        ExerciseDto dto, MindPalDbContext db, CancellationToken ct)
    {
        if (!AdminStats.IsKnownExercise(dto.Type))
            return Problem(400, "validation_failed", "Unknown exercise");

        db.ExerciseEvents.Add(new ExerciseEvent
        {
            ExerciseType = dto.Type!,
            CreatedAt = DateTime.UtcNow
        });
        await db.SaveChangesAsync(ct);
        return Results.NoContent();
    }
}
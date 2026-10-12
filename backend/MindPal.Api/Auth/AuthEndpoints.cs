using System.Security.Claims;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using MindPal.Api.Data;
using Npgsql;

namespace MindPal.Api.Auth;

public static class AuthEndpoints
{
    private const int MaxFailedLogins = 5;
    private static readonly TimeSpan LockDuration = TimeSpan.FromMinutes(15);
    private static readonly Regex EmailRegex = new(@"^[^@\s]+@[^@\s]+\.[^@\s]+$", RegexOptions.Compiled);

    public static void MapAuth(this IEndpointRouteBuilder app)
    {
        var auth = app.MapGroup("/auth").WithTags("Auth");
        auth.MapPost("/register", Register).RequireRateLimiting("register");
        auth.MapPost("/login", Login).RequireRateLimiting("auth");
        auth.MapPost("/refresh", Refresh).RequireRateLimiting("auth");
        auth.MapPost("/logout", Logout);

        app.MapGet("/me", Me).RequireAuthorization().WithTags("Auth");
    }

    // ---------- helpers ----------
    private static IResult Problem(int status, string code, string title, string? detail = null,
        Dictionary<string, string[]>? errors = null)
    {
        var ext = new Dictionary<string, object?> { ["code"] = code };
        if (errors is not null) ext["errors"] = errors;
        return Results.Problem(statusCode: status, title: title, detail: detail, extensions: ext);
    }

    private static UserDto ToDto(User u) => new(u.Id, u.DisplayName, u.AvatarId, u.Email, u.Role, u.EmailVerified);

    private static async Task<AuthResponse> IssueTokens(User user, MindPalDbContext db, TokenService tokens, CancellationToken ct)
    {
        var raw = TokenService.NewRefreshToken();
        var now = DateTime.UtcNow;
        db.RefreshTokens.Add(new RefreshToken
        {
            UserId = user.Id,
            TokenHash = TokenService.Hash(raw),
            CreatedAt = now,
            ExpiresAt = now.AddDays(tokens.RefreshDays)
        });
        await db.SaveChangesAsync(ct);
        return new AuthResponse(tokens.CreateAccessToken(user), tokens.AccessSeconds, raw, ToDto(user));
    }

    // Daily active users (SRS): one row per user per day, Asia/Karachi = UTC+5.
    private static async Task MarkActive(Guid userId, MindPalDbContext db, CancellationToken ct)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow.AddHours(5));
        if (!await db.UserActivityDays.AnyAsync(a => a.UserId == userId && a.ActivityDate == today, ct))
        {
            db.UserActivityDays.Add(new UserActivityDay { UserId = userId, ActivityDate = today });
            try { await db.SaveChangesAsync(ct); }
            catch (DbUpdateException) { /* another request inserted it first: fine */ }
        }
    }

    // ---------- POST /auth/register ----------
    private static async Task<IResult> Register(RegisterRequest req, MindPalDbContext db, TokenService tokens, CancellationToken ct)
    {
        var errors = new Dictionary<string, string[]>();
        var name = req.DisplayName?.Trim() ?? "";
        var email = req.Email?.Trim().ToLowerInvariant() ?? "";
        var password = req.Password ?? "";

        if (name.Length is < 1 or > 40) errors["displayName"] = ["Display name must be 1 to 40 characters."];
        if (email.Length is < 3 or > 254 || !EmailRegex.IsMatch(email)) errors["email"] = ["Enter a valid email address."];
        var pwError = PasswordHasher.Validate(password);
        if (pwError is not null) errors["password"] = [pwError];
        if (errors.Count > 0)
            return Problem(400, "validation_failed", "Validation failed", "One or more fields are invalid.", errors);

        if (await db.Users.AnyAsync(u => u.Email == email, ct))
            return Problem(409, "email_taken", "Email already registered");

        var now = DateTime.UtcNow;
        var user = new User
        {
            DisplayName = name,
            Email = email,
            PasswordHash = PasswordHasher.Hash(password),
            CreatedAt = now,
            UpdatedAt = now
        };
        db.Users.Add(user);
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: "23505" })
        {
            return Problem(409, "email_taken", "Email already registered");
        }

        await MarkActive(user.Id, db, ct);
        var result = await IssueTokens(user, db, tokens, ct);
        return Results.Created($"/me", result);
    }

    // ---------- POST /auth/login ----------
    private static async Task<IResult> Login(LoginRequest req, MindPalDbContext db, TokenService tokens, CancellationToken ct)
    {
        var email = req.Email?.Trim().ToLowerInvariant() ?? "";
        var password = req.Password ?? "";
        if (email.Length == 0 || password.Length == 0 || password.Length > 200)
            return Problem(400, "validation_failed", "Email and password are required");

        var invalid = () => Problem(401, "invalid_credentials", "Email or password is incorrect");

        var user = await db.Users.FirstOrDefaultAsync(u => u.Email == email, ct);
        if (user is null)
        {
            PasswordHasher.BurnTime(password);
            return invalid();
        }

        var now = DateTime.UtcNow;
        // Locked accounts get the same generic answer, so attackers cannot learn which emails exist.
        if (user.LockedUntil is not null && user.LockedUntil > now)
        {
            PasswordHasher.BurnTime(password);
            return invalid();
        }

        if (!PasswordHasher.Verify(password, user.PasswordHash))
        {
            user.FailedLoginCount++;
            if (user.FailedLoginCount >= MaxFailedLogins)
            {
                user.LockedUntil = now.Add(LockDuration);
                user.FailedLoginCount = 0;
            }
            user.UpdatedAt = now;
            await db.SaveChangesAsync(ct);
            return invalid();
        }

        if (user.Status == "suspended")
            return Problem(403, "account_suspended", "This account is suspended");

        user.FailedLoginCount = 0;
        user.LockedUntil = null;
        user.UpdatedAt = now;
        await db.SaveChangesAsync(ct);

        await MarkActive(user.Id, db, ct);
        return Results.Ok(await IssueTokens(user, db, tokens, ct));
    }

    // ---------- POST /auth/refresh (rotation + reuse detection) ----------
    private static async Task<IResult> Refresh(RefreshRequest req, MindPalDbContext db, TokenService tokens, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(req.RefreshToken))
            return Problem(400, "validation_failed", "Refresh token is required");

        var hash = TokenService.Hash(req.RefreshToken);
        var stored = await db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == hash, ct);
        var bad = () => Problem(401, "invalid_token", "Refresh token is invalid or expired");
        if (stored is null) return bad();

        var now = DateTime.UtcNow;
        if (stored.RevokedAt is not null)
        {
            // An old token was used again: assume theft and sign the user out everywhere.
            await db.RefreshTokens
                .Where(t => t.UserId == stored.UserId && t.RevokedAt == null)
                .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now), ct);
            return bad();
        }
        if (stored.ExpiresAt <= now) return bad();

        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == stored.UserId, ct);
        if (user is null || user.Status == "suspended") return bad();

        stored.RevokedAt = now;           // rotate: the old token can never be used again
        await db.SaveChangesAsync(ct);
        return Results.Ok(await IssueTokens(user, db, tokens, ct));
    }

    // ---------- POST /auth/logout ----------
    private static async Task<IResult> Logout(RefreshRequest req, MindPalDbContext db, CancellationToken ct)
    {
        if (!string.IsNullOrWhiteSpace(req.RefreshToken))
        {
            var hash = TokenService.Hash(req.RefreshToken);
            await db.RefreshTokens
                .Where(t => t.TokenHash == hash && t.RevokedAt == null)
                .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, DateTime.UtcNow), ct);
        }
        return Results.NoContent();   // always 204: never reveal whether the token existed
    }

    // ---------- GET /me ----------
    private static async Task<IResult> Me(ClaimsPrincipal principal, MindPalDbContext db, CancellationToken ct)
    {
        if (!Guid.TryParse(principal.FindFirstValue("sub"), out var id))
            return Problem(401, "invalid_token", "Token is invalid");
        var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == id, ct);
        return user is null ? Problem(401, "invalid_token", "Token is invalid") : Results.Ok(ToDto(user));
    }
}
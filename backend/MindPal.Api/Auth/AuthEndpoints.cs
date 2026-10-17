
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using MindPal.Api.Data;
using MindPal.Api.Email;
using Npgsql;

namespace MindPal.Api.Auth;

public static class AuthEndpoints
{
    private const int MaxFailedLogins = 5;
    private const int MaxFailedVerificationAttempts = 5;
    private const int MaxFailedPasswordResetAttempts = 5;

    private static readonly TimeSpan LockDuration =
        TimeSpan.FromMinutes(15);

    private static readonly TimeSpan VerificationCodeLifetime =
        TimeSpan.FromMinutes(10);

    private static readonly TimeSpan ResendCooldown =
        TimeSpan.FromSeconds(60);

    private static readonly Regex EmailRegex =
        new(@"^[^@\s]+@[^@\s]+\.[^@\s]+$", RegexOptions.Compiled);

    public static void MapAuth(this IEndpointRouteBuilder app)
    {
        var auth = app.MapGroup("/auth").WithTags("Auth");

        auth.MapPost("/register", Register)
            .RequireRateLimiting("register");

        auth.MapPost("/login", Login)
            .RequireRateLimiting("auth");

        auth.MapPost("/refresh", Refresh)
            .RequireRateLimiting("auth");

        auth.MapPost("/logout", Logout);

        auth.MapPost("/verify-email", VerifyEmail)
            .RequireRateLimiting("auth");

        auth.MapPost("/resend-verification", ResendVerification)
            .RequireRateLimiting("auth");

        auth.MapPost("/forgot-password", ForgotPassword)
            .RequireRateLimiting("auth");

        auth.MapPost("/reset-password", ResetPassword)
            .RequireRateLimiting("auth");

        app.MapGet("/me", Me)
            .RequireAuthorization()
            .WithTags("Auth");

        app.MapPatch("/me", UpdateMe)
            .RequireAuthorization()
            .WithTags("Auth");

        // FR-07: Change password for the authenticated user.
        app.MapPost("/me/password", ChangePassword)
            .RequireAuthorization()
            .RequireRateLimiting("auth")
            .WithTags("Auth");
    }

    // ---------- Helpers ----------

    private static IResult Problem(
        int status,
        string code,
        string title,
        string? detail = null,
        Dictionary<string, string[]>? errors = null)
    {
        var extensions = new Dictionary<string, object?>
        {
            ["code"] = code
        };

        if (errors is not null)
            extensions["errors"] = errors;

        return Results.Problem(
            statusCode: status,
            title: title,
            detail: detail,
            extensions: extensions);
    }

    private static UserDto ToDto(User user) =>
        new(
            user.Id,
            user.DisplayName,
            user.AvatarId,
            user.Email,
            user.Role,
            user.EmailVerified,
            user.Gender);

    private static async Task<AuthResponse> IssueTokens(
        User user,
        MindPalDbContext db,
        TokenService tokens,
        CancellationToken ct)
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

        return new AuthResponse(
            tokens.CreateAccessToken(user),
            tokens.AccessSeconds,
            raw,
            ToDto(user));
    }

    // Daily active users: Asia/Karachi = UTC+5.
    private static async Task MarkActive(
        Guid userId,
        MindPalDbContext db,
        CancellationToken ct)
    {
        var today = DateOnly.FromDateTime(
            DateTime.UtcNow.AddHours(5));

        if (!await db.UserActivityDays.AnyAsync(
                a => a.UserId == userId &&
                     a.ActivityDate == today,
                ct))
        {
            db.UserActivityDays.Add(new UserActivityDay
            {
                UserId = userId,
                ActivityDate = today
            });

            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                // Another request may have inserted the same user/day.
            }
        }
    }

    private static string GenerateVerificationCode() =>
        RandomNumberGenerator.GetInt32(0, 1_000_000)
            .ToString("D6");

    // Bind a verification code hash to its token and user.
    // The raw code is never stored in the database.
    private static string HashVerificationCode(
        OneTimeToken token,
        string code) =>
        TokenService.Hash(
            $"{token.Id:N}:{token.UserId:N}:verify_email:{code}");

    private static bool VerificationCodeMatches(
        OneTimeToken token,
        string suppliedCode)
    {
        var expected = HashVerificationCode(token, suppliedCode);
        var stored = token.TokenHash.Trim();

        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expected),
            Encoding.UTF8.GetBytes(stored));
    }

    // Password-reset codes use a different purpose from verification codes.
    private static string HashPasswordResetCode(
        OneTimeToken token,
        string code) =>
        TokenService.Hash(
            $"{token.Id:N}:{token.UserId:N}:reset_password:{code}");

    private static bool PasswordResetCodeMatches(
        OneTimeToken token,
        string suppliedCode)
    {
        var expected = HashPasswordResetCode(token, suppliedCode);
        var stored = token.TokenHash.Trim();

        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expected),
            Encoding.UTF8.GetBytes(stored));
    }

    private static async Task<bool> SendNewVerificationCodeAsync(
        User user,
        MindPalDbContext db,
        SmtpEmailSender emailSender,
        CancellationToken ct)
    {
        var now = DateTime.UtcNow;

        var previousTokens = await db.OneTimeTokens
            .Where(t =>
                t.UserId == user.Id &&
                t.Purpose == "verify_email" &&
                t.UsedAt == null)
            .ToListAsync(ct);

        foreach (var previous in previousTokens)
            previous.UsedAt = now;

        var code = GenerateVerificationCode();

        var token = new OneTimeToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Purpose = "verify_email",
            ExpiresAt = now.Add(VerificationCodeLifetime),
            CreatedAt = now,
            FailedAttempts = 0
        };

        token.TokenHash = HashVerificationCode(token, code);

        db.OneTimeTokens.Add(token);
        await db.SaveChangesAsync(ct);

        try
        {
            await emailSender.SendVerificationCodeAsync(
                user.Email,
                user.DisplayName,
                code,
                ct);

            return true;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception)
        {
            token.UsedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);

            return false;
        }
    }

    // ---------- POST /auth/register ----------

    private static async Task<IResult> Register(
        RegisterRequest req,
        MindPalDbContext db,
        SmtpEmailSender emailSender,
        CancellationToken ct)
    {
        var errors = new Dictionary<string, string[]>();

        var name = req.DisplayName?.Trim() ?? "";
        var email = req.Email?.Trim().ToLowerInvariant() ?? "";
        var password = req.Password ?? "";

        var gender = string.IsNullOrWhiteSpace(req.Gender)
            ? "unspecified"
            : req.Gender.Trim().ToLowerInvariant();

        if (name.Length is < 1 or > 40)
            errors["displayName"] =
                ["Display name must be 1 to 40 characters."];

        if (email.Length is < 3 or > 254 ||
            !EmailRegex.IsMatch(email))
        {
            errors["email"] = ["Enter a valid email address."];
        }

        var passwordError = PasswordHasher.Validate(password);

        if (passwordError is not null)
            errors["password"] = [passwordError];

        if (gender is not ("female" or "male" or "unspecified"))
        {
            errors["gender"] = [
                "Gender must be female, male, or unspecified."
            ];
        }

        if (errors.Count > 0)
        {
            return Problem(
                400,
                "validation_failed",
                "Validation failed",
                "One or more fields are invalid.",
                errors);
        }

        if (await db.Users.AnyAsync(u => u.Email == email, ct))
            return Problem(
                409,
                "email_taken",
                "Email already registered");

        var now = DateTime.UtcNow;

        var user = new User
        {
            DisplayName = name,
            Email = email,
            PasswordHash = PasswordHasher.Hash(password),
            Gender = gender,
            AvatarId = gender == "male" ? (short)6 : (short)1,
            EmailVerified = false,
            CreatedAt = now,
            UpdatedAt = now
        };

        db.Users.Add(user);

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException ex)
            when (ex.InnerException is
                PostgresException { SqlState: "23505" })
        {
            return Problem(
                409,
                "email_taken",
                "Email already registered");
        }

        var sent = await SendNewVerificationCodeAsync(
            user, db, emailSender, ct);

        if (!sent)
        {
            return Problem(
                503,
                "verification_email_failed",
                "Verification email could not be sent",
                "Please try requesting another verification code.");
        }

        return Results.Created(
            "/auth/verify-email",
            new
            {
                verificationRequired = true,
                email = user.Email
            });
    }

    // ---------- POST /auth/verify-email ----------

    private static async Task<IResult> VerifyEmail(
        VerifyEmailRequest req,
        MindPalDbContext db,
        TokenService tokens,
        CancellationToken ct)
    {
        var email = req.Email?.Trim().ToLowerInvariant() ?? "";
        var code = req.Code?.Trim() ?? "";

        if (!EmailRegex.IsMatch(email) ||
            code.Length != 6 ||
            code.Any(c => c is < '0' or > '9'))
        {
            return Problem(
                400,
                "validation_failed",
                "Enter a valid email address and six-digit code.");
        }

        var user = await db.Users
            .FirstOrDefaultAsync(u => u.Email == email, ct);

        if (user is null)
        {
            return Problem(
                400,
                "invalid_verification_code",
                "The verification code is invalid or expired.");
        }

        if (user.EmailVerified)
        {
            return Problem(
                409,
                "email_already_verified",
                "This email address is already verified.");
        }

        var token = await db.OneTimeTokens
            .Where(t =>
                t.UserId == user.Id &&
                t.Purpose == "verify_email" &&
                t.UsedAt == null)
            .OrderByDescending(t => t.CreatedAt)
            .FirstOrDefaultAsync(ct);

        if (token is null)
        {
            return Problem(
                400,
                "invalid_verification_code",
                "The verification code is invalid or expired.");
        }

        var now = DateTime.UtcNow;

        if (token.ExpiresAt <= now)
        {
            token.UsedAt = now;
            await db.SaveChangesAsync(ct);

            return Problem(
                400,
                "verification_code_expired",
                "Your verification code has expired. Request a new one.");
        }

        if (token.FailedAttempts >= MaxFailedVerificationAttempts)
        {
            token.UsedAt = now;
            await db.SaveChangesAsync(ct);

            return Problem(
                429,
                "verification_attempts_exceeded",
                "Too many incorrect attempts. Request a new code.");
        }

        if (!VerificationCodeMatches(token, code))
        {
            token.FailedAttempts++;

            var attemptsExceeded =
                token.FailedAttempts >= MaxFailedVerificationAttempts;

            if (attemptsExceeded)
                token.UsedAt = now;

            await db.SaveChangesAsync(ct);

            return Problem(
                attemptsExceeded ? 429 : 400,
                attemptsExceeded
                    ? "verification_attempts_exceeded"
                    : "invalid_verification_code",
                attemptsExceeded
                    ? "Too many incorrect attempts. Request a new code."
                    : "The verification code is incorrect.");
        }

        token.UsedAt = now;
        user.EmailVerified = true;
        user.UpdatedAt = now;

        await db.SaveChangesAsync(ct);
        await MarkActive(user.Id, db, ct);

        var authResponse = await IssueTokens(user, db, tokens, ct);

        return Results.Ok(authResponse);
    }

    // ---------- POST /auth/resend-verification ----------

    private static async Task<IResult> ResendVerification(
        ResendVerificationRequest req,
        MindPalDbContext db,
        SmtpEmailSender emailSender,
        CancellationToken ct)
    {
        var email = req.Email?.Trim().ToLowerInvariant() ?? "";

        if (!EmailRegex.IsMatch(email))
        {
            return Problem(
                400,
                "validation_failed",
                "Enter a valid email address.");
        }

        var user = await db.Users
            .FirstOrDefaultAsync(u => u.Email == email, ct);

        if (user is null || user.EmailVerified)
        {
            return Results.Accepted(
                value: new
                {
                    message =
                        "If the account requires verification, instructions will be sent."
                });
        }

        var now = DateTime.UtcNow;
        var cooldownStart = now.Subtract(ResendCooldown);

        var recentlySent = await db.OneTimeTokens.AnyAsync(
            t =>
                t.UserId == user.Id &&
                t.Purpose == "verify_email" &&
                t.UsedAt == null &&
                t.CreatedAt >= cooldownStart,
            ct);

        if (recentlySent)
        {
            return Problem(
                429,
                "resend_cooldown",
                "Please wait before requesting another verification code.");
        }

        var sent = await SendNewVerificationCodeAsync(
            user, db, emailSender, ct);

        if (!sent)
        {
            return Problem(
                503,
                "verification_email_failed",
                "Verification email could not be sent",
                "Please try again later.");
        }

        return Results.Ok(
            new
            {
                message = "A new verification code has been sent.",
                email = user.Email
            });
    }

    // ---------- POST /auth/forgot-password ----------

    private static async Task<IResult> ForgotPassword(
        ForgotPasswordRequest req,
        MindPalDbContext db,
        SmtpEmailSender emailSender,
        CancellationToken ct)
    {
        var email = req.Email?.Trim().ToLowerInvariant() ?? "";

        if (email.Length > 254 || !EmailRegex.IsMatch(email))
        {
            return Problem(
                400,
                "validation_failed",
                "Enter a valid email address.");
        }

        // Keep the response generic to prevent account enumeration.
        var accepted = () => Results.Accepted(
            value: new
            {
                message =
                    "If an eligible account exists, password reset instructions will be sent."
            });

        var user = await db.Users
            .FirstOrDefaultAsync(u => u.Email == email, ct);

        if (user is null ||
            !user.EmailVerified ||
            user.Status != "active")
        {
            return accepted();
        }

        var now = DateTime.UtcNow;
        var cooldownStart = now.Subtract(ResendCooldown);

        var recentlyRequested = await db.OneTimeTokens.AnyAsync(
            t =>
                t.UserId == user.Id &&
                t.Purpose == "reset_password" &&
                t.CreatedAt >= cooldownStart,
            ct);

        if (recentlyRequested)
            return accepted();

        var previousTokens = await db.OneTimeTokens
            .Where(t =>
                t.UserId == user.Id &&
                t.Purpose == "reset_password" &&
                t.UsedAt == null)
            .ToListAsync(ct);

        foreach (var previous in previousTokens)
            previous.UsedAt = now;

        var code = GenerateVerificationCode();

        var token = new OneTimeToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Purpose = "reset_password",
            ExpiresAt = now.Add(VerificationCodeLifetime),
            CreatedAt = now,
            FailedAttempts = 0
        };

        token.TokenHash = HashPasswordResetCode(token, code);

        db.OneTimeTokens.Add(token);
        await db.SaveChangesAsync(ct);

        try
        {
            await emailSender.SendPasswordResetCodeAsync(
                user.Email,
                user.DisplayName,
                code,
                ct);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception)
        {
            // Invalidate the code if email delivery fails.
            token.UsedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);

            // Do not expose account existence or SMTP details.
        }

        return accepted();
    }

    // ---------- POST /auth/reset-password ----------

    private static async Task<IResult> ResetPassword(
        ResetPasswordRequest req,
        MindPalDbContext db,
        CancellationToken ct)
    {
        var email = req.Email?.Trim().ToLowerInvariant() ?? "";
        var code = req.Code?.Trim() ?? "";
        var newPassword = req.NewPassword ?? "";

        var errors = new Dictionary<string, string[]>();

        if (email.Length > 254 || !EmailRegex.IsMatch(email))
            errors["email"] = ["Enter a valid email address."];

        if (code.Length != 6 ||
            code.Any(c => c is < '0' or > '9'))
        {
            errors["code"] = ["Enter the six-digit reset code."];
        }

        if (newPassword.Length > 200)
        {
            errors["newPassword"] = [
                "Password must not exceed 200 characters."
            ];
        }
        else
        {
            var passwordError = PasswordHasher.Validate(newPassword);

            if (passwordError is not null)
                errors["newPassword"] = [passwordError];
        }

        if (errors.Count > 0)
        {
            return Problem(
                400,
                "validation_failed",
                "Validation failed",
                "One or more fields are invalid.",
                errors);
        }

        var invalidCode = () => Problem(
            400,
            "invalid_reset_code",
            "The reset code is invalid or expired.");

        var user = await db.Users
            .FirstOrDefaultAsync(u => u.Email == email, ct);

        if (user is null ||
            !user.EmailVerified ||
            user.Status != "active")
        {
            return invalidCode();
        }

        var token = await db.OneTimeTokens
            .Where(t =>
                t.UserId == user.Id &&
                t.Purpose == "reset_password" &&
                t.UsedAt == null)
            .OrderByDescending(t => t.CreatedAt)
            .FirstOrDefaultAsync(ct);

        if (token is null)
            return invalidCode();

        var now = DateTime.UtcNow;

        if (token.ExpiresAt <= now)
        {
            token.UsedAt = now;
            await db.SaveChangesAsync(ct);

            return Problem(
                400,
                "reset_code_expired",
                "Your reset code has expired. Request a new one.");
        }

        if (token.FailedAttempts >= MaxFailedPasswordResetAttempts)
        {
            token.UsedAt = now;
            await db.SaveChangesAsync(ct);

            return Problem(
                429,
                "reset_attempts_exceeded",
                "Too many incorrect attempts. Request a new code.");
        }

        if (!PasswordResetCodeMatches(token, code))
        {
            token.FailedAttempts++;

            var attemptsExceeded =
                token.FailedAttempts >= MaxFailedPasswordResetAttempts;

            if (attemptsExceeded)
                token.UsedAt = now;

            await db.SaveChangesAsync(ct);

            return Problem(
                attemptsExceeded ? 429 : 400,
                attemptsExceeded
                    ? "reset_attempts_exceeded"
                    : "invalid_reset_code",
                attemptsExceeded
                    ? "Too many incorrect attempts. Request a new code."
                    : "The reset code is incorrect.");
        }

        // Consume the code and change the password transactionally.
        await using var transaction =
            await db.Database.BeginTransactionAsync(ct);

        token.UsedAt = now;
        user.PasswordHash = PasswordHasher.Hash(newPassword);
        user.UpdatedAt = now;
        user.FailedLoginCount = 0;
        user.LockedUntil = null;

        var otherTokens = await db.OneTimeTokens
            .Where(t =>
                t.UserId == user.Id &&
                t.Purpose == "reset_password" &&
                t.UsedAt == null &&
                t.Id != token.Id)
            .ToListAsync(ct);

        foreach (var other in otherTokens)
            other.UsedAt = now;

        await db.SaveChangesAsync(ct);

        // Revoke all active refresh tokens after a password reset.
        await db.RefreshTokens
            .Where(t =>
                t.UserId == user.Id &&
                t.RevokedAt == null)
            .ExecuteUpdateAsync(
                s => s.SetProperty(t => t.RevokedAt, now),
                ct);

        await transaction.CommitAsync(ct);

        return Results.NoContent();
    }

    // ---------- POST /auth/login ----------

    private static async Task<IResult> Login(
        LoginRequest req,
        MindPalDbContext db,
        TokenService tokens,
        CancellationToken ct)
    {
        var email = req.Email?.Trim().ToLowerInvariant() ?? "";
        var password = req.Password ?? "";

        if (email.Length == 0 ||
            password.Length == 0 ||
            password.Length > 200)
        {
            return Problem(
                400,
                "validation_failed",
                "Email and password are required");
        }

        var invalid = () =>
            Problem(
                401,
                "invalid_credentials",
                "Email or password is incorrect");

        var user = await db.Users
            .FirstOrDefaultAsync(u => u.Email == email, ct);

        if (user is null)
        {
            PasswordHasher.BurnTime(password);
            return invalid();
        }

        var now = DateTime.UtcNow;

        if (user.LockedUntil is not null &&
            user.LockedUntil > now)
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
        {
            return Problem(
                403,
                "account_suspended",
                "This account is suspended");
        }

        user.FailedLoginCount = 0;
        user.LockedUntil = null;
        user.UpdatedAt = now;

        await db.SaveChangesAsync(ct);

        if (!user.EmailVerified)
        {
            return Problem(
                403,
                "email_not_verified",
                "Email verification is required");
        }

        await MarkActive(user.Id, db, ct);

        return Results.Ok(await IssueTokens(user, db, tokens, ct));
    }

    // ---------- POST /auth/refresh ----------

    private static async Task<IResult> Refresh(
        RefreshRequest req,
        MindPalDbContext db,
        TokenService tokens,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(req.RefreshToken))
        {
            return Problem(
                400,
                "validation_failed",
                "Refresh token is required");
        }

        var hash = TokenService.Hash(req.RefreshToken);

        var stored = await db.RefreshTokens
            .FirstOrDefaultAsync(t => t.TokenHash == hash, ct);

        var bad = () =>
            Problem(
                401,
                "invalid_token",
                "Refresh token is invalid or expired");

        if (stored is null)
            return bad();

        var now = DateTime.UtcNow;

        if (stored.RevokedAt is not null)
        {
            // Reuse detection: revoke all active refresh tokens.
            await db.RefreshTokens
                .Where(t =>
                    t.UserId == stored.UserId &&
                    t.RevokedAt == null)
                .ExecuteUpdateAsync(
                    s => s.SetProperty(t => t.RevokedAt, now),
                    ct);

            return bad();
        }

        if (stored.ExpiresAt <= now)
            return bad();

        var user = await db.Users
            .FirstOrDefaultAsync(u => u.Id == stored.UserId, ct);

        if (user is null ||
            user.Status == "suspended" ||
            !user.EmailVerified)
        {
            stored.RevokedAt = now;
            await db.SaveChangesAsync(ct);
            return bad();
        }

        stored.RevokedAt = now;
        await db.SaveChangesAsync(ct);

        return Results.Ok(await IssueTokens(user, db, tokens, ct));
    }

    // ---------- POST /auth/logout ----------

    private static async Task<IResult> Logout(
        RefreshRequest req,
        MindPalDbContext db,
        CancellationToken ct)
    {
        if (!string.IsNullOrWhiteSpace(req.RefreshToken))
        {
            var hash = TokenService.Hash(req.RefreshToken);

            await db.RefreshTokens
                .Where(t =>
                    t.TokenHash == hash &&
                    t.RevokedAt == null)
                .ExecuteUpdateAsync(
                    s => s.SetProperty(
                        t => t.RevokedAt,
                        DateTime.UtcNow),
                    ct);
        }

        return Results.NoContent();
    }

    // ---------- GET /me ----------

    private static async Task<IResult> Me(
        ClaimsPrincipal principal,
        MindPalDbContext db,
        CancellationToken ct)
    {
        if (!Guid.TryParse(
                principal.FindFirstValue("sub"),
                out var id))
        {
            return Problem(401, "invalid_token", "Token is invalid");
        }

        var user = await db.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == id, ct);

        return user is null
            ? Problem(401, "invalid_token", "Token is invalid")
            : Results.Ok(ToDto(user));
    }

    // ---------- PATCH /me ----------

    private static async Task<IResult> UpdateMe(
        UpdateProfileRequest req,
        ClaimsPrincipal principal,
        MindPalDbContext db,
        CancellationToken ct)
    {
        if (!Guid.TryParse(
                principal.FindFirstValue("sub"),
                out var id))
        {
            return Problem(401, "invalid_token", "Token is invalid");
        }

        var user = await db.Users
            .FirstOrDefaultAsync(u => u.Id == id, ct);

        if (user is null)
            return Problem(401, "invalid_token", "Token is invalid");

        if (req.DisplayName is null && req.AvatarId is null)
        {
            return Problem(
                400,
                "empty_update",
                "No profile changes provided");
        }

        var errors = new Dictionary<string, string[]>();
        string? newName = null;
        short? newAvatarId = null;

        if (req.DisplayName is not null)
        {
            newName = req.DisplayName.Trim();

            if (newName.Length is < 1 or > 40)
            {
                errors["displayName"] = [
                    "Display name must be 1 to 40 characters."
                ];
            }
        }

        if (req.AvatarId.HasValue)
        {
            var avatarId = req.AvatarId.Value;

            var allowed = user.Gender switch
            {
                "female" => avatarId >= 1 && avatarId <= 5,
                "male" => avatarId >= 6 && avatarId <= 10,
                _ => avatarId >= 1 && avatarId <= 10
            };

            if (!allowed)
            {
                errors["avatarId"] = [
                    "The selected avatar is not allowed for this profile."
                ];
            }
            else
            {
                newAvatarId = avatarId;
            }
        }

        if (errors.Count > 0)
        {
            return Problem(
                400,
                "validation_failed",
                "Validation failed",
                "One or more fields are invalid.",
                errors);
        }

        if (newName is not null)
            user.DisplayName = newName;

        if (newAvatarId.HasValue)
            user.AvatarId = newAvatarId.Value;

        user.UpdatedAt = DateTime.UtcNow;

        await db.SaveChangesAsync(ct);

        return Results.Ok(ToDto(user));
    }

    // ---------- POST /me/password (FR-07) ----------

    private static async Task<IResult> ChangePassword(
        ChangePasswordRequest req,
        ClaimsPrincipal principal,
        MindPalDbContext db,
        TokenService tokens,
        CancellationToken ct)
    {
        if (!Guid.TryParse(
                principal.FindFirstValue("sub"),
                out var id))
        {
            return Problem(401, "invalid_token", "Token is invalid");
        }

        var user = await db.Users
            .FirstOrDefaultAsync(u => u.Id == id, ct);

        if (user is null || user.Status != "active")
        {
            return Problem(401, "invalid_token", "Token is invalid");
        }

        var currentPassword = req.CurrentPassword ?? "";
        var newPassword = req.NewPassword ?? "";

        var errors = new Dictionary<string, string[]>();

        if (string.IsNullOrEmpty(currentPassword))
        {
            errors["currentPassword"] = [
                "Enter your current password."
            ];
        }
        else if (currentPassword.Length > 200)
        {
            errors["currentPassword"] = [
                "Current password is invalid."
            ];
        }

        if (newPassword.Length > 200)
        {
            errors["newPassword"] = [
                "Password must not exceed 200 characters."
            ];
        }
        else
        {
            var passwordError = PasswordHasher.Validate(newPassword);

            if (passwordError is not null)
                errors["newPassword"] = [passwordError];
        }

        if (errors.Count > 0)
        {
            return Problem(
                400,
                "validation_failed",
                "Validation failed",
                "One or more fields are invalid.",
                errors);
        }

        if (!PasswordHasher.Verify(
                currentPassword, user.PasswordHash))
        {
            return Problem(
                400,
                "invalid_current_password",
                "Your current password is incorrect.");
        }

        if (PasswordHasher.Verify(newPassword, user.PasswordHash))
        {
            return Problem(
                400,
                "same_password",
                "Choose a password different from your current password.");
        }

        await using var transaction =
            await db.Database.BeginTransactionAsync(ct);

        var now = DateTime.UtcNow;

        user.PasswordHash = PasswordHasher.Hash(newPassword);
        user.UpdatedAt = now;
        user.FailedLoginCount = 0;
        user.LockedUntil = null;

        // Revoke all previously active refresh sessions.
        await db.RefreshTokens
            .Where(t =>
                t.UserId == user.Id &&
                t.RevokedAt == null)
            .ExecuteUpdateAsync(
                s => s.SetProperty(t => t.RevokedAt, now),
                ct);

        // Create a new refresh token and access token for this device.
        var response = await IssueTokens(user, db, tokens, ct);

        await transaction.CommitAsync(ct);

        return Results.Ok(response);
    }
}

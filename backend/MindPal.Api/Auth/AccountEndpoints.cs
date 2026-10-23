using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using MindPal.Api.Data;
using MindPal.Api.Services;

namespace MindPal.Api.Auth;

public record DeleteAccountRequest(string? Password);

public static class AccountEndpoints
{
    public static void MapAccount(this IEndpointRouteBuilder app) =>
        app.MapPost("/me/delete", DeleteAccount)
           .RequireAuthorization()
           .RequireRateLimiting("auth")
           .WithTags("Account");

    private static IResult Problem(
        int status,
        string code,
        string title,
        string? detail = null,
        Dictionary<string, string[]>? errors = null)
    {
        var ext = new Dictionary<string, object?> { ["code"] = code };
        if (errors is not null) ext["errors"] = errors;

        return Results.Problem(
            statusCode: status, title: title, detail: detail, extensions: ext);
    }

    // FR-34: the user confirms with their password. The account is marked for deletion,
    // every session is revoked, and sign-in is blocked at once. The purge job removes
    // the server data (see AccountPurgeService).
    private static async Task<IResult> DeleteAccount(
        DeleteAccountRequest req,
        ClaimsPrincipal principal,
        MindPalDbContext db,
        CancellationToken ct)
    {
        if (!Guid.TryParse(principal.FindFirstValue("sub"), out var id))
            return Problem(401, "invalid_token", "Token is invalid");

        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == id, ct);

        if (user is null || !AccountDeletion.CanSignIn(user.Status))
            return Problem(401, "invalid_token", "Token is invalid");

        var password = req.Password ?? "";

        if (password.Length == 0 || password.Length > 200)
        {
            return Problem(
                400,
                "validation_failed",
                "Validation failed",
                "Enter your password.",
                new Dictionary<string, string[]> { ["password"] = ["Enter your password."] });
        }

        if (!PasswordHasher.Verify(password, user.PasswordHash))
        {
            return Problem(
                400,
                "invalid_current_password",
                "Your password is incorrect.");
        }

        await using var transaction = await db.Database.BeginTransactionAsync(ct);

        var now = DateTime.UtcNow;

        user.Status = AccountDeletion.PendingStatus;
        user.DeletionRequestedAt = now;
        user.UpdatedAt = now;
        await db.SaveChangesAsync(ct);

        await db.RefreshTokens
            .Where(t => t.UserId == user.Id && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now), ct);

        await db.OneTimeTokens
            .Where(t => t.UserId == user.Id && t.UsedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.UsedAt, now), ct);

        await transaction.CommitAsync(ct);

        return Results.Accepted(value: new
        {
            message = "Your account is scheduled for deletion. Your server data will be removed within 7 days.",
            deleteWithinDays = (int)AccountDeletion.Deadline.TotalDays
        });
    }
}

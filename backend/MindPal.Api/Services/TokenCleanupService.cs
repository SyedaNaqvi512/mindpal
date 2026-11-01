using Microsoft.EntityFrameworkCore;
using MindPal.Api.Data;

namespace MindPal.Api.Services;

// How long an expired token is kept before the cleanup job removes it.
// A revoked refresh token stays until it expires, so reuse of an old token is
// still noticed; one more day of margin keeps clock differences harmless.
public static class TokenRetention
{
    public static readonly TimeSpan KeepExpiredFor = TimeSpan.FromDays(1);

    public static DateTime Cutoff(DateTime nowUtc) => nowUtc - KeepExpiredFor;

    public static bool IsRemovable(DateTime expiresAtUtc, DateTime nowUtc)
        => expiresAtUtc <= Cutoff(nowUtc);
}

// Housekeeping: removes expired sign-in tokens and expired e-mail codes so the
// tables stay small. Nothing the user sees depends on this job.
public class TokenCleanupService(
    IServiceScopeFactory scopes,
    ILogger<TokenCleanupService> logger) : BackgroundService
{
    private static readonly TimeSpan StartDelay = TimeSpan.FromMinutes(2);
    private static readonly TimeSpan Every = TimeSpan.FromHours(6);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            await Task.Delay(StartDelay, stoppingToken);

            while (!stoppingToken.IsCancellationRequested)
            {
                await RunOnce(stoppingToken);
                await Task.Delay(Every, stoppingToken);
            }
        }
        catch (OperationCanceledException)
        {
            // The app is stopping.
        }
    }

    private async Task RunOnce(CancellationToken ct)
    {
        try
        {
            using var scope = scopes.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<MindPalDbContext>();

            var cutoff = TokenRetention.Cutoff(DateTime.UtcNow);

            var refresh = await db.RefreshTokens
                .Where(t => t.ExpiresAt <= cutoff)
                .ExecuteDeleteAsync(ct);

            var codes = await db.OneTimeTokens
                .Where(t => t.ExpiresAt <= cutoff)
                .ExecuteDeleteAsync(ct);

            if (refresh + codes > 0)
                logger.LogInformation(
                    "Token cleanup removed {Refresh} refresh token(s) and {Codes} e-mail code(s).",
                    refresh, codes);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Token cleanup failed; it will run again later.");
        }
    }
}

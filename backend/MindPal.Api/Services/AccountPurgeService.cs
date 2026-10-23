using Microsoft.EntityFrameworkCore;
using MindPal.Api.Auth;
using MindPal.Api.Data;

namespace MindPal.Api.Services;

// Removes accounts that asked to be deleted (FR-34, NFR-16).
// Deleting the user row removes everything linked to it (tokens, consents,
// usage logs, ratings, activity days) through the database's ON DELETE CASCADE.
public class AccountPurgeService(
    IServiceScopeFactory scopes,
    ILogger<AccountPurgeService> logger) : BackgroundService
{
    private static readonly TimeSpan StartDelay = TimeSpan.FromMinutes(1);
    private static readonly TimeSpan Every = TimeSpan.FromHours(1);

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

            var cutoff = DateTime.UtcNow - AccountDeletion.PurgeAfter;

            var removed = await db.Users
                .Where(u => u.Status == AccountDeletion.PendingStatus &&
                            u.DeletionRequestedAt != null &&
                            u.DeletionRequestedAt <= cutoff)
                .ExecuteDeleteAsync(ct);

            if (removed > 0)
                logger.LogInformation("Deleted {Count} account(s) that requested deletion.", removed);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Account purge failed; it will run again later.");
        }
    }
}

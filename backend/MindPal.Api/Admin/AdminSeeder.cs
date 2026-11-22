using Microsoft.EntityFrameworkCore;
using MindPal.Api.Auth;
using MindPal.Api.Data;

namespace MindPal.Api.Admin;

// Creates (or promotes) the first admin at start-up from Admin:Email and
// Admin:Password (user secrets or environment variables). It never changes
// the password of an existing account. Nothing happens if they are not set.
public class AdminSeeder(
    IServiceProvider services,
    IConfiguration config,
    ILogger<AdminSeeder> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var email = (config["Admin:Email"] ?? "").Trim().ToLowerInvariant();
        var password = config["Admin:Password"] ?? "";

        if (email.Length == 0 || password.Length == 0) return;

        try
        {
            using var scope = services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<MindPalDbContext>();

            var user = await db.Users.FirstOrDefaultAsync(
                u => u.Email.ToLower() == email, stoppingToken);
            var now = DateTime.UtcNow;

            if (user is null)
            {
                var problem = PasswordHasher.Validate(password);
                if (problem is not null)
                {
                    log.LogWarning("Admin seed skipped: {Problem}", problem);
                    return;
                }

                db.Users.Add(new User
                {
                    Id = Guid.NewGuid(),
                    DisplayName = "Admin",
                    Email = email,
                    PasswordHash = PasswordHasher.Hash(password),
                    Role = "admin",
                    Status = "active",
                    EmailVerified = true,
                    Gender = "unspecified",
                    AvatarId = 1,
                    CreatedAt = now,
                    UpdatedAt = now
                });
                log.LogInformation("Admin account created");
            }
            else if (user.Role != "admin")
            {
                user.Role = "admin";
                user.UpdatedAt = now;
                log.LogInformation("Existing account promoted to admin");
            }
            else return;

            await db.SaveChangesAsync(stoppingToken);
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Admin seed failed");
        }
    }
}
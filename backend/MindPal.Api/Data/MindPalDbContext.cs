using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;

namespace MindPal.Api.Data;

public class MindPalDbContext(DbContextOptions<MindPalDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<OneTimeToken> OneTimeTokens => Set<OneTimeToken>();
    public DbSet<UserActivityDay> UserActivityDays => Set<UserActivityDay>();
    public DbSet<Consent> Consents => Set<Consent>();
    public DbSet<AiUsageLog> AiUsageLogs => Set<AiUsageLog>();
    public DbSet<ReflectionFeedback> ReflectionFeedback => Set<ReflectionFeedback>();
    public DbSet<SafetyEvent> SafetyEvents => Set<SafetyEvent>();
    public DbSet<ExerciseEvent> ExerciseEvents => Set<ExerciseEvent>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.HasPostgresExtension("citext");

        // ---- users (D2) ----
        b.Entity<User>(e =>
        {
            e.ToTable("users", t =>
            {
                t.HasCheckConstraint("ck_users_avatar", "avatar_id BETWEEN 1 AND 12");
                t.HasCheckConstraint("ck_users_gender", "gender IN ('female','male','unspecified')");
                t.HasCheckConstraint("ck_users_role", "role IN ('user','admin')");
                t.HasCheckConstraint("ck_users_status", "status IN ('active','suspended','pending_deletion')");
                t.HasCheckConstraint("ck_users_email_len", "char_length(email) BETWEEN 3 AND 254");
                t.HasCheckConstraint("ck_users_name_len", "char_length(btrim(display_name)) BETWEEN 1 AND 40");
                t.HasCheckConstraint("ck_users_deletion", "(status = 'pending_deletion') = (deletion_requested_at IS NOT NULL)");
            });

            e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
            e.Property(x => x.DisplayName).HasMaxLength(40);
            e.Property(x => x.AvatarId).HasDefaultValue((short)1);
            e.Property(x => x.Gender)
                .HasMaxLength(20)
                .HasDefaultValue("unspecified");
            e.Property(x => x.Email).HasColumnType("citext");
            e.Property(x => x.PasswordHash).HasMaxLength(100);
            e.Property(x => x.Role).HasMaxLength(10).HasDefaultValue("user");
            e.Property(x => x.Status).HasMaxLength(16).HasDefaultValue("active");
            e.Property(x => x.CreatedAt).HasDefaultValueSql("now()");
            e.Property(x => x.UpdatedAt).HasDefaultValueSql("now()");

            e.HasIndex(x => x.Email).IsUnique().HasDatabaseName("ux_users_email");
            e.HasIndex(x => x.CreatedAt).HasDatabaseName("ix_users_created_at");
            e.HasIndex(x => x.DeletionRequestedAt)
                .HasFilter("status = 'pending_deletion'")
                .HasDatabaseName("ix_users_deletion_due");
        });

        // ---- refresh_tokens (D2) ----
        b.Entity<RefreshToken>(e =>
        {
            e.ToTable("refresh_tokens", t =>
                t.HasCheckConstraint("ck_refresh_expiry", "expires_at > created_at"));

            e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
            e.Property(x => x.TokenHash).HasColumnType("char(64)");
            e.Property(x => x.CreatedAt).HasDefaultValueSql("now()");
            e.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(x => x.TokenHash).IsUnique().HasDatabaseName("ux_refresh_tokens_hash");
            e.HasIndex(x => x.UserId).HasDatabaseName("ix_refresh_tokens_user");
            e.HasIndex(x => x.ExpiresAt).HasDatabaseName("ix_refresh_tokens_expires_at");
        });

        // ---- one_time_tokens (D2) ----
        b.Entity<OneTimeToken>(e =>
        {
            e.ToTable("one_time_tokens", t =>
                t.HasCheckConstraint("ck_ott_purpose", "purpose IN ('verify_email','reset_password')"));

            e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
            e.Property(x => x.Purpose).HasMaxLength(20);
            e.Property(x => x.TokenHash).HasColumnType("char(64)");
            e.Property(x => x.CreatedAt).HasDefaultValueSql("now()");
            e.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(x => x.TokenHash).IsUnique().HasDatabaseName("ux_one_time_tokens_hash");
            e.HasIndex(x => new { x.UserId, x.Purpose }).HasDatabaseName("ix_one_time_tokens_user");
            e.HasIndex(x => x.ExpiresAt).HasDatabaseName("ix_one_time_tokens_expires_at");
        });

        // ---- user_activity_days (D2) ----
        b.Entity<UserActivityDay>(e =>
        {
            e.ToTable("user_activity_days");
            e.HasKey(x => new { x.UserId, x.ActivityDate });
            e.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(x => x.ActivityDate).HasDatabaseName("ix_activity_date");
        });

        // ---- consents (D3) ----
        b.Entity<Consent>(e =>
        {
            e.ToTable("consents", t =>
            {
                t.HasCheckConstraint("ck_consents_type", "type IN ('ai_processing')");
                t.HasCheckConstraint("ck_consents_revoked", "revoked_at IS NULL OR revoked_at >= granted_at");
            });

            e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
            e.Property(x => x.Type).HasMaxLength(20);
            e.Property(x => x.PolicyVersion).HasMaxLength(10);
            e.Property(x => x.GrantedAt).HasDefaultValueSql("now()");
            e.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(x => new { x.UserId, x.Type })
                .IsUnique()
                .HasFilter("revoked_at IS NULL")
                .HasDatabaseName("ux_consents_active");
            e.HasIndex(x => new { x.UserId, x.Type, x.GrantedAt })
                .IsDescending(false, false, true)
                .HasDatabaseName("ix_consents_latest");
        });

        // ---- ai_usage_logs (D4) ----
        b.Entity<AiUsageLog>(e =>
        {
            e.ToTable("ai_usage_logs", t =>
            {
                t.HasCheckConstraint("ck_ai_usage_status", "status IN ('success','timeout','error','rate_limited')");
                t.HasCheckConstraint("ck_ai_usage_duration", "duration_ms >= 0");
            });

            e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
            e.Property(x => x.CreatedAt).HasDefaultValueSql("now()");
            e.Property(x => x.Model).HasMaxLength(40);
            e.Property(x => x.Status).HasMaxLength(15);
            e.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(x => new { x.UserId, x.CreatedAt })
                .IsDescending(false, true)
                .HasDatabaseName("ix_ai_usage_user_time");
            e.HasIndex(x => x.CreatedAt)
                .IncludeProperties(x => new { x.Status, x.DurationMs })
                .HasDatabaseName("ix_ai_usage_created");
        });

        // ---- reflection_feedback (D4) ----
        b.Entity<ReflectionFeedback>(e =>
        {
            e.ToTable("reflection_feedback", t =>
            {
                t.HasCheckConstraint("ck_feedback_rating", "rating IN ('helpful','not_helpful')");
                t.HasCheckConstraint("ck_feedback_reason", "reason_code IS NULL OR (rating = 'not_helpful' AND reason_code IN ('not_relevant','too_generic','felt_wrong','too_long','other'))");
            });

            e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
            e.Property(x => x.Rating).HasMaxLength(12);
            e.Property(x => x.ReasonCode).HasMaxLength(20);
            e.Property(x => x.CreatedAt).HasDefaultValueSql("now()");
            e.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            e.HasOne<AiUsageLog>().WithMany().HasForeignKey(x => x.UsageId).OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(x => x.UsageId).IsUnique().HasDatabaseName("ux_feedback_usage");
            e.HasIndex(x => x.UserId).HasDatabaseName("ix_feedback_user");
            e.HasIndex(x => x.CreatedAt)
                .IncludeProperties(x => new { x.Rating, x.ReasonCode })
                .HasDatabaseName("ix_feedback_created");
        });

        // ---- safety_events and exercise_events (D4, anonymous counts) ----
        b.Entity<SafetyEvent>(e =>
        {
            e.ToTable("safety_events");
            e.HasKey(x => x.Id);
            e.Property(x => x.CreatedAt).HasDefaultValueSql("now()");
            e.HasIndex(x => x.CreatedAt).HasDatabaseName("ix_safety_created");
        });

        b.Entity<ExerciseEvent>(e =>
        {
            e.ToTable("exercise_events");
            e.HasKey(x => x.Id);
            e.Property(x => x.ExerciseType).HasMaxLength(40);
            e.Property(x => x.CreatedAt).HasDefaultValueSql("now()");
            e.HasIndex(x => x.CreatedAt)
                .IncludeProperties(x => x.ExerciseType)
                .HasDatabaseName("ix_exercise_events_created");
        });

        // Column names in snake_case, as in the Week 4 design.
        // Example: DisplayName -> display_name, Gender -> gender.
        foreach (var entity in b.Model.GetEntityTypes())
        {
            foreach (var property in entity.GetProperties())
            {
                property.SetColumnName(ToSnake(property.Name));
            }
        }
    }

    private static string ToSnake(string name) =>
        Regex.Replace(name, "([a-z0-9])([A-Z])", "$1_$2").ToLowerInvariant();
}
namespace MindPal.Api.Data;

// Server tables of SRS v1.1, Section 8.2. No journal text is stored here, by design.

public class User
{
    public Guid Id { get; set; }
    public string DisplayName { get; set; } = "";
    public short AvatarId { get; set; } = 1;
    public string Gender { get; set; } = "unspecified";
    public string Email { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string Role { get; set; } = "user";               // user | admin
    public string Status { get; set; } = "active";           // active | suspended | pending_deletion
    public bool EmailVerified { get; set; }
    public short FailedLoginCount { get; set; }
    public DateTime? LockedUntil { get; set; }
    public DateTime? DeletionRequestedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class RefreshToken
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string TokenHash { get; set; } = "";              // SHA-256, 64 hex characters
    public DateTime ExpiresAt { get; set; }
    public DateTime? RevokedAt { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class OneTimeToken
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Purpose { get; set; } = "";                // verify_email | reset_password
    public string TokenHash { get; set; } = "";
    public DateTime ExpiresAt { get; set; }
    public DateTime? UsedAt { get; set; }
    public short FailedAttempts { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class UserActivityDay
{
    public Guid UserId { get; set; }
    public DateOnly ActivityDate { get; set; }
}

public class Consent
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Type { get; set; } = "ai_processing";
    public string PolicyVersion { get; set; } = "";
    public DateTime GrantedAt { get; set; }
    public DateTime? RevokedAt { get; set; }
}

public class AiUsageLog
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public DateTime CreatedAt { get; set; }
    public string Model { get; set; } = "";
    public int DurationMs { get; set; }
    public string Status { get; set; } = "success";          // success | timeout | error | rate_limited
}

public class ReflectionFeedback
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid UsageId { get; set; }
    public string Rating { get; set; } = "";                 // helpful | not_helpful
    public string? ReasonCode { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class SafetyEvent
{
    public long Id { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class ExerciseEvent
{
    public long Id { get; set; }
    public string ExerciseType { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}
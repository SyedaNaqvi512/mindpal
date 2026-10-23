namespace MindPal.Api.Auth;

// Rules for account deletion (FR-34, NFR-16).
public static class AccountDeletion
{
    public const string PendingStatus = "pending_deletion";

    // The server data must be gone within 7 days of the request (NFR-16).
    public static readonly TimeSpan Deadline = TimeSpan.FromDays(7);

    // The purge job removes an account this long after the request.
    // Sign-in is blocked from the moment of the request.
    public static readonly TimeSpan PurgeAfter = TimeSpan.FromHours(24);

    public static bool IsDue(DateTime? requestedAt, DateTime now) =>
        requestedAt is not null && now - requestedAt.Value >= PurgeAfter;

    // Only active accounts may sign in or use an existing token.
    public static bool CanSignIn(string? status) => status == "active";
}

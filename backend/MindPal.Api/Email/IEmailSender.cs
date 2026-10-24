namespace MindPal.Api.Email;

/// Sends the two emails MindPal needs. The data sent is only the recipient and
/// the message text, never any journal data (SRS TB-D).
public interface IEmailSender
{
    Task SendVerificationCodeAsync(
        string recipientEmail,
        string displayName,
        string code,
        CancellationToken cancellationToken = default);

    Task SendPasswordResetCodeAsync(
        string recipientEmail,
        string displayName,
        string code,
        CancellationToken cancellationToken = default);
}

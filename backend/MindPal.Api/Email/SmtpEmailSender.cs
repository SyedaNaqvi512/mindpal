using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace MindPal.Api.Email;

/// Local development only: sends through Gmail SMTP. The free web host blocks
/// SMTP ports, so deployment uses BrevoEmailSender (SRS section 2.7).
public sealed class SmtpEmailSender(IConfiguration configuration) : IEmailSender
{
    public Task SendVerificationCodeAsync(
        string recipientEmail, string displayName, string code,
        CancellationToken cancellationToken = default)
        => SendAsync(recipientEmail, displayName,
            EmailTemplates.Verification(displayName, code), cancellationToken);

    public Task SendPasswordResetCodeAsync(
        string recipientEmail, string displayName, string code,
        CancellationToken cancellationToken = default)
        => SendAsync(recipientEmail, displayName,
            EmailTemplates.PasswordReset(displayName, code), cancellationToken);

    private async Task SendAsync(
        string recipientEmail, string displayName, EmailContent content,
        CancellationToken cancellationToken)
    {
        var section = configuration.GetSection("Email:Smtp");

        var host = section["Host"]
            ?? throw new InvalidOperationException("SMTP host is not configured.");
        var port = section.GetValue<int>("Port");
        var username = section["Username"]
            ?? throw new InvalidOperationException("SMTP username is not configured.");
        var password = section["Password"]
            ?? throw new InvalidOperationException("SMTP password is not configured.");
        var senderEmail = section["SenderEmail"]
            ?? throw new InvalidOperationException("Sender email is not configured.");
        var senderName = section["SenderName"] ?? "MindPal Team";

        if (port <= 0)
            throw new InvalidOperationException("SMTP port is invalid.");

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(senderName, senderEmail));
        message.To.Add(new MailboxAddress(displayName, recipientEmail));
        message.Subject = content.Subject;
        message.Body = new BodyBuilder
        {
            TextBody = content.Text,
            HtmlBody = content.Html
        }.ToMessageBody();

        using var client = new SmtpClient();
        await client.ConnectAsync(host, port, SecureSocketOptions.StartTls,
            cancellationToken);
        try
        {
            await client.AuthenticateAsync(username, password, cancellationToken);
            await client.SendAsync(message, cancellationToken);
        }
        finally
        {
            if (client.IsConnected)
                await client.DisconnectAsync(true, cancellationToken);
        }
    }
}


using System.Net;
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace MindPal.Api.Email;

public sealed class SmtpEmailSender(IConfiguration configuration)
{
    public async Task SendVerificationCodeAsync(
        string recipientEmail,
        string displayName,
        string code,
        CancellationToken cancellationToken = default)
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

        var safeName = WebUtility.HtmlEncode(displayName);

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(senderName, senderEmail));
        message.To.Add(new MailboxAddress(displayName, recipientEmail));
        message.Subject = "Your MindPal verification code";

        var body = new BodyBuilder
        {
            TextBody =
                $"Hi {displayName},\n\n" +
                "Your MindPal code to confirm your email address is:\n\n" +
                $"{code}\n\n" +
                "The code expires in 10 minutes. " +
                "If you did not ask for it, you can ignore this email.",

            HtmlBody =
                $"<p>Hi {safeName},</p>" +
                "<p>Your MindPal code to confirm your email address is:</p>" +
                $"<p style=\"font-size:24px;font-weight:bold;letter-spacing:4px\">{code}</p>" +
                "<p>The code expires in 10 minutes. " +
                "If you did not ask for it, you can ignore this email.</p>"
        };

        message.Body = body.ToMessageBody();

        using var client = new SmtpClient();

        await client.ConnectAsync(
            host,
            port,
            SecureSocketOptions.StartTls,
            cancellationToken);

        try
        {
            await client.AuthenticateAsync(
                username,
                password,
                cancellationToken);

            await client.SendAsync(message, cancellationToken);
        }
        finally
        {
            if (client.IsConnected)
            {
                await client.DisconnectAsync(
                    true,
                    cancellationToken);
            }
        }
    }

    public async Task SendPasswordResetCodeAsync(
        string recipientEmail,
        string displayName,
        string code,
        CancellationToken cancellationToken = default)
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

        var safeName = WebUtility.HtmlEncode(displayName);

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(senderName, senderEmail));
        message.To.Add(new MailboxAddress(displayName, recipientEmail));
        message.Subject = "Your MindPal password reset code";

        var body = new BodyBuilder
        {
            TextBody =
                $"Hi {displayName},\n\n" +
                "Your MindPal password reset code is:\n\n" +
                $"{code}\n\n" +
                "This code expires in 10 minutes and can only be used once. " +
                "If you did not request a password reset, you can ignore this email.",

            HtmlBody =
                $"<p>Hi {safeName},</p>" +
                "<p>Your MindPal password reset code is:</p>" +
                $"<p style=\"font-size:24px;font-weight:bold;letter-spacing:4px\">{code}</p>" +
                "<p>This code expires in 10 minutes and can only be used once. " +
                "If you did not request a password reset, you can ignore this email.</p>"
        };

        message.Body = body.ToMessageBody();

        using var client = new SmtpClient();

        await client.ConnectAsync(
            host,
            port,
            SecureSocketOptions.StartTls,
            cancellationToken);

        try
        {
            await client.AuthenticateAsync(
                username,
                password,
                cancellationToken);

            await client.SendAsync(message, cancellationToken);
        }
        finally
        {
            if (client.IsConnected)
            {
                await client.DisconnectAsync(
                    true,
                    cancellationToken);
            }
        }
    }
}

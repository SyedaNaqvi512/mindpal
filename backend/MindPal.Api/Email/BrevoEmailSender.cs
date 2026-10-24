using System.Net.Http.Headers;
using System.Net.Http.Json;

namespace MindPal.Api.Email;

/// Sends email through Brevo's HTTPS API (SRS section 2.7). Works on hosts that
/// block SMTP ports. Needs Email:Brevo:ApiKey and Email:Brevo:SenderEmail
/// (a sender verified in the Brevo account).
public sealed class BrevoEmailSender(
    HttpClient http,
    IConfiguration configuration,
    ILogger<BrevoEmailSender> logger) : IEmailSender
{
    public const string Endpoint = "https://api.brevo.com/v3/smtp/email";

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
        var section = configuration.GetSection("Email:Brevo");

        var apiKey = section["ApiKey"];
        if (string.IsNullOrWhiteSpace(apiKey))
            throw new InvalidOperationException("Brevo API key is not configured.");

        var senderEmail = section["SenderEmail"];
        if (string.IsNullOrWhiteSpace(senderEmail))
            throw new InvalidOperationException("Brevo sender email is not configured.");

        var senderName = section["SenderName"] ?? "MindPal Team";

        var payload = new
        {
            sender = new { name = senderName, email = senderEmail },
            to = new[] { new { email = recipientEmail, name = displayName } },
            subject = content.Subject,
            htmlContent = content.Html,
            textContent = content.Text
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, Endpoint)
        {
            Content = JsonContent.Create(payload)
        };
        request.Headers.Add("api-key", apiKey);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        using var response = await http.SendAsync(request, cancellationToken);
        if (response.IsSuccessStatusCode) return;

        // The reply explains problems such as an unverified sender. It does not
        // contain the code or the recipient, so it is safe to log.
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        if (body.Length > 300) body = body[..300];
        logger.LogError("Brevo rejected an email: {Status} {Body}",
            (int)response.StatusCode, body);

        throw new InvalidOperationException(
            $"The email service returned {(int)response.StatusCode}.");
    }
}

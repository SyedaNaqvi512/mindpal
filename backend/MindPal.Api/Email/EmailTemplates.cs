using System.Net;

namespace MindPal.Api.Email;

public sealed record EmailContent(string Subject, string Text, string Html);

/// The wording of the emails, shared by every sender so they never differ.
public static class EmailTemplates
{
    private const string CodeStyle =
        "font-size:24px;font-weight:bold;letter-spacing:4px";

    public static EmailContent Verification(string displayName, string code)
    {
        var safeName = WebUtility.HtmlEncode(displayName);
        return new EmailContent(
            "Your MindPal verification code",
            $"Hi {displayName},\n\n" +
            "Your MindPal code to confirm your email address is:\n\n" +
            $"{code}\n\n" +
            "The code expires in 10 minutes. " +
            "If you did not ask for it, you can ignore this email.",
            $"<p>Hi {safeName},</p>" +
            "<p>Your MindPal code to confirm your email address is:</p>" +
            $"<p style=\"{CodeStyle}\">{WebUtility.HtmlEncode(code)}</p>" +
            "<p>The code expires in 10 minutes. " +
            "If you did not ask for it, you can ignore this email.</p>");
    }

    public static EmailContent PasswordReset(string displayName, string code)
    {
        var safeName = WebUtility.HtmlEncode(displayName);
        return new EmailContent(
            "Your MindPal password reset code",
            $"Hi {displayName},\n\n" +
            "Your MindPal password reset code is:\n\n" +
            $"{code}\n\n" +
            "This code expires in 10 minutes and can only be used once. " +
            "If you did not request a password reset, you can ignore this email.",
            $"<p>Hi {safeName},</p>" +
            "<p>Your MindPal password reset code is:</p>" +
            $"<p style=\"{CodeStyle}\">{WebUtility.HtmlEncode(code)}</p>" +
            "<p>This code expires in 10 minutes and can only be used once. " +
            "If you did not request a password reset, you can ignore this email.</p>");
    }
}

using System.Text.RegularExpressions;

namespace MindPal.Api.Reflection;

public static class SafetyScreener
{
    private static readonly string[] HighRiskPhrases =
    [
        "kill myself", "end my life", "suicide", "suicidal", "want to die",
        "hurt myself", "harm myself", "self harm", "self-harm", "cut myself",
        "don't want to live", "do not want to live", "better off dead", "end it all"
    ];

    // Shown instead of an AI reflection. No phone numbers are written here on purpose.
    public const string SupportMessage =
        "It sounds like you may be going through something very painful. " +
        "MindPal cannot help with this, and it cannot reliably detect every crisis. " +
        "Please contact a trusted person near you, or your local emergency or crisis service, right now.";

    public static bool IsHighRisk(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return false;
        var t = Regex.Replace(text.ToLowerInvariant().Replace('\u2019', '\''), @"\s+", " ");
        return HighRiskPhrases.Any(t.Contains);
    }
}
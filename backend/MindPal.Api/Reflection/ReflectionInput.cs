namespace MindPal.Api.Reflection;

public static class ReflectionInput
{
    public const int MaxLength = 5000;   // Week 4 design

    // Returns an error message, or null when the text is valid.
    public static string? Validate(string? text, out string cleaned)
    {
        cleaned = text?.Trim() ?? "";
        if (cleaned.Length == 0) return "Text is required.";
        if (cleaned.Length > MaxLength) return $"Text must be {MaxLength} characters or fewer.";
        return null;
    }
}
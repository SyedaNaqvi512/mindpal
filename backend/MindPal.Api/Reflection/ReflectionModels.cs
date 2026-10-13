namespace MindPal.Api.Reflection;

public static class ThinkingPatterns
{
    public static readonly string[] All =
    [
        "all_or_nothing", "catastrophizing", "mind_reading", "overgeneralization",
        "emotional_reasoning", "should_statements", "personalization", "labeling",
        "mental_filter", "none"
    ];
}

public record ReflectionResult(
    string Acknowledgement,
    string ThinkingPattern,
    string[] Questions,
    string BalancedThought,
    string NextStep)
{
    // Plain-text version, so the current app keeps working
    public string ToText() =>
        $"{Acknowledgement}\n\n" +
        string.Join("\n", Questions.Select(q => "- " + q)) + "\n\n" +
        $"A balanced thought: {BalancedThought}\n\n" +
        $"A small next step: {NextStep}";
}
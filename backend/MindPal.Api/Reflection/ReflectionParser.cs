using System.Text.Json;

namespace MindPal.Api.Reflection;

// Checks the AI's answer before it reaches the user.
public static class ReflectionParser
{
    private const int MaxPart = 800;

    public static ReflectionResult? TryParse(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return null;
        try
        {
            using var doc = JsonDocument.Parse(json);
            var r = doc.RootElement;
            if (r.ValueKind != JsonValueKind.Object) return null;

            var ack = Str(r, "acknowledgement");
            var balanced = Str(r, "balancedThought");
            var next = Str(r, "nextStep");
            if (ack is null || balanced is null || next is null) return null;

            if (!r.TryGetProperty("questions", out var q) || q.ValueKind != JsonValueKind.Array) return null;
            var questions = q.EnumerateArray()
                .Where(x => x.ValueKind == JsonValueKind.String)
                .Select(x => x.GetString()!.Trim())
                .Where(x => x.Length > 0 && x.Length <= MaxPart)
                .Take(2).ToArray();
            if (questions.Length == 0) return null;

            var pattern = (Str(r, "thinkingPattern") ?? "none").ToLowerInvariant()
                .Replace('-', '_').Replace(' ', '_');
            if (!ThinkingPatterns.All.Contains(pattern)) pattern = "none";

            return new ReflectionResult(ack, pattern, questions, balanced, next);
        }
        catch (JsonException) { return null; }
    }

    private static string? Str(JsonElement r, string name)
    {
        if (!r.TryGetProperty(name, out var v) || v.ValueKind != JsonValueKind.String) return null;
        var s = v.GetString()?.Trim();
        return string.IsNullOrEmpty(s) || s.Length > MaxPart ? null : s;
    }
}
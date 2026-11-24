using System.Text.Json;
using System.Text.Json.Serialization;

namespace MindPal.Api.Reflection;

// One saved message of the conversation. Role is "user" or "assistant".
public record FollowUpMessage(string? Role, string? Text);

// The phone sends everything the AI needs to remember. The server keeps nothing.
public record FollowUpRequest(
    string? Entry,
    string? Reflection,
    FollowUpMessage[]? History,
    string? Message);

public record FollowUpReply(string Reply, string[] Suggestions)
{
    // Used for server-side logging only.
    [JsonIgnore]
    public string? ModelUsed { get; init; }
}

public sealed record FollowUpContext(
    string Entry,
    string Reflection,
    IReadOnlyList<FollowUpMessage> History,
    string Message);

// A reason the request is refused, with the HTTP status and a stable code.
public sealed record FollowUpIssue(int Status, string Code, string Message);

public static class FollowUpLimits
{
    // Questions the user can ask after the reflection, for one entry.
    public const int MaxQuestions = 10;

    public const int MaxMessageChars = 500;
    public const int MaxReflectionChars = 4000;
    public const int MaxHistoryChars = 3000;
    public const int MaxHistoryMessages = (MaxQuestions - 1) * 2;
    public const int MaxTotalChars = 40000;

    // Per user, rolling windows (successful answers).
    public const int MaxPerHour = 40;
    public const int MaxPerDay = 100;

    // Abuse guard: counts failed attempts too.
    public const int MaxAttemptsPerHour = 80;

    // Follow-ups are written to ai_usage_logs with this model prefix so they
    // are not counted as reflections.
    public const string ModelPrefix = "followup:";

    public static bool IsExceeded(int inLastHour, int inLastDay) =>
        inLastHour >= MaxPerHour || inLastDay >= MaxPerDay;

    public static bool IsAttemptCapExceeded(int attemptsLastHour) =>
        attemptsLastHour >= MaxAttemptsPerHour;
}

public static class FollowUpRules
{
    private static FollowUpIssue Bad(string message) =>
        new(400, "validation_failed", message);

    // Returns null when the request is fine, otherwise the reason it is refused.
    public static FollowUpIssue? Validate(FollowUpRequest? req, out FollowUpContext? ctx)
    {
        ctx = null;
        if (req is null) return Bad("Send the entry, the reflection and your question.");

        var entry = req.Entry?.Trim() ?? "";
        if (entry.Length == 0) return Bad("The journal entry is required.");
        if (entry.Length > ReflectionInput.MaxLength)
            return Bad($"The entry must be {ReflectionInput.MaxLength} characters or fewer.");

        var reflection = req.Reflection?.Trim() ?? "";
        if (reflection.Length == 0) return Bad("The reflection is required.");
        if (reflection.Length > FollowUpLimits.MaxReflectionChars)
            return Bad("The reflection is too long.");

        var message = req.Message?.Trim() ?? "";
        if (message.Length == 0) return Bad("Type your question first.");
        if (message.Length > FollowUpLimits.MaxMessageChars)
            return Bad($"Keep your message under {FollowUpLimits.MaxMessageChars} characters.");

        var raw = req.History ?? Array.Empty<FollowUpMessage>();
        if (raw.Length > FollowUpLimits.MaxHistoryMessages + 2)
            return Bad("The conversation is too long.");
        if (raw.Length % 2 != 0)
            return Bad("The conversation is incomplete. Each question needs its answer.");

        var history = new List<FollowUpMessage>(raw.Length);
        var total = entry.Length + reflection.Length + message.Length;
        for (var i = 0; i < raw.Length; i++)
        {
            var expected = i % 2 == 0 ? "user" : "assistant";
            var role = raw[i]?.Role?.Trim().ToLowerInvariant() ?? "";
            if (role != expected) return Bad("The conversation order is not valid.");

            var text = raw[i]?.Text?.Trim() ?? "";
            if (text.Length == 0) return Bad("The conversation has an empty message.");
            if (text.Length > FollowUpLimits.MaxHistoryChars)
                return Bad("A message in the conversation is too long.");

            total += text.Length;
            history.Add(new FollowUpMessage(role, text));
        }

        if (total > FollowUpLimits.MaxTotalChars) return Bad("The conversation is too long.");

        if (QuestionsUsed(history) >= FollowUpLimits.MaxQuestions)
        {
            return new FollowUpIssue(
                409,
                "followup_limit_reached",
                $"You have used all {FollowUpLimits.MaxQuestions} questions for this entry. " +
                "Start a new entry to talk more.");
        }

        ctx = new FollowUpContext(entry, reflection, history, message);
        return null;
    }

    // Each completed question and answer pair counts once.
    public static int QuestionsUsed(IReadOnlyCollection<FollowUpMessage> history) =>
        history.Count / 2;
}

// Checks the AI's answer before it reaches the user.
public static class FollowUpParser
{
    private const int MaxReply = 1800;
    private const int MaxSuggestion = 60;

    public static FollowUpReply? TryParse(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return null;
        try
        {
            using var doc = JsonDocument.Parse(json);
            var r = doc.RootElement;
            if (r.ValueKind != JsonValueKind.Object) return null;

            if (!r.TryGetProperty("reply", out var v) || v.ValueKind != JsonValueKind.String)
                return null;
            var reply = Clean(v.GetString());
            if (reply.Length == 0 || reply.Length > MaxReply) return null;

            var suggestions = new List<string>();
            if (r.TryGetProperty("suggestions", out var s) && s.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in s.EnumerateArray())
                {
                    if (item.ValueKind != JsonValueKind.String) continue;
                    var t = (item.GetString() ?? "").Trim();
                    if (t.Length > 0 && t.Length <= MaxSuggestion) suggestions.Add(t);
                    if (suggestions.Count == 3) break;
                }
            }

            return new FollowUpReply(reply, suggestions.ToArray());
        }
        catch (JsonException) { return null; }
    }

    // Plain text with light formatting only: paragraphs, "- " bullets, **bold**.
    private static string Clean(string? s)
    {
        var t = (s ?? "").Replace("\r\n", "\n").Replace('\r', '\n');
        t = t.Replace("```", "").Replace("<", "").Replace(">", "");
        while (t.Contains("\n\n\n")) t = t.Replace("\n\n\n", "\n\n");
        return t.Trim();
    }
}

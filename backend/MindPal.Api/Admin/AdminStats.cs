namespace MindPal.Api.Admin;

public record DayCount(string Date, int Count);

// Pure rules and helpers for the admin portal (FR-54 to FR-61). Nothing here
// touches the database, so every rule can be tested on its own.
public static class AdminStats
{
    public const int DefaultDays = 14;
    public const int MaxDays = 90;
    public const int DefaultPageSize = 20;
    public const int MaxPageSize = 100;
    public const int MaxSearchLength = 100;

    // Asia/Karachi is UTC+5 all year (FR-55). The same offset is used when a
    // daily active user is recorded.
    public static readonly TimeSpan KarachiOffset = TimeSpan.FromHours(5);

    // The exercises the app can report (FR-61). Anything else is rejected.
    public static readonly string[] ExerciseTypes =
    [
        "sort", "scale", "belief", "breathing", "grounding", "thought_record",
        "gratitude", "self_compassion", "problem_solving", "check_in", "stop",
        "anchor", "body_scan"
    ];

    public static int ClampDays(int? days) =>
        days is null or < 1 ? DefaultDays : Math.Min(days.Value, MaxDays);

    public static (int Page, int PageSize) ClampPage(int? page, int? pageSize) =>
        (page is null or < 1 ? 1 : Math.Min(page.Value, 100_000),
         pageSize is null or < 1 ? DefaultPageSize : Math.Min(pageSize.Value, MaxPageSize));

    // Lower-case, trimmed and shortened, so a search cannot be abused.
    public static string SearchTerm(string? raw)
    {
        var t = (raw ?? "").Trim().ToLowerInvariant();
        return t.Length > MaxSearchLength ? t[..MaxSearchLength] : t;
    }

    public static DateOnly KarachiDate(DateTime utc) =>
        DateOnly.FromDateTime(utc.Add(KarachiOffset));

    public static DateOnly KarachiToday(DateTime utcNow) => KarachiDate(utcNow);

    // The moment (in UTC) when a Karachi day starts.
    public static DateTime StartOfKarachiDayUtc(DateOnly day) =>
        DateTime.SpecifyKind(
            day.ToDateTime(TimeOnly.MinValue) - KarachiOffset,
            DateTimeKind.Utc);

    // One entry for each of the last [days] days, oldest first, with zero for
    // days that had no events.
    public static List<DayCount> Series(
        DateOnly today, int days, IReadOnlyDictionary<DateOnly, int> counts)
    {
        var list = new List<DayCount>(days);

        for (var i = days - 1; i >= 0; i--)
        {
            var d = today.AddDays(-i);
            list.Add(new DayCount(
                d.ToString("yyyy-MM-dd"),
                counts.TryGetValue(d, out var n) ? n : 0));
        }

        return list;
    }

    // Counts events per Karachi day from their UTC times.
    public static Dictionary<DateOnly, int> CountByDay(IEnumerable<DateTime> utcTimes)
    {
        var map = new Dictionary<DateOnly, int>();

        foreach (var t in utcTimes)
        {
            var d = KarachiDate(t);
            map[d] = map.TryGetValue(d, out var n) ? n + 1 : 1;
        }

        return map;
    }

    // Percentage with one decimal; 0 when there is nothing to divide.
    public static double Percent(int part, int total) =>
        total <= 0 ? 0 : Math.Round(100.0 * part / total, 1);

    public static double AverageMs(IEnumerable<int> values)
    {
        var list = values.ToList();
        return list.Count == 0 ? 0 : Math.Round(list.Average(), 0);
    }

    // ---- who can be changed by an admin (FR-56) ----

    public static bool CanSuspend(Guid actorId, Guid targetId, string role, string status) =>
        actorId != targetId && role != "admin" && status == "active";

    public static bool CanReactivate(string status) => status == "suspended";

    public static bool CanProcessDeletion(string role, string status) =>
        role != "admin" && status == "pending_deletion";

    public static bool IsKnownExercise(string? type) =>
        type is not null && ExerciseTypes.Contains(type);
}
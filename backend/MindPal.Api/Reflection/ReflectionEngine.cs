namespace MindPal.Api.Reflection;

// The AI provider is replaceable: anything that implements this
// interface can power reflections.
public interface IReflectionEngine
{
    Task<ReflectionResult> ReflectAsync(
        string text,
        CancellationToken ct);
}

// Status is "timeout" or "error"
// (values allowed in ai_usage_logs).
public class ReflectionException(string status, string message)
    : Exception(message)
{
    public string Status { get; } = status;
}

public static class ReflectionLimits
{
    // Successful reflection request limits (rolling windows).
    public const int MaxPerHour = 10;
    public const int MaxPerDay = 30;

    // Abuse guard: counts failed attempts too.
    public const int MaxAttemptsPerHour = 30;

    // Checks successful reflection limits.
    public static bool IsExceeded(int inLastHour, int inLastDay) =>
        inLastHour >= MaxPerHour ||
        inLastDay >= MaxPerDay;

    // Checks the total number of attempts, including failed attempts.
    public static bool IsAttemptCapExceeded(int attemptsLastHour) =>
        attemptsLastHour >= MaxAttemptsPerHour;
}
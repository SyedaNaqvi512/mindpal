namespace MindPal.Api.Reflection;

// The AI provider is replaceable: anything that implements this can power reflections.
public interface IReflectionEngine
{
    Task<ReflectionResult> ReflectAsync(string text, CancellationToken ct);
}

// Status is "timeout" or "error" (values allowed in ai_usage_logs).
public class ReflectionException(string status, string message) : Exception(message)
{
    public string Status { get; } = status;
}

public static class ReflectionLimits
{
    public const int MaxPerHour = 10;   // SRS v1.1
    public const int MaxPerDay = 30;    // rolling 24 hours

    public static bool IsExceeded(int inLastHour, int inLastDay)
        => inLastHour >= MaxPerHour || inLastDay >= MaxPerDay;
}
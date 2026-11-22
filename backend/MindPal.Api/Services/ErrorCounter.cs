using System.Collections.Concurrent;

namespace MindPal.Api.Services;

// Counts unexpected server errors for the admin health page (FR-59).
// Only the time of each error is kept, nothing about the request.
public static class ErrorCounter
{
    private static readonly ConcurrentQueue<DateTime> Hits = new();

    public static void Record()
    {
        Hits.Enqueue(DateTime.UtcNow);
        Trim();
    }

    public static int CountSince(TimeSpan span)
    {
        Trim();
        var cut = DateTime.UtcNow - span;
        return Hits.Count(t => t >= cut);
    }

    private static void Trim()
    {
        var cut = DateTime.UtcNow.AddHours(-24);

        while (Hits.TryPeek(out var t) && t < cut)
            Hits.TryDequeue(out _);
    }
}
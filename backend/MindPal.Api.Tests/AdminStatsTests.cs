using MindPal.Api.Admin;
using MindPal.Api.Services;

namespace MindPal.Api.Tests;

public class AdminStatsTests
{
    [Fact]
    public void KarachiDate_RollsOverAtMidnightKarachi()
    {
        // 18:59 UTC is 23:59 in Karachi, 19:00 UTC is 00:00 the next day.
        Assert.Equal(new DateOnly(2026, 11, 20),
            AdminStats.KarachiDate(new DateTime(2026, 11, 20, 18, 59, 0, DateTimeKind.Utc)));
        Assert.Equal(new DateOnly(2026, 11, 21),
            AdminStats.KarachiDate(new DateTime(2026, 11, 20, 19, 0, 0, DateTimeKind.Utc)));
    }

    [Fact]
    public void StartOfKarachiDay_IsFiveHoursBeforeUtcMidnight()
    {
        var s = AdminStats.StartOfKarachiDayUtc(new DateOnly(2026, 11, 21));
        Assert.Equal(new DateTime(2026, 11, 20, 19, 0, 0, DateTimeKind.Utc), s);
        Assert.Equal(DateTimeKind.Utc, s.Kind);
    }

    [Theory]
    [InlineData(null, 14)]
    [InlineData(0, 14)]
    [InlineData(-5, 14)]
    [InlineData(7, 7)]
    [InlineData(500, 90)]
    public void ClampDays_StaysInRange(int? input, int expected) =>
        Assert.Equal(expected, AdminStats.ClampDays(input));

    [Fact]
    public void ClampPage_UsesDefaultsAndLimits()
    {
        Assert.Equal((1, 20), AdminStats.ClampPage(null, null));
        Assert.Equal((1, 20), AdminStats.ClampPage(0, 0));
        Assert.Equal((3, 100), AdminStats.ClampPage(3, 5000));
    }

    [Fact]
    public void SearchTerm_TrimsLowercasesAndShortens()
    {
        Assert.Equal("ali@x.com", AdminStats.SearchTerm("  Ali@X.com "));
        Assert.Equal("", AdminStats.SearchTerm(null));
        Assert.Equal(100, AdminStats.SearchTerm(new string('A', 300)).Length);
    }

    [Fact]
    public void Series_FillsEveryDayOldestFirst()
    {
        var today = new DateOnly(2026, 11, 21);
        var counts = new Dictionary<DateOnly, int>
        {
            [today] = 4,
            [today.AddDays(-2)] = 1
        };

        var s = AdminStats.Series(today, 3, counts);

        Assert.Equal(3, s.Count);
        Assert.Equal(new DayCount("2026-11-19", 1), s[0]);
        Assert.Equal(new DayCount("2026-11-20", 0), s[1]);
        Assert.Equal(new DayCount("2026-11-21", 4), s[2]);
    }

    [Fact]
    public void CountByDay_GroupsByKarachiDay()
    {
        var times = new[]
        {
            new DateTime(2026, 11, 20, 10, 0, 0, DateTimeKind.Utc),
            new DateTime(2026, 11, 20, 18, 0, 0, DateTimeKind.Utc),
            new DateTime(2026, 11, 20, 20, 0, 0, DateTimeKind.Utc)  // next day in Karachi
        };

        var m = AdminStats.CountByDay(times);

        Assert.Equal(2, m[new DateOnly(2026, 11, 20)]);
        Assert.Equal(1, m[new DateOnly(2026, 11, 21)]);
    }

    [Fact]
    public void Percent_RoundsAndHandlesZero()
    {
        Assert.Equal(0, AdminStats.Percent(0, 0));
        Assert.Equal(66.7, AdminStats.Percent(2, 3));
        Assert.Equal(100, AdminStats.Percent(5, 5));
    }

    [Fact]
    public void AverageMs_HandlesEmptyAndValues()
    {
        Assert.Equal(0, AdminStats.AverageMs([]));
        Assert.Equal(200, AdminStats.AverageMs([100, 300]));
    }

    [Fact]
    public void CanSuspend_OnlyActiveOtherNonAdmins()
    {
        var me = Guid.NewGuid();
        var other = Guid.NewGuid();

        Assert.True(AdminStats.CanSuspend(me, other, "user", "active"));
        Assert.False(AdminStats.CanSuspend(me, me, "user", "active"));
        Assert.False(AdminStats.CanSuspend(me, other, "admin", "active"));
        Assert.False(AdminStats.CanSuspend(me, other, "user", "suspended"));
        Assert.False(AdminStats.CanSuspend(me, other, "user", "pending_deletion"));
    }

    [Fact]
    public void CanReactivate_OnlySuspended()
    {
        Assert.True(AdminStats.CanReactivate("suspended"));
        Assert.False(AdminStats.CanReactivate("active"));
        Assert.False(AdminStats.CanReactivate("pending_deletion"));
    }

    [Fact]
    public void CanProcessDeletion_OnlyPendingNonAdmins()
    {
        Assert.True(AdminStats.CanProcessDeletion("user", "pending_deletion"));
        Assert.False(AdminStats.CanProcessDeletion("admin", "pending_deletion"));
        Assert.False(AdminStats.CanProcessDeletion("user", "active"));
    }

    [Fact]
    public void IsKnownExercise_AcceptsOnlyListedTypes()
    {
        Assert.True(AdminStats.IsKnownExercise("breathing"));
        Assert.True(AdminStats.IsKnownExercise("thought_record"));
        Assert.False(AdminStats.IsKnownExercise("hack"));
        Assert.False(AdminStats.IsKnownExercise(null));
        Assert.Equal(13, AdminStats.ExerciseTypes.Length);
    }

    [Fact]
    public void ErrorCounter_CountsRecentErrors()
    {
        var before = ErrorCounter.CountSince(TimeSpan.FromHours(24));
        ErrorCounter.Record();
        Assert.Equal(before + 1, ErrorCounter.CountSince(TimeSpan.FromHours(24)));
    }
}
using MindPal.Api.Auth;

namespace MindPal.Api.Tests;

public class AccountDeletionTests
{
    [Fact]
    public void PendingStatus_MatchesTheDatabaseConstraint()
        => Assert.Equal("pending_deletion", AccountDeletion.PendingStatus);

    [Fact]
    public void PurgeHappensWellInsideTheSevenDayLimit()
    {
        Assert.Equal(TimeSpan.FromDays(7), AccountDeletion.Deadline);
        Assert.True(AccountDeletion.PurgeAfter < AccountDeletion.Deadline);
    }

    [Fact]
    public void NotDueBeforeTheGracePeriod()
    {
        var now = new DateTime(2026, 10, 23, 12, 0, 0, DateTimeKind.Utc);
        Assert.False(AccountDeletion.IsDue(now.AddHours(-23), now));
        Assert.False(AccountDeletion.IsDue(null, now));
    }

    [Fact]
    public void DueAfterTheGracePeriod()
    {
        var now = new DateTime(2026, 10, 23, 12, 0, 0, DateTimeKind.Utc);
        Assert.True(AccountDeletion.IsDue(now.AddHours(-24), now));
        Assert.True(AccountDeletion.IsDue(now.AddDays(-3), now));
    }

    [Theory]
    [InlineData("active", true)]
    [InlineData("pending_deletion", false)]
    [InlineData("suspended", false)]
    [InlineData(null, false)]
    public void OnlyActiveAccountsCanSignIn(string? status, bool expected)
        => Assert.Equal(expected, AccountDeletion.CanSignIn(status));
}

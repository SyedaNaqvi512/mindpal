using MindPal.Api.Services;

namespace MindPal.Api.Tests;

public class TokenRetentionTests
{
    private static readonly DateTime Now = new(2026, 11, 2, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void ATokenThatIsStillValidIsNeverRemoved()
        => Assert.False(TokenRetention.IsRemovable(Now.AddMinutes(10), Now));

    [Fact]
    public void ATokenThatExpiredJustNowIsKeptForTheMargin()
    {
        Assert.False(TokenRetention.IsRemovable(Now.AddMinutes(-1), Now));
        Assert.False(TokenRetention.IsRemovable(Now.AddHours(-23), Now));
    }

    [Fact]
    public void ATokenExpiredForMoreThanTheMarginIsRemoved()
    {
        Assert.True(TokenRetention.IsRemovable(Now.AddDays(-1), Now));
        Assert.True(TokenRetention.IsRemovable(Now.AddDays(-30), Now));
    }

    [Fact]
    public void TheMarginIsOneDay()
        => Assert.Equal(TimeSpan.FromDays(1), TokenRetention.KeepExpiredFor);
}

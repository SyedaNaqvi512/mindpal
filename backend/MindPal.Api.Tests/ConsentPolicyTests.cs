using MindPal.Api.Consents;

namespace MindPal.Api.Tests;

public class ConsentPolicyTests
{
    [Fact]
    public void Type_MatchesDatabaseCheckConstraint()
        => Assert.Equal("ai_processing", ConsentPolicy.AiProcessing);

    [Fact]
    public void CurrentVersion_FitsTheTenCharacterColumn()
    {
        Assert.False(string.IsNullOrWhiteSpace(ConsentPolicy.CurrentVersion));
        Assert.True(ConsentPolicy.CurrentVersion.Length <= 10);
    }
}

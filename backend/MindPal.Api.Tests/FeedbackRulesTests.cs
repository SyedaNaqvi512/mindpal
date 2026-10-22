using MindPal.Api.Reflection;

namespace MindPal.Api.Tests;

public class FeedbackRulesTests
{
    [Theory]
    [InlineData("helpful", null)]
    [InlineData("helpful", "")]
    [InlineData("not_helpful", null)]
    [InlineData("not_helpful", "too_generic")]
    [InlineData("not_helpful", "other")]
    public void ValidRatings_AreAccepted(string rating, string? reason)
        => Assert.Null(FeedbackRules.Validate(rating, reason));

    [Theory]
    [InlineData(null, null)]
    [InlineData("", null)]
    [InlineData("great", null)]
    [InlineData("HELPFUL", null)]
    public void BadRatings_AreRejected(string? rating, string? reason)
        => Assert.NotNull(FeedbackRules.Validate(rating, reason));

    [Fact]
    public void ReasonOnHelpful_IsRejected()
        => Assert.NotNull(FeedbackRules.Validate("helpful", "too_long"));

    [Fact]
    public void UnknownReason_IsRejected()
        => Assert.NotNull(FeedbackRules.Validate("not_helpful", "boring"));

    [Fact]
    public void Reasons_MatchTheDatabaseConstraint()
        => Assert.Equal(
            new[] { "not_relevant", "too_generic", "felt_wrong", "too_long", "other" },
            FeedbackRules.Reasons);
}

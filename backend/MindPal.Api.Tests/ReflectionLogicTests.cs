using MindPal.Api.Reflection;

namespace MindPal.Api.Tests;

public class ReflectionLogicTests
{
    // ---- input validation ----
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Input_EmptyText_IsRejected(string? text)
        => Assert.NotNull(ReflectionInput.Validate(text, out _));

    [Fact]
    public void Input_5000Characters_IsAccepted_5001_IsRejected()
    {
        Assert.Null(ReflectionInput.Validate(new string('a', 5000), out _));
        Assert.NotNull(ReflectionInput.Validate(new string('a', 5001), out _));
    }

    [Fact]
    public void Input_IsTrimmed()
    {
        ReflectionInput.Validate("  hello  ", out var cleaned);
        Assert.Equal("hello", cleaned);
    }

    // ---- safety screening ----
    [Theory]
    [InlineData("I want to kill myself")]
    [InlineData("I feel like I DON\u2019T WANT TO LIVE anymore")]
    [InlineData("thinking about self-harm")]
    public void Safety_HighRiskText_IsDetected(string text)
        => Assert.True(SafetyScreener.IsHighRisk(text));

    [Theory]
    [InlineData("I feel stressed about my exams")]
    [InlineData("I killed my presentation today")]
    [InlineData("")]
    public void Safety_NormalText_IsNotFlagged(string text)
        => Assert.False(SafetyScreener.IsHighRisk(text));

    // ---- output validation ----
    private const string Good = """
        {"acknowledgement":"That sounds stressful.","thinkingPattern":"catastrophizing",
         "questions":["What is the evidence?","What else could happen?"],
         "balancedThought":"One bad grade does not decide my future.","nextStep":"Make a study plan."}
        """;

    [Fact]
    public void Parser_ValidJson_ReturnsResult()
    {
        var r = ReflectionParser.TryParse(Good);
        Assert.NotNull(r);
        Assert.Equal("catastrophizing", r!.ThinkingPattern);
        Assert.Equal(2, r.Questions.Length);
        Assert.Contains("balanced thought", r.ToText());
    }

    [Fact]
    public void Parser_UnknownPattern_BecomesNone()
    {
        var r = ReflectionParser.TryParse(Good.Replace("catastrophizing", "made_up_pattern"));
        Assert.Equal("none", r!.ThinkingPattern);
    }

    [Theory]
    [InlineData("not json")]
    [InlineData("")]
    [InlineData("[]")]
    [InlineData("""{"acknowledgement":"x"}""")]
    public void Parser_BadOutput_ReturnsNull(string json)
        => Assert.Null(ReflectionParser.TryParse(json));
}
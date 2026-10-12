using Microsoft.IdentityModel.JsonWebTokens;
using MindPal.Api.Auth;
using MindPal.Api.Data;

namespace MindPal.Api.Tests;

public class TokenServiceTests
{
    private static TokenService Make() =>
        new(new JwtOptions { Key = "a-test-key-that-is-at-least-32-bytes-long!!" });

    private static User SampleUser() =>
        new() { Id = Guid.NewGuid(), Email = "ann@test.com", DisplayName = "Ann", Role = "user" };

    [Fact]
    public void AccessToken_ContainsUserClaims()
    {
        var user = SampleUser();
        var jwt = new JsonWebTokenHandler().ReadJsonWebToken(Make().CreateAccessToken(user));

        Assert.Equal(user.Id.ToString(), jwt.GetClaim("sub").Value);
        Assert.Equal("ann@test.com", jwt.GetClaim("email").Value);
        Assert.Equal("user", jwt.GetClaim("role").Value);
    }

    [Fact]
    public void AccessToken_ExpiresInAboutFifteenMinutes()
    {
        var jwt = new JsonWebTokenHandler().ReadJsonWebToken(Make().CreateAccessToken(SampleUser()));
        var now = DateTime.UtcNow;
        Assert.InRange(jwt.ValidTo, now.AddMinutes(14), now.AddMinutes(16));
    }

    [Fact]
    public void Settings_MatchSrs_15MinutesAnd7Days()
    {
        var svc = Make();
        Assert.Equal(900, svc.AccessSeconds);
        Assert.Equal(7, svc.RefreshDays);
    }

    [Fact]
    public void RefreshToken_IsRandomAndUnique()
    {
        var a = TokenService.NewRefreshToken();
        var b = TokenService.NewRefreshToken();
        Assert.NotEqual(a, b);
        Assert.True(a.Length >= 60);
    }

    [Fact]
    public void RefreshTokenHash_Is64HexChars_Deterministic_AndDiffersFromToken()
    {
        var raw = TokenService.NewRefreshToken();
        var h1 = TokenService.Hash(raw);
        Assert.Equal(64, h1.Length);
        Assert.Matches("^[0-9a-f]{64}$", h1);
        Assert.Equal(h1, TokenService.Hash(raw));
        Assert.NotEqual(raw, h1);
    }
}
namespace MindPal.Api.Auth;

public record RegisterRequest(string? DisplayName, string? Email, string? Password);
public record LoginRequest(string? Email, string? Password);
public record RefreshRequest(string? RefreshToken);

public record UserDto(Guid Id, string DisplayName, short AvatarId, string Email, string Role, bool EmailVerified);
public record AuthResponse(string AccessToken, int ExpiresIn, string RefreshToken, UserDto User);

public class JwtOptions
{
    public string Key { get; set; } = "";
    public string Issuer { get; set; } = "MindPal.Api";
    public string Audience { get; set; } = "MindPal.App";
    public int AccessMinutes { get; set; } = 15;   // SRS v1.1: access token 15 minutes
    public int RefreshDays { get; set; } = 7;      // SRS v1.1: refresh token 7 days
}
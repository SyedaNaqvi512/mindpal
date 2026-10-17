namespace MindPal.Api.Auth;

public record RegisterRequest(
    string? DisplayName,
    string? Email,
    string? Password,
    string? Gender = null);

public record LoginRequest(string? Email, string? Password);

public record RefreshRequest(string? RefreshToken);

public record VerifyEmailRequest(string? Email, string? Code);

public record ResendVerificationRequest(string? Email);

public record ForgotPasswordRequest(string? Email);

public record ResetPasswordRequest(
    string? Email,
    string? Code,
    string? NewPassword);

public record UpdateProfileRequest(
    string? DisplayName,
    short? AvatarId);
    public record ChangePasswordRequest(
    string? CurrentPassword,
    string? NewPassword);

public record UserDto(
    Guid Id,
    string DisplayName,
    short AvatarId,
    string Email,
    string Role,
    bool EmailVerified,
    string Gender);

public record AuthResponse(
    string AccessToken,
    int ExpiresIn,
    string RefreshToken,
    UserDto User);

public class JwtOptions
{
    public string Key { get; set; } = "";
    public string Issuer { get; set; } = "MindPal.Api";
    public string Audience { get; set; } = "MindPal.App";
    public int AccessMinutes { get; set; } = 15;
    public int RefreshDays { get; set; } = 7;
}
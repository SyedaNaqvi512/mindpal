using System.Text;

namespace MindPal.Api.Auth;

public static class PasswordHasher
{
    private const int WorkFactor = 12;

    // A real hash of a random value, used so that login takes similar time
    // whether or not the email exists (prevents user enumeration by timing).
    private static readonly string DummyHash = BCrypt.Net.BCrypt.HashPassword(Guid.NewGuid().ToString(), WorkFactor);

    public static string Hash(string password) => BCrypt.Net.BCrypt.HashPassword(password, WorkFactor);

    public static bool Verify(string password, string hash)
    {
        try { return BCrypt.Net.BCrypt.Verify(password, hash); }
        catch { return false; }
    }

    public static void BurnTime(string password) => BCrypt.Net.BCrypt.Verify(password, DummyHash);

    // bcrypt only uses the first 72 bytes, so longer passwords are rejected.
    public static string? Validate(string password)
    {
        if (password.Length < 8) return "Password must be at least 8 characters.";
        if (Encoding.UTF8.GetByteCount(password) > 72) return "Password is too long (maximum 72 bytes).";
        if (!password.Any(char.IsLetter) || !password.Any(char.IsDigit))
            return "Password must contain at least one letter and one digit.";
        return null;
    }
}
using MindPal.Api.Auth;

namespace MindPal.Api.Tests;

public class PasswordHasherTests
{
    [Fact]
    public void Hash_UsesBcryptWithWorkFactor12_AndIsNotPlaintext()
    {
        var hash = PasswordHasher.Hash("Test12345");
        Assert.StartsWith("$2a$12$", hash);
        Assert.DoesNotContain("Test12345", hash);
    }

    [Fact]
    public void Hash_SamePasswordTwice_GivesDifferentHashes_RandomSalt()
    {
        Assert.NotEqual(PasswordHasher.Hash("Test12345"), PasswordHasher.Hash("Test12345"));
    }

    [Fact]
    public void Verify_CorrectPassword_ReturnsTrue()
    {
        var hash = PasswordHasher.Hash("Test12345");
        Assert.True(PasswordHasher.Verify("Test12345", hash));
    }

    [Fact]
    public void Verify_WrongPassword_ReturnsFalse()
    {
        var hash = PasswordHasher.Hash("Test12345");
        Assert.False(PasswordHasher.Verify("Wrong12345", hash));
    }

    [Fact]
    public void Verify_InvalidHashText_ReturnsFalse_NotException()
    {
        Assert.False(PasswordHasher.Verify("Test12345", "not-a-bcrypt-hash"));
    }

    [Theory]
    [InlineData("Ab1")]            // too short
    [InlineData("abcdefgh")]       // no digit
    [InlineData("12345678")]       // no letter
    public void Validate_WeakPassword_ReturnsMessage(string password)
    {
        Assert.NotNull(PasswordHasher.Validate(password));
    }

    [Fact]
    public void Validate_StrongPassword_ReturnsNull()
    {
        Assert.Null(PasswordHasher.Validate("Test12345"));
    }

    [Fact]
    public void Validate_72Bytes_IsAccepted_73Bytes_IsRejected()
    {
        Assert.Null(PasswordHasher.Validate(new string('a', 71) + "1"));      // 72 bytes
        Assert.NotNull(PasswordHasher.Validate(new string('a', 72) + "1"));   // 73 bytes
    }
}
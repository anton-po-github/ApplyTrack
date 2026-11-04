using ApplyTrack.End.Security;

namespace ApplyTrack.End.Tests.Security;

public class Pbkdf2PasswordHasherTests
{
    private readonly Pbkdf2PasswordHasher _hasher = new();

    [Fact]
    public void Verify_CorrectPassword_ReturnsTrue()
    {
        string hash = _hasher.Hash("correct horse battery");

        Assert.True(_hasher.Verify("correct horse battery", hash));
    }

    [Fact]
    public void Verify_WrongPassword_ReturnsFalse()
    {
        string hash = _hasher.Hash("correct horse battery");

        Assert.False(_hasher.Verify("wrong password", hash));
    }

    [Fact]
    public void Hash_SamePasswordTwice_GivesDifferentHashes()
    {
        string first = _hasher.Hash("same password");
        string second = _hasher.Hash("same password");

        Assert.NotEqual(first, second); // random salt
    }

    [Fact]
    public void Hash_IsValidBase64_AndFitsDatabaseColumn()
    {
        string hash = _hasher.Hash("any password");

        Assert.Equal(48, Convert.FromBase64String(hash).Length); // 16 salt + 32 hash
        Assert.True(hash.Length <= 128); // PasswordHash varchar(128)
    }

    [Fact]
    public void Verify_NullStoredHash_ReturnsFalse_AndDoesNotThrow()
    {
        Assert.False(_hasher.Verify("whatever", null));
    }

    [Theory]
    [InlineData("")]
    [InlineData("not base64 !!!")]
    [InlineData("AAAA")] // valid Base64 but too short
    public void Verify_BrokenStoredHash_ReturnsFalse_AndDoesNotThrow(string broken)
    {
        Assert.False(_hasher.Verify("whatever", broken));
    }

    [Fact]
    public void CreateUnusableHash_IsWellFormed_AndFitsTheDatabaseColumn()
    {
        string hash = _hasher.CreateUnusableHash();

        Assert.Equal(48, Convert.FromBase64String(hash).Length);
        Assert.True(hash.Length <= 128);
    }

    [Fact]
    public void CreateUnusableHash_NeverMatchesAnyPassword()
    {
        string hash = _hasher.CreateUnusableHash();

        Assert.False(_hasher.Verify("password123", hash));
        Assert.False(_hasher.Verify("", hash));
        Assert.False(_hasher.Verify(hash, hash));
    }

    [Fact]
    public void CreateUnusableHash_IsDifferentEveryTime()
    {
        Assert.NotEqual(_hasher.CreateUnusableHash(), _hasher.CreateUnusableHash());
    }
}

using System.Security.Cryptography;

namespace ApplyTrack.End.Security;

public sealed class Pbkdf2PasswordHasher : IPasswordHasher
{
    private const int Iterations = 350_000;
    private const int SaltSize = 16;
    private const int HashSize = 32;
    private const int TotalSize = SaltSize + HashSize;

    // A real hash of a random password. Used when the stored hash is missing.
    private static readonly string DummyHash = CreateHash(
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
    );

    public string Hash(string password) => CreateHash(password);

    public bool Verify(string password, string? storedHash)
    {
        Span<byte> raw = stackalloc byte[TotalSize];

        bool wellFormed =
            storedHash is not null
            && Convert.TryFromBase64String(storedHash, raw, out int written)
            && written == TotalSize;

        if (!wellFormed)
        {
            Convert.TryFromBase64String(DummyHash, raw, out _);
        }

        byte[] actual = Rfc2898DeriveBytes.Pbkdf2(
            password,
            raw[..SaltSize],
            Iterations,
            HashAlgorithmName.SHA256,
            HashSize
        );

        // Constant-time compare. Defeats timing attacks.
        bool equal = CryptographicOperations.FixedTimeEquals(actual, raw[SaltSize..]);

        return wellFormed && equal;
    }

    private static string CreateHash(string password)
    {
        byte[] salt = RandomNumberGenerator.GetBytes(SaltSize);
        byte[] hash = Rfc2898DeriveBytes.Pbkdf2(
            password,
            salt,
            Iterations,
            HashAlgorithmName.SHA256,
            HashSize
        );

        byte[] combined = new byte[TotalSize];
        salt.CopyTo(combined, 0);
        hash.CopyTo(combined, SaltSize);
        return Convert.ToBase64String(combined);
    }
}

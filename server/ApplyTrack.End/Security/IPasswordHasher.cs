namespace ApplyTrack.End.Security;

public interface IPasswordHasher
{
    /// <summary>Returns Base64(salt + hash). Always fits varchar(128).</summary>
    string Hash(string password);

    /// <summary>
    /// storedHash can be null or broken. The result is then false,
    /// and the CPU work stays the same, so response time leaks nothing.
    /// </summary>
    bool Verify(string password, string? storedHash);
}

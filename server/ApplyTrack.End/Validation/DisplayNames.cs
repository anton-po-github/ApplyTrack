using System.Text;

namespace ApplyTrack.End.Validation;

public static class DisplayNames
{
    /// <summary>
    /// Makes a safe display name (1-80 characters) from the Google "name" claim.
    /// Falls back to the part of the email before "@".
    /// </summary>
    public static string FromGoogle(string? googleName, string email)
    {
        string name = Clean(googleName);

        if (name.Length == 0)
        {
            int at = email.IndexOf('@');
            name = Clean(at > 0 ? email[..at] : email);
        }

        return name.Length == 0 ? "User" : name;
    }

    // Removes control characters, repairs broken UTF-16, and cuts to 80 characters
    // without ever splitting an emoji in half.
    private static string Clean(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return string.Empty;

        var builder = new StringBuilder();

        foreach (Rune rune in text.Trim().EnumerateRunes()) // broken surrogates become U+FFFD
        {
            if (Rune.IsControl(rune))
                continue;

            if (builder.Length + rune.Utf16SequenceLength > AuthValidator.MaxDisplayNameLength)
                break;

            builder.Append(rune.ToString());
        }

        return builder.ToString().Trim();
    }
}

using System.Text;

namespace ApplyTrack.End.Services;

public static class LikeEscaper
{
    /// <summary>
    /// Turns user text into a "contains" pattern for LIKE / ILIKE.
    /// The characters \ % _ are escaped with a backslash, so they mean themselves.
    /// </summary>
    public static string ContainsPattern(string text)
    {
        var builder = new StringBuilder(text.Length + 2);
        builder.Append('%');

        foreach (char c in text)
        {
            if (c is '\\' or '%' or '_')
                builder.Append('\\');

            builder.Append(c);
        }

        builder.Append('%');
        return builder.ToString();
    }
}

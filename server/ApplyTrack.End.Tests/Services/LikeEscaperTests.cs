using ApplyTrack.End.Services;

namespace ApplyTrack.End.Tests.Services;

public class LikeEscaperTests
{
    [Theory]
    [InlineData("abc", "%abc%")]
    [InlineData("50%", @"%50\%%")]
    [InlineData("a_b", @"%a\_b%")]
    [InlineData(@"a\b", @"%a\\b%")]
    [InlineData(@"%_\", @"%\%\_\\%")]
    public void SpecialCharacters_AreEscaped(string input, string expected)
    {
        Assert.Equal(expected, LikeEscaper.ContainsPattern(input));
    }
}

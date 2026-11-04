using ApplyTrack.End.Validation;

namespace ApplyTrack.End.Tests.Validation;

public class DisplayNamesTests
{
    private const string Email = "john.doe@example.com";

    [Fact]
    public void NormalName_IsTrimmed() =>
        Assert.Equal("Anton Test", DisplayNames.FromGoogle("  Anton Test  ", Email));

    [Fact]
    public void NullName_FallsBackToTheEmailPart() =>
        Assert.Equal("john.doe", DisplayNames.FromGoogle(null, Email));

    [Fact]
    public void BlankName_FallsBackToTheEmailPart() =>
        Assert.Equal("john.doe", DisplayNames.FromGoogle("   ", Email));

    [Fact]
    public void LongName_IsCutTo80Characters()
    {
        string result = DisplayNames.FromGoogle(new string('N', 100), Email);

        Assert.Equal(new string('N', 80), result);
    }

    [Fact]
    public void CutNeverSplitsAnEmoji()
    {
        string name = new string('a', 79) + "😀"; // the emoji needs 2 units, only 1 is free

        string result = DisplayNames.FromGoogle(name, Email);

        Assert.Equal(new string('a', 79), result);
    }

    [Fact]
    public void ControlCharacters_AreRemoved() =>
        Assert.Equal("ABC", DisplayNames.FromGoogle("A\u0000B\nC", Email));

    [Fact]
    public void OnlyControlCharacters_FallBackToTheEmailPart() =>
        Assert.Equal("john.doe", DisplayNames.FromGoogle("\n\t", Email));

    [Fact]
    public void BrokenSurrogate_IsRepaired_NotThrown()
    {
        string result = DisplayNames.FromGoogle("ab" + (char)0xD800 + "cd", Email);

        Assert.Equal("ab\uFFFDcd", result);
    }
}

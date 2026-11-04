using ApplyTrack.End.Validation;

namespace ApplyTrack.End.Tests.Validation;

public class ProposalListValidatorTests
{
    [Fact]
    public void NoParameters_GiveDefaults()
    {
        var result = ProposalListValidator.Validate(null, null, null);

        Assert.NotNull(result.Query);
        Assert.Null(result.Query.Status);
        Assert.Null(result.Query.Search);
        Assert.Equal(20, result.Query.Limit);
    }

    [Fact]
    public void Search_IsTrimmed_AndBlankBecomesNull()
    {
        Assert.Equal(
            "flutter",
            ProposalListValidator.Validate(null, "  flutter ", null).Query!.Search
        );
        Assert.Null(ProposalListValidator.Validate(null, "   ", null).Query!.Search);
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(6)]
    public void BadStatus_IsRejected(int status)
    {
        var result = ProposalListValidator.Validate(status, null, null);

        Assert.Null(result.Query);
        Assert.True(result.Errors.ContainsKey("status"));
    }

    [Fact]
    public void AllStatuses_0To5_AreAccepted()
    {
        for (int status = 0; status <= 5; status++)
        {
            Assert.Equal(
                (short)status,
                ProposalListValidator.Validate(status, null, null).Query!.Status
            );
        }
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(51)]
    public void BadLimit_IsRejected(int limit)
    {
        var result = ProposalListValidator.Validate(null, null, limit);

        Assert.Null(result.Query);
        Assert.True(result.Errors.ContainsKey("limit"));
    }

    [Fact]
    public void LimitBoundaries_1And50_AreAccepted()
    {
        Assert.Equal(1, ProposalListValidator.Validate(null, null, 1).Query!.Limit);
        Assert.Equal(50, ProposalListValidator.Validate(null, null, 50).Query!.Limit);
    }

    [Fact]
    public void SearchLength_Limit_Is100()
    {
        Assert.NotNull(ProposalListValidator.Validate(null, new string('q', 100), null).Query);

        var tooLong = ProposalListValidator.Validate(null, new string('q', 101), null);
        Assert.Null(tooLong.Query);
        Assert.True(tooLong.Errors.ContainsKey("q"));
    }

    [Fact]
    public void SearchWithControlCharacter_IsRejected()
    {
        var result = ProposalListValidator.Validate(null, "a\u0000b", null);

        Assert.Null(result.Query);
        Assert.True(result.Errors.ContainsKey("q"));
    }
}

using System.Text;
using ApplyTrack.End.Models;
using ApplyTrack.End.Validation;

namespace ApplyTrack.End.Tests.Validation;

public class ProposalValidatorTests
{
    private static ProposalRequest Req(
        string? title = "Build an app",
        int? platform = 0,
        int? status = 0,
        decimal? budget = null,
        string? followUp = null,
        string? link = null,
        string? notes = null,
        string? company = null
    ) => new(title, company, platform, status, budget, followUp, link, notes);

    private static void AssertError(ProposalRequest request, string field)
    {
        ProposalValidation result = ProposalValidator.Validate(request);

        Assert.Null(result.Input);
        Assert.True(result.Errors.ContainsKey(field), $"Expected an error for '{field}'.");
    }

    private static bool IsValid(ProposalRequest request) =>
        ProposalValidator.Validate(request).Input is not null;

    [Fact]
    public void Full_Request_IsCleaned()
    {
        var result = ProposalValidator.Validate(
            Req(
                title: "  Build app  ",
                company: " Acme ",
                platform: 1,
                status: 2,
                budget: 10.5m,
                followUp: "2026-12-01",
                link: " https://x.com/a ",
                notes: " hi "
            )
        );

        ProposalInput input = result.Input!;
        Assert.Equal("Build app", input.Title);
        Assert.Equal("Acme", input.Company);
        Assert.Equal((short)1, input.Platform);
        Assert.Equal((short)2, input.Status);
        Assert.Equal(10.5m, input.Budget);
        Assert.Equal(new DateOnly(2026, 12, 1), input.FollowUpDate);
        Assert.Equal("https://x.com/a", input.Link);
        Assert.Equal("hi", input.Notes);
    }

    [Fact]
    public void Minimal_Request_HasNullOptionals()
    {
        ProposalInput input = ProposalValidator.Validate(Req()).Input!;

        Assert.Null(input.Company);
        Assert.Null(input.Budget);
        Assert.Null(input.FollowUpDate);
        Assert.Null(input.Link);
        Assert.Null(input.Notes);
    }

    [Fact]
    public void BlankOptionals_BecomeNull()
    {
        ProposalInput input = ProposalValidator
            .Validate(Req(company: "  ", followUp: " ", link: "", notes: "   "))
            .Input!;

        Assert.Null(input.Company);
        Assert.Null(input.FollowUpDate);
        Assert.Null(input.Link);
        Assert.Null(input.Notes);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("ab")]
    [InlineData(" ab ")] // 2 characters after trim
    [InlineData("bad\u0000title")]
    public void BadTitle_IsRejected(string? title) => AssertError(Req(title: title), "title");

    [Fact]
    public void LoneSurrogate_IsRejected()
    {
        string broken = "bad" + (char)0xD800 + "title";

        AssertError(Req(title: broken), "title");
    }

    [Fact]
    public void TitleLength_Limit_Is120()
    {
        Assert.True(IsValid(Req(title: new string('t', 120))));
        AssertError(Req(title: new string('t', 121)), "title");
    }

    [Fact]
    public void CompanyLength_Limit_Is120()
    {
        Assert.True(IsValid(Req(company: new string('c', 120))));
        AssertError(Req(company: new string('c', 121)), "company");
    }

    [Theory]
    [InlineData(null)]
    [InlineData(-1)]
    [InlineData(4)]
    public void BadPlatform_IsRejected(int? platform) =>
        AssertError(Req(platform: platform), "platform");

    [Theory]
    [InlineData(null)]
    [InlineData(-1)]
    [InlineData(6)]
    public void BadStatus_IsRejected(int? status) => AssertError(Req(status: status), "status");

    [Fact]
    public void AllPlatformsAndStatuses_AreAccepted()
    {
        for (int platform = 0; platform <= 3; platform++)
            Assert.True(IsValid(Req(platform: platform)));

        for (int status = 0; status <= 5; status++)
            Assert.True(IsValid(Req(status: status)));
    }

    [Fact]
    public void Budget_Rules()
    {
        AssertError(Req(budget: -0.01m), "budget");
        AssertError(Req(budget: 12.345m), "budget"); // 3 decimals: never round silently
        AssertError(Req(budget: 10_000_000_000m), "budget");

        Assert.True(IsValid(Req(budget: 0m)));
        Assert.True(IsValid(Req(budget: 1500.5m)));
        Assert.True(IsValid(Req(budget: 9_999_999_999.99m)));
    }

    [Theory]
    [InlineData("2026-13-01")]
    [InlineData("2026-02-30")]
    [InlineData("26-11-04")]
    [InlineData("2026/11/04")]
    [InlineData("04.11.2026")]
    [InlineData("abc")]
    [InlineData("2026-11-04T10:00:00")]
    public void BadFollowUpDate_IsRejected(string date) =>
        AssertError(Req(followUp: date), "followUpDate");

    [Fact]
    public void ValidFollowUpDate_IsParsed()
    {
        ProposalInput input = ProposalValidator.Validate(Req(followUp: "2026-11-04")).Input!;

        Assert.Equal(new DateOnly(2026, 11, 4), input.FollowUpDate);
    }

    [Theory]
    [InlineData("ftp://x.com")]
    [InlineData("javascript:alert(1)")]
    [InlineData("example.com")]
    [InlineData("http://")]
    [InlineData("https://a b.com")]
    [InlineData("HTTP://x.com")] // database CHECK is case-sensitive
    public void BadLink_IsRejected(string link) => AssertError(Req(link: link), "link");

    [Fact]
    public void ValidLink_IsAccepted()
    {
        Assert.True(IsValid(Req(link: "https://www.upwork.com/jobs/~01abc?x=1")));
        Assert.True(IsValid(Req(link: "http://localhost:5000/a")));
    }

    [Fact]
    public void LinkLength_Limit_Is2048()
    {
        string prefix = "https://a.com/"; // 14 characters

        Assert.True(IsValid(Req(link: prefix + new string('x', 2048 - prefix.Length))));
        AssertError(Req(link: prefix + new string('x', 2049 - prefix.Length)), "link");
    }

    [Fact]
    public void NotesLength_Limit_Is2000()
    {
        Assert.True(IsValid(Req(notes: new string('n', 2000))));
        AssertError(Req(notes: new string('n', 2001)), "notes");
    }

    [Fact]
    public void Notes_AllowLineBreaks_ButNotOtherControlChars()
    {
        Assert.True(IsValid(Req(notes: "line1\nline2\r\n\tindented")));
        AssertError(Req(notes: "a\u0000b"), "notes");
    }

    [Fact]
    public void NullRequest_FailsTheRequiredFieldsOnly()
    {
        var result = ProposalValidator.Validate(null);

        Assert.Null(result.Input);
        Assert.Equal(
            new[] { "platform", "status", "title" },
            result.Errors.Keys.OrderBy(k => k).ToArray()
        );
    }

    [Fact]
    public void ManyBadFields_AreAllReportedAtOnce()
    {
        var result = ProposalValidator.Validate(
            Req(
                title: "ab",
                platform: 9,
                status: -1,
                budget: -5m,
                followUp: "nope",
                link: "ftp://x",
                notes: new string('n', 2001)
            )
        );

        Assert.Null(result.Input);
        Assert.Equal(
            new[] { "budget", "followUpDate", "link", "notes", "platform", "status", "title" },
            result.Errors.Keys.OrderBy(k => k).ToArray()
        );
    }
}

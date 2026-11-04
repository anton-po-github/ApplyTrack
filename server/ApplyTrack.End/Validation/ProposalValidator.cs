using System.Globalization;
using System.Text;
using ApplyTrack.End.Models;

namespace ApplyTrack.End.Validation;

public sealed record ProposalInput(
    string Title,
    string? Company,
    short Platform,
    short Status,
    decimal? Budget,
    DateOnly? FollowUpDate,
    string? Link,
    string? Notes
);

public sealed record ProposalValidation(
    ProposalInput? Input,
    IReadOnlyDictionary<string, string> Errors
);

public static class ProposalValidator
{
    public const int MinTitleLength = 3;
    public const int MaxTitleLength = 120;
    public const int MaxCompanyLength = 120;
    public const int MaxPlatformValue = 3;
    public const int MaxStatusValue = 5;
    public const int MaxLinkLength = 2048;
    public const int MaxNotesLength = 2000;
    public const decimal MaxBudget = 9_999_999_999.99m; // numeric(12,2)

    private static readonly UTF8Encoding StrictUtf8 = new(false, true);

    public static ProposalValidation Validate(ProposalRequest? request)
    {
        var errors = new Dictionary<string, string>();

        // Title
        string? title = Trimmed(request?.Title);
        if (title is null)
            errors["title"] = "Title is required.";
        else if (title.Length < MinTitleLength)
            errors["title"] = $"Title must be at least {MinTitleLength} characters.";
        else if (title.Length > MaxTitleLength)
            errors["title"] = $"Title must be at most {MaxTitleLength} characters.";
        else if (HasBadChars(title, allowLineBreaks: false))
            errors["title"] = "Title has invalid characters.";

        // Company (optional)
        string? company = Trimmed(request?.Company);
        if (company is not null)
        {
            if (company.Length > MaxCompanyLength)
                errors["company"] = $"Company must be at most {MaxCompanyLength} characters.";
            else if (HasBadChars(company, allowLineBreaks: false))
                errors["company"] = "Company has invalid characters.";
        }

        // Platform and status (required)
        int? platform = request?.Platform;
        if (platform is null)
            errors["platform"] = "Platform is required.";
        else if (platform is < 0 or > MaxPlatformValue)
            errors["platform"] = "Platform is not valid.";

        int? status = request?.Status;
        if (status is null)
            errors["status"] = "Status is required.";
        else if (status is < 0 or > MaxStatusValue)
            errors["status"] = "Status is not valid.";

        // Budget (optional)
        decimal? budget = request?.Budget;
        if (budget is not null)
        {
            if (budget < 0)
                errors["budget"] = "Budget must be 0 or more.";
            else if (budget > MaxBudget)
                errors["budget"] = "Budget is too large.";
            else if (decimal.Round(budget.Value, 2) != budget)
                errors["budget"] = "Budget can have at most 2 decimals.";
        }

        // Follow-up date (optional, exactly yyyy-MM-dd)
        DateOnly? followUp = null;
        string? rawDate = Trimmed(request?.FollowUpDate);
        if (rawDate is not null)
        {
            if (
                DateOnly.TryParseExact(
                    rawDate,
                    "yyyy-MM-dd",
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.None,
                    out DateOnly parsed
                )
            )
                followUp = parsed;
            else
                errors["followUpDate"] = "Date must look like 2026-12-31.";
        }

        // Link (optional)
        string? link = Trimmed(request?.Link);
        if (link is not null)
        {
            if (link.Length > MaxLinkLength)
                errors["link"] = $"Link must be at most {MaxLinkLength} characters.";
            else if (!IsValidLink(link))
                errors["link"] = "Link must start with http:// or https://.";
        }

        // Notes (optional)
        string? notes = Trimmed(request?.Notes);
        if (notes is not null)
        {
            if (notes.Length > MaxNotesLength)
                errors["notes"] = $"Notes must be at most {MaxNotesLength} characters.";
            else if (HasBadChars(notes, allowLineBreaks: true))
                errors["notes"] = "Notes have invalid characters.";
        }

        if (errors.Count > 0)
            return new ProposalValidation(null, errors);

        return new ProposalValidation(
            new ProposalInput(
                title!,
                company,
                (short)platform!.Value,
                (short)status!.Value,
                budget,
                followUp,
                link,
                notes
            ),
            errors
        );
    }

    private static string? Trimmed(string? value)
    {
        string text = value?.Trim() ?? string.Empty;
        return text.Length == 0 ? null : text;
    }

    // Postgres cannot store NUL, and Npgsql fails on broken UTF-16. Reject both here.
    private static bool HasBadChars(string value, bool allowLineBreaks)
    {
        foreach (char c in value)
        {
            if (char.IsControl(c) && !(allowLineBreaks && c is '\n' or '\r' or '\t'))
                return true;
        }

        try
        {
            StrictUtf8.GetByteCount(value);
            return false;
        }
        catch (EncoderFallbackException)
        {
            return true;
        }
    }

    // Lowercase scheme only: the database CHECK on Link is case-sensitive.
    private static bool IsValidLink(string link)
    {
        bool schemeOk =
            link.StartsWith("http://", StringComparison.Ordinal)
            || link.StartsWith("https://", StringComparison.Ordinal);
        if (!schemeOk)
            return false;

        foreach (char c in link)
        {
            if (char.IsWhiteSpace(c) || char.IsControl(c))
                return false;
        }

        return Uri.TryCreate(link, UriKind.Absolute, out Uri? uri)
            && !string.IsNullOrEmpty(uri.Host);
    }
}

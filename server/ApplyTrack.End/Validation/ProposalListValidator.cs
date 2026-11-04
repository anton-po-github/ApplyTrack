namespace ApplyTrack.End.Validation;

public sealed record ProposalListQuery(short? Status, string? Search, int Limit);

public sealed record ProposalListValidation(
    ProposalListQuery? Query,
    IReadOnlyDictionary<string, string> Errors
);

public static class ProposalListValidator
{
    public const int DefaultLimit = 20;
    public const int MaxLimit = 50;
    public const int MaxSearchLength = 100;

    public static ProposalListValidation Validate(int? status, string? q, int? limit)
    {
        var errors = new Dictionary<string, string>();

        if (status is < 0 or > ProposalValidator.MaxStatusValue)
            errors["status"] = "Status is not valid.";

        int effectiveLimit = limit ?? DefaultLimit;
        if (effectiveLimit is < 1 or > MaxLimit)
            errors["limit"] = $"Limit must be between 1 and {MaxLimit}.";

        string? search = q?.Trim();
        if (string.IsNullOrEmpty(search))
            search = null;

        if (search is not null)
        {
            if (search.Length > MaxSearchLength)
                errors["q"] = $"Search must be at most {MaxSearchLength} characters.";
            else if (ProposalValidator.HasBadChars(search, allowLineBreaks: false))
                errors["q"] = "Search has invalid characters.";
        }

        return errors.Count == 0
            ? new ProposalListValidation(
                new ProposalListQuery((short?)status, search, effectiveLimit),
                errors
            )
            : new ProposalListValidation(null, errors);
    }
}

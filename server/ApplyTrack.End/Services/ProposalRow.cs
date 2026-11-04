using ApplyTrack.End.Models;

namespace ApplyTrack.End.Services;

/// <summary>
/// One Proposals row as the database returns it. Used by get, list and update.
/// Property names must match the column names.
/// </summary>
internal sealed class ProposalRow
{
    public Guid Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Company { get; set; }
    public short Platform { get; set; }
    public short Status { get; set; }
    public decimal? Budget { get; set; }
    public DateOnly? FollowUpDate { get; set; }
    public string? Link { get; set; }
    public string? Notes { get; set; }
    public long CreatedAtMs { get; set; }
    public long UpdatedAtMs { get; set; }

    // No UserId and no DeletedAtMs: the client never sees them.
    public ProposalResponse ToResponse() =>
        new(
            Id,
            Title,
            Company,
            Platform,
            Status,
            Budget,
            FollowUpDate,
            Link,
            Notes,
            CreatedAtMs,
            UpdatedAtMs
        );
}

/// <summary>What the update needs from the locked row.</summary>
internal sealed class ProposalLockRow
{
    public short Status { get; set; }
    public long CreatedAtMs { get; set; }
}

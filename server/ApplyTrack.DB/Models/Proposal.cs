namespace ApplyTrack.DB.Models;

public sealed class Proposal
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public required Guid UserId { get; set; }

    public required string Title { get; set; }
    public string? Company { get; set; }
    public ProposalPlatform Platform { get; set; }
    public ProposalStatus Status { get; set; }
    public decimal? Budget { get; set; }
    public DateOnly? FollowUpDate { get; set; }
    public string? Link { get; set; }
    public string? Notes { get; set; }

    public required long CreatedAtMs { get; set; } = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
    public required long UpdatedAtMs { get; set; } = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
    public required long? DeletedAtMs { get; set; } = null;
}

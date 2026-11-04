namespace ApplyTrack.End.Models;

/// <summary>Create/update body. Everything is nullable: the client can send anything.</summary>
public sealed record ProposalRequest(
    string? Title,
    string? Company,
    int? Platform,
    int? Status,
    decimal? Budget,
    string? FollowUpDate, // "yyyy-MM-dd"
    string? Link,
    string? Notes
);

public sealed record ProposalResponse(
    Guid Id,
    string Title,
    string? Company,
    int Platform,
    int Status,
    decimal? Budget,
    DateOnly? FollowUpDate,
    string? Link,
    string? Notes,
    long CreatedAtMs,
    long UpdatedAtMs
);

public sealed record ProposalListResponse(IReadOnlyList<ProposalResponse> Items, Guid? NextCursor);

using ApplyTrack.End.Models;
using ApplyTrack.End.Validation;

namespace ApplyTrack.End.Services;

public abstract record CreateProposalResult
{
    private CreateProposalResult() { }

    public sealed record Created(ProposalResponse Proposal) : CreateProposalResult;

    public sealed record LimitReached : CreateProposalResult;

    public sealed record UserNotFound : CreateProposalResult;
}

public interface IProposalService
{
    Task<CreateProposalResult> CreateAsync(Guid userId, ProposalInput input, CancellationToken ct);
}

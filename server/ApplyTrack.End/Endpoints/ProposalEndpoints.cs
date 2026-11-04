using System.Security.Claims;
using ApplyTrack.End.Infrastructure;
using ApplyTrack.End.Models;
using ApplyTrack.End.Security;
using ApplyTrack.End.Services;
using ApplyTrack.End.Validation;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

namespace ApplyTrack.End.Endpoints;

public static class ProposalEndpoints
{
    public static void MapProposalEndpoints(this IEndpointRouteBuilder app)
    {
        RouteGroupBuilder group = app.MapGroup("/api/proposals").RequireAuthorization();

        group.MapPost(
            "/",
            async Task<
                Results<
                    Created<ProposalResponse>,
                    BadRequest<ErrorResponse>,
                    Conflict<ErrorResponse>,
                    JsonHttpResult<ErrorResponse>
                >
            > (
                [FromBody] ProposalRequest? request,
                ClaimsPrincipal user,
                IProposalService proposals,
                CancellationToken ct
            ) =>
            {
                // The owner comes ONLY from the token. The body has no userId.
                if (!user.TryGetUserId(out Guid userId))
                {
                    return ApiErrors.Unauthorized();
                }

                ProposalValidation check = ProposalValidator.Validate(request);
                if (check.Input is null)
                {
                    return TypedResults.BadRequest(
                        new ErrorResponse("validation", "Please fix the fields.", check.Errors)
                    );
                }

                CreateProposalResult result = await proposals.CreateAsync(userId, check.Input, ct);

                switch (result)
                {
                    case CreateProposalResult.Created created:
                        return TypedResults.Created(
                            $"/api/proposals/{created.Proposal.Id}",
                            created.Proposal
                        );

                    case CreateProposalResult.LimitReached:
                        return TypedResults.Conflict(
                            new ErrorResponse(
                                "proposal_limit",
                                $"You have {ProposalService.MaxLiveProposalsPerUser} proposals. Delete one to add a new one."
                            )
                        );

                    case CreateProposalResult.UserNotFound:
                        return ApiErrors.Unauthorized();

                    default:
                        throw new InvalidOperationException("Unknown create result.");
                }
            }
        );
    }
}

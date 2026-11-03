namespace ApplyTrack.DB.Models;

// Values are stored as smallint. If you add a value, update the CHECK in the DbContext.
public enum ProposalPlatform : int
{
    Upwork = 0,
    LinkedIn = 1,
    Email = 2,
    Other = 3,
}

public enum ProposalStatus : int
{
    Draft = 0,
    Sent = 1,
    Viewed = 2,
    Interview = 3,
    Won = 4,
    Lost = 5,
}

namespace ApplyTrack.DB.Models;

// One row per user. Never read-then-write.
// Update with atomic SQL: SET "Won" = "Won" + 1, "Sent" = "Sent" - 1 ...
public sealed class UserStats
{
    public Guid UserId { get; set; }

    public int Total { get; set; }
    public int Draft { get; set; }
    public int Sent { get; set; }
    public int Viewed { get; set; }
    public int Interview { get; set; }
    public int Won { get; set; }
    public int Lost { get; set; }
}

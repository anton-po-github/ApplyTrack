namespace ApplyTrack.End.Models;

public sealed record StatsResponse(
    int Total,
    int Draft,
    int Sent,
    int Viewed,
    int Interview,
    int Won,
    int Lost
);

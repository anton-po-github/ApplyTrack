namespace ApplyTrack.End.Models;

/// <summary>
/// One error shape for the whole API.
/// Code is for machines (the Dart app maps it). Message is for humans.
/// Fields is for form errors, for example { "title": "Too short." }.
/// </summary>
public sealed record ErrorResponse(
    string Code,
    string Message,
    IReadOnlyDictionary<string, string>? Fields = null
);

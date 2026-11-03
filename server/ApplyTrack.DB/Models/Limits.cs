namespace ApplyTrack.DB.Models;

public static class UserLimits
{
    public const int EmailMaxLength = 255;
    public const int DisplayNameMinLength = 1;
    public const int DisplayNameMaxLength = 80;
    public const int PasswordHashMaxLength = 128;
}

public static class ProposalLimits
{
    public const int TitleMinLength = 3;
    public const int TitleMaxLength = 120;
    public const int CompanyMaxLength = 120;
    public const int LinkMaxLength = 2048;
    public const int NotesMaxLength = 2000;
    public const int MaxLiveProposalsPerUser = 500; // server checks UserStats.Total
}

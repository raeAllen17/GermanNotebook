namespace GermanNotebook.Core.Auth;

public class AuthOptions
{
    public string OtpPepper { get; set; } = "";
    public int OtpLifetimeMinutes { get; set; } = 10;
    public int MaxAttempts { get; set; } = 5;
    public int RateLimitWindowMinutes { get; set; } = 10;
    public int MaxRequestsPerWindow { get; set; } = 3;
}

public class JwtOptions
{
    public string Issuer { get; set; } = "";
    public string Audience { get; set; } = "";
    public string Key { get; set; } = "";
    public int AccessTokenMinutes { get; set; } = 60;
}
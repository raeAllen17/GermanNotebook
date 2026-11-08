using System.Security.Cryptography;
using System.Text;
using GermanNotebook.Core.Abstractions;
using GermanNotebook.Core.Entities;

namespace GermanNotebook.Core.Auth;

public enum RequestCodeResult { Sent, InvalidEmail, RateLimited }

public record LoginResult(string AccessToken, DateTime ExpiresAt, User user);

public sealed class AuthService(
    IUserRepository users,
    IOtpChallengeRepository otps,
    IEmailSender emailSender,
    ITokenService tokens,
    AuthOptions options)
{
    public async Task<RequestCodeResult> RequestCodeAsync(string? rawEmail, CancellationToken ct)
    {
        var email = EmailNormalizer.TryNormalize(rawEmail);
        if (email is null) return RequestCodeResult.InvalidEmail;

        var since = DateTime.UtcNow.AddMinutes(-options.RateLimitWindowMinutes);
        if (await otps.CountSinceAsync(email, since, ct) >= options.MaxRequestsPerWindow)
            return RequestCodeResult.RateLimited;

        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        var expiresAt = DateTime.UtcNow.AddMinutes(options.OtpLifetimeMinutes);

        await otps.CreateAsync(email, Hash(email, code), expiresAt, ct);
        await emailSender.SentOtpAsync(email, code, ct);
        return RequestCodeResult.Sent;
    }

    public async Task<LoginResult?> VerifyCodeAsync(string? rawEmail, string? rawCode, CancellationToken ct)
    {
        var email = EmailNormalizer.TryNormalize(rawEmail);
        var code = rawCode?.Trim();
        if (email is null || code is null || code.Length != 6 || !code.All(char.IsAsciiDigit))
            return null;

        var challenge = await otps.GetLatestPendingAsync(email, ct);
        if (challenge is null
            || challenge.ExpiresAt <= DateTime.UtcNow
            || challenge.Attempts >= options.MaxAttempts)
            return null;

        var given = Encoding.UTF8.GetBytes(Hash(email, code));
        var stored = Encoding.UTF8.GetBytes(challenge.CodeHash);
        if (!CryptographicOperations.FixedTimeEquals(given, stored))
        {
            await otps.RecordFailedAttemptAsync(challenge.Id, ct);
            return null;
        }

        if (!await otps.TryConsumeAsync(challenge.Id, options.MaxAttempts, ct))
            return null;

        var user = await users.UpsertOnLoginAsync(email, ct);
        var (token, expiresAt) = tokens.CreateAccessToken(user);
        return new LoginResult(token, expiresAt, user);
    }

    private string Hash(string email, string code) =>
           Convert.ToHexString(HMACSHA256.HashData(
               Encoding.UTF8.GetBytes(options.OtpPepper),
               Encoding.UTF8.GetBytes($"{email}:{code}")));

}


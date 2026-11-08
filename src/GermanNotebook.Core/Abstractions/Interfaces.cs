using GermanNotebook.Core.Entities;

namespace GermanNotebook.Core.Abstractions;

public interface IUserRepository
{
    Task<User> UpsertOnLoginAsync(string email, CancellationToken ct);
}

public interface IOtpChallengeRepository
{
    Task CreateAsync(string email, string codeHash, DateTime expiresAt, CancellationToken ct);
    Task<OtpChallenge?> GetLatestPendingAsync(string email, CancellationToken ct);
    Task RecordFailedAttemptAsync(Guid id, CancellationToken ct);
    Task<bool> TryConsumeAsync(Guid id, int maxAttempts, CancellationToken ct);
    Task<long> CountSinceAsync(string email, DateTime since, CancellationToken ct);
}

public interface IEmailSender
{
    Task SendOtpAsync(string email, string code, CancellationToken ct);
}

public interface ITokenService
{
    (string Token, DateTime ExpiresAt) CreateAccessToken(User user);
}
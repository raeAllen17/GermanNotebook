using GermanNotebook.Core.Abstractions;
using Microsoft.Extensions.Logging;

namespace GermanNotebook.Infrastructure.Services;

public sealed class ConsoleEmailSender(ILogger<ConsoleEmailSender> logger) : IEmailSender
{
    public Task SendOtpAsync(string email, string code, CancellationToken ct)
    {
        logger.LogWarning("DEV ONLY - login code for {Email}: {Code}", email, code);
        return Task.CompletedTask;
    }
}
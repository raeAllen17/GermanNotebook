using System.Net.Mail;

namespace GermanNotebook.Core.Auth;

public static class EmailNormalizer
{
    public static string? TryNormalize(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;

        var email = raw.Trim().ToLowerInvariant();
        if (email.Length > 254) return null;
        if (!MailAddress.TryCreate(email, out var addr) || addr.Address != email) return null;

        var domain = email[(email.IndexOf('@') + 1)..];
        return domain.Contains('.') ? email : null;
    }
}


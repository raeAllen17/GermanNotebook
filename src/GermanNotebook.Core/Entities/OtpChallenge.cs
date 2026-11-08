namespace GermanNotebook.Core.Entities
{
    public class OtpChallenge
    {
        public Guid Id { get; set; }
        public string Email { get; set; } = "";
        public string CodeHash { get; set; } = "";
        public DateTime ExpiresAt { get; set; }
        public int Attempts { get; set; }
        public DateTime? ConsumedAt { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}

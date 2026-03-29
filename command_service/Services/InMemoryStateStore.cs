namespace LockMyLaptop.CommandService.Services;

public sealed class InMemoryStateStore
{
    public string? ActiveLaptopId { get; set; }
    public string? ActivePairToken { get; set; }
    public DateTimeOffset? PairExpiryUtc { get; set; }
    public string? CurrentPairingCode { get; set; }
    public DateTimeOffset? PairingCodeExpiryUtc { get; set; }
    public int FailedCodeAttempts { get; set; }
}

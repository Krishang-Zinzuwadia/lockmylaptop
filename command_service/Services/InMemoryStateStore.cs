namespace LockMyLaptop.CommandService.Services;

public sealed class InMemoryStateStore
{
    private readonly object _sync = new();

    public string? ActiveLaptopId { get; set; }
    public string? ActivePairToken { get; set; }
    public DateTimeOffset? PairExpiryUtc { get; set; }
    public string? CurrentPairingCode { get; set; }
    public DateTimeOffset? PairingCodeExpiryUtc { get; set; }
    public int FailedCodeAttempts { get; set; }
    public DateTimeOffset? PairingCooldownUntilUtc { get; set; }

    public TResult Read<TResult>(Func<InMemoryStateStore, TResult> selector)
    {
        lock (_sync)
        {
            return selector(this);
        }
    }

    public void Write(Action<InMemoryStateStore> mutator)
    {
        lock (_sync)
        {
            mutator(this);
        }
    }
}

using System.Collections.Concurrent;
using LockMyLaptop.SharedContracts;

namespace LockMyLaptop.CommandService.Services;

public sealed record CommandCacheEntry(Guid CommandId, string State, DateTimeOffset CreatedAt);

public sealed class InMemoryStateStore
{
    private readonly object _sync = new();
    private readonly ConcurrentDictionary<Guid, TaskCompletionSource<CommandResultMessage>> _pendingCommands = new();

    public string? ActiveLaptopId { get; set; }
    public string? ActiveMobileDeviceId { get; set; }
    public string? ActivePairTokenHash { get; set; }
    public DateTimeOffset? PairExpiryUtc { get; set; }
    public string? CurrentPairingCodeHash { get; set; }
    public DateTimeOffset? PairingCodeExpiryUtc { get; set; }
    public int FailedCodeAttempts { get; set; }
    public DateTimeOffset? PairingCooldownUntilUtc { get; set; }
    public string? LaptopConnectionId { get; set; }
    public DateTimeOffset? LastCommandAtUtc { get; set; }
    public Dictionary<string, CommandCacheEntry> IdempotencyCache { get; } = new(StringComparer.Ordinal);

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

    public Task<CommandResultMessage> CreatePendingCommand(Guid commandId)
    {
        var tcs = new TaskCompletionSource<CommandResultMessage>(TaskCreationOptions.RunContinuationsAsynchronously);
        _pendingCommands[commandId] = tcs;
        return tcs.Task;
    }

    public void CompletePendingCommand(CommandResultMessage result)
    {
        if (_pendingCommands.TryRemove(result.CommandId, out var tcs))
        {
            tcs.TrySetResult(result);
        }
    }

    public void CancelPendingCommand(Guid commandId)
    {
        if (_pendingCommands.TryRemove(commandId, out var tcs))
        {
            tcs.TrySetCanceled();
        }
    }

    public void CleanupIdempotencyCache(DateTimeOffset nowUtc, TimeSpan maxAge)
    {
        var toRemove = IdempotencyCache
            .Where(x => nowUtc - x.Value.CreatedAt > maxAge)
            .Select(x => x.Key)
            .ToArray();

        foreach (var key in toRemove)
        {
            IdempotencyCache.Remove(key);
        }
    }
}

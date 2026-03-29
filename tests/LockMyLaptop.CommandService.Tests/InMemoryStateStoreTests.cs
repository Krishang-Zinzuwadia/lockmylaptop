using LockMyLaptop.CommandService.Services;
using LockMyLaptop.SharedContracts;

namespace LockMyLaptop.CommandService.Tests;

public sealed class InMemoryStateStoreTests
{
    [Fact]
    public async Task PendingCommand_Completes_WhenResultArrives()
    {
        var store = new InMemoryStateStore();
        var commandId = Guid.NewGuid();
        var task = store.CreatePendingCommand(commandId);

        store.CompletePendingCommand(
            new CommandResultMessage(commandId, true, null, DateTimeOffset.UtcNow));

        var result = await task;

        Assert.True(result.Success);
        Assert.Equal(commandId, result.CommandId);
    }

    [Fact]
    public void CleanupIdempotencyCache_RemovesExpiredItems()
    {
        var store = new InMemoryStateStore();
        var now = DateTimeOffset.UtcNow;

        store.IdempotencyCache["old"] = new CommandCacheEntry(Guid.NewGuid(), "succeeded", now.AddMinutes(-10));
        store.IdempotencyCache["fresh"] = new CommandCacheEntry(Guid.NewGuid(), "succeeded", now);

        store.CleanupIdempotencyCache(now, TimeSpan.FromMinutes(5));

        Assert.False(store.IdempotencyCache.ContainsKey("old"));
        Assert.True(store.IdempotencyCache.ContainsKey("fresh"));
    }
}

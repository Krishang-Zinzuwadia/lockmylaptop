# Security and Reliability Hardening Notes

## Implemented in Phase 5
- Pairing codes stored as SHA-256 hashes in service memory.
- Pair tokens stored as SHA-256 hashes in service memory.
- Pairing lockout after repeated invalid code entries.
- Per-command rate limiting to prevent abuse spam.
- Idempotency support for power commands.
- Command timeout handling and explicit timeout state caching.

## Remaining for Production
- Replace in-memory state with durable DB and distributed cache.
- Rotate service secrets and enforce strong auth between all components.
- Add structured audit event sink with retention policy.
- Add device identity attestation for laptop agent.

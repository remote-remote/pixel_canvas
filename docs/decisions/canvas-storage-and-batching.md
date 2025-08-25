# Canvas Storage and Batching Strategy

**Date**: 2025-08-22  
**Status**: Decided  
**Context**: Need efficient storage and update mechanism for 1024x1024 pixel canvas with thousands of concurrent users

## Problem

How to efficiently store and retrieve canvas data while handling high-frequency pixel updates from many concurrent users? Initial concerns about ETS update rates led to exploring batching strategies.

## Constraints

- Target canvas: 1024x1024 pixels (single region initially)
- Future expansion: Grid of 1024x1024 regions (1024²×1024² total)
- Performance goal: Handle thousands of concurrent users
- Update frequency: 60fps broadcasts (every ~16.67ms)
- No authentication - "wild west" anonymous access

## Decision

### Storage: ETS with Batching
- Use ETS for in-memory canvas state (fast reads/writes, good concurrency)
- Implement batching GenServer to accumulate updates before ETS writes
- Batch triggers: Either 60fps timer (~17ms) OR WebSocket frame size limit

### Update Flow
1. User draws pixel → immediate echo back to user (instant feedback)
2. Update accumulated in batch buffer
3. Every ~17ms: Apply batch to ETS + broadcast to all users
4. Include `user_id` in broadcast messages for client-side filtering

### Client-Side Duplicate Filtering
Instead of server-side filtering (expensive per-user message reconstruction):
- Add `user_id` to update protocol
- Clients filter out their own updates: `if (update.user_id === my_user_id) return;`
- Server generates single broadcast message for all connections

### User Management
- Generate random user_id on WebSocket connection
- No authentication or session management
- Store user_id in connection process state

## Benefits

- **Performance**: Single message generation per batch, no per-user filtering overhead
- **Responsiveness**: Immediate user feedback + batched updates to others
- **Simplicity**: No auth complexity, clean stateless design
- **Scalability**: ETS + batching handles high concurrent load
- **Network efficiency**: One broadcast message per batch

## Trade-offs

- Users see their pixels drawn twice (imperceptible UX impact)
- Anonymous system enables griefing (acceptable for learning project)
- In-memory only (persistence can be added later)

## Future Considerations

- Multi-region expansion will need distributed ETS or per-region tables
- Load testing needed to validate 60fps performance under load
- Consider chunking strategies for larger canvas sizes
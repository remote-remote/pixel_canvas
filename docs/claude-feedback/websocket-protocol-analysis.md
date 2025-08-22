# WebSocket Protocol Implementation Analysis

## Issues Found

### 1. **Fragment Detection Size Calculations (HIGH)**
**Location**: `frame.ex:33`, `frame.ex:41`

**Problem**: Size checks are incorrect:
```elixir
# For payload_len=126, you check for 20 bytes but need 2+4=6 minimum
if byte_size(rest) < 20 do
# For payload_len=127, you check for 68 bytes but need 8+4=12 minimum  
if byte_size(rest) < 68 do
```

**Issue**: You're checking for `extended_length + mask + payload` but should only check for `extended_length + mask` at this stage.

### 2. **Missing Control Frame Handling (HIGH)**
**Location**: `handler.ex:80-106`

**Problem**: Only handles data frames with fragmentation logic. Control frames (ping, pong, close) are processed through fragmentation handlers.

**Issue**: Control frames MUST NOT be fragmented and should be handled immediately, even during message assembly.

**Required**: Add separate handling for opcodes 8 (close), 9 (ping), 10 (pong).

### 3. **Continuation Frame Logic Error (MEDIUM)**
**Location**: `handler.ex:81`, `handler.ex:92`

**Problem**: Checking `state.buffer_opcode != frame.opcode` for continuation frames:
```elixir
if !is_nil(state.buffer_opcode) && state.buffer_opcode != frame.opcode do
```

**Issue**: Continuation frames have opcode 0, not the original message opcode. You should track the original opcode separately.

### 4. **Error Recovery Missing (MEDIUM)**
**Location**: `handler.ex:22-24`

**Problem**: Listen loop crashes on any error:
```elixir
{:error, reason} ->
  Logger.error("Error receiving data: #{inspect(reason)}")
  raise "Unknown data receive error"
```

**Issue**: Network hiccups will crash the entire connection. Should attempt graceful recovery for transient errors.

### 5. **Memory Exhaustion Vulnerability (MEDIUM)**
**Location**: No limits on buffer sizes

**Problem**: Malicious clients can send headers indicating massive payload sizes, causing unbounded memory allocation.

**Issue**: No protection against memory attacks.

**Fix**: Add maximum frame size limits (typically 64KB-1MB).

### 6. **Race Condition in Recursive Parsing (LOW)**
**Location**: `handler.ex:68`, `handler.ex:72`

**Problem**: Recursive `handle_data` calls within GenServer handle_call can create deep call stacks.

**Issue**: Large numbers of small frames could cause stack overflow.

**Fix**: Use iterative parsing or tail-call optimization.

## Protocol Compliance Issues

### Missing Required Validations
- No RSV bit validation (must be 0 unless extensions negotiated)
- No opcode validation (unknown opcodes should close connection)
- No payload length validation for control frames (must be ≤ 125 bytes)
- No UTF-8 validation for text frames

### Missing Close Handshake
- No proper close frame generation/handling
- No close code/reason parsing
- Connection termination is abrupt, not graceful

## Recommendations

1. **High Priority**: Add control frame handling (ping/pong/close)
2. **Medium Priority**: Fix continuation frame opcode tracking
3. **Security**: Add frame size limits and input validation
4. **Robustness**: Improve error recovery in listen loop

## Status Update

✅ **FIXED**: Buffer management logic is now correct - no more exponential growth
✅ **FIXED**: Proper separation between TCP assembly (`frame_buffer`) and message assembly (`message_buffer`)
✅ **FIXED**: Frame buffer is properly cleared after successful parsing

The core TCP-to-frame parsing logic is now solid and handles buffering correctly. The remaining issues are primarily protocol completeness and robustness improvements.
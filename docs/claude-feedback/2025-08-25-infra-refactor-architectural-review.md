# Infrastructure Refactor - Architectural Review

**Date**: 2025-08-25  
**Reviewer**: Claude  
**Scope**: Major infrastructure refactor and architectural reorganization

## Overview

This review covers a significant architectural refactor that transitions the codebase from a monolithic HTTP server structure to a properly layered, supervised architecture with clear separation of concerns. The changes demonstrate strong architectural thinking and lay solid groundwork for the pixel canvas implementation.

## 🎯 Architectural Strengths

### 1. **Clean Separation of Concerns**
**Excellent**: The move from `lib/http/` to `lib/infra/` with proper domain boundaries:
- **Infrastructure layer** (`lib/infra/`): TCP, HTTP, WebSocket protocols  
- **Domain layer** (`lib/pixel_canvas/`): Business logic and message handling
- **Application layer** (`lib/supervisor.ex`): Process supervision

This separation follows hexagonal architecture principles and will scale well as the domain grows.

### 2. **Robust Supervision Strategy**
**Strong**: The supervision tree design shows deep OTP understanding:
```elixir
# Clean supervisor hierarchy
PixelCanvas.Supervisor
├── Infra.WebSocket.Broadcaster (singleton)  
├── DynamicSupervisor (connection manager)
└── Infra.TcpListener (connection acceptor)
```

**Highlights**:
- `:temporary` restart strategy for connections (appropriate for network clients)
- `:permanent` strategy for critical infrastructure components
- Dynamic supervision allows unlimited connection scaling
- Broadcaster isolation prevents connection failures from affecting broadcasts

### 3. **Protocol Handling Architecture**
**Sophisticated**: The connection state machine is well-designed:
```
HTTP Connection → WebSocket Upgrade → WebSocket Protocol
     ↓                    ↓                  ↓
Router Logic    →   Handshake Logic   →  Frame Handling
```

The stateful protocol transition in `TcpConnection` is elegant and handles the complexity of HTTP→WebSocket upgrades properly.

## 🔧 Implementation Quality

### 1. **TcpConnection Design**
**Strengths**:
- Proper GenServer with struct-based state management
- Clean protocol switching with pattern matching
- Task-based recv_loop prevents blocking the GenServer
- Configurable handler injection for testability

**Areas for Enhancement**:
- Error handling in recv_loop could be more graceful
- Buffer management for partial frames needs attention
- WebSocket connection state management coupling

### 2. **Broadcasting Architecture**
**Current Implementation**: Simple PID registry approach
```elixir
# Broadcaster maintains Map of PID → PID
def handle_cast({:broadcast, message}, state) do
  for {pid, _} <- state do
    send(pid, {:broadcast_message, message})
  end
end
```

**Assessment**: 
- ✅ **Simple and correct** for current scale
- ✅ **No message duplication** - single broadcast per update
- ⚠️  **Scalability concerns** at thousands of connections
- ⚠️  **No error handling** for dead processes

### 3. **Message Handler Domain Logic**
**Excellent**: Clean separation into domain-specific module:
```elixir
defmodule PixelCanvas.WebSocket.MessageHandler do
  # Binary protocol parsing with proper struct
  def handle_message(<<opcode::8, region_x::integer-10, ...>>, state)
end
```

**Strengths**:
- Binary protocol definition matches specification
- Proper struct modeling with `Point` 
- Clean return semantics (`:reply`, `:broadcast`, `:ok`)

## 📋 Architectural Decision Analysis

### Decision: ETS + Batching Strategy
**From docs/decisions/canvas-storage-and-batching.md**

**Assessment: Architecturally Sound**
- ✅ ETS choice appropriate for high-concurrency reads
- ✅ Batching strategy addresses write bottlenecks  
- ✅ Client-side filtering eliminates per-user message overhead
- ✅ 60fps target is realistic and user-experience focused

**Missing Implementation**: The batching GenServer is not yet implemented, which is critical for the performance benefits described.

## 🚨 Critical Issues & Recommendations

### 1. **Connection Error Handling** 
**Priority: High**

Current recv_loop error handling:
```elixir
{:error, :closed} -> raise "Connection closed"
{:error, reason} -> raise "Unknown data receive error" 
```

**Issues**:
- `raise` in a Task will crash the parent GenServer
- No cleanup of broadcaster registration
- No graceful connection termination

**Recommendation**:
```elixir
{:error, :closed} -> 
  GenServer.cast(handler, :connection_closed)
  :ok
{:error, reason} ->
  Logger.warn("Connection error: #{inspect(reason)}")
  GenServer.cast(handler, {:connection_error, reason})
  :ok
```

### 2. **Memory Management in Broadcaster**
**Priority: Medium**

The broadcaster accumulates PIDs but has no cleanup mechanism for dead processes.

**Recommendation**: Implement process monitoring:
```elixir
def handle_call({:register, pid}, _from, state) do
  Process.monitor(pid)
  {:reply, :ok, Map.put(state, pid, pid)}
end

def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
  {:noreply, Map.delete(state, pid)}
end
```

### 3. **Buffer Management Edge Cases**
**Priority: Medium**

HTTP and WebSocket buffer handling has potential edge cases:
- HTTP: Buffer accumulation without size limits
- WebSocket: Fragment handling incomplete

**Recommendation**: 
- Add buffer size limits with overflow protection
- Implement proper WebSocket continuation frame handling

## 🎯 Next Implementation Priorities

### Phase 1: Core Canvas Infrastructure
1. **Implement Batching GenServer** 
   - [x] ETS table creation and management
   - [x] Timer-based batch processing (60fps)
   - [x] Integration with message handler

2. **User ID System**
   - Generate random user_id on WebSocket connect
   - Store in connection state
   - Include in pixel update protocol

3. **Canvas ETS Design**
   - Table structure for 1024x1024 pixels
   - Efficient read/write patterns
   - Memory usage optimization

### Phase 2: Protocol Completion
1. **Enhanced Message Protocol**
   - Add user_id to pixel updates
   - Implement immediate echo-back
   - Batch broadcast mechanism

2. **Error Handling Hardening**
   - Connection cleanup procedures
   - Graceful degradation strategies
   - Error monitoring and logging

## 🏗️ Architectural Evolution Path

### Current State: Solid Foundation ✅
- Clean layer separation
- Proper supervision 
- Protocol handling framework
- Broadcasting mechanism

### Near Term: Canvas Implementation 
- Batching GenServer + ETS
- User management
- Pixel update protocol
- Performance optimization

### Long Term: Scale Considerations
- Multi-region canvas expansion
- Load balancing strategies  
- Persistence layer integration
- Advanced monitoring

## 📊 Learning Objectives Assessment

**Excellent Progress On**:
- ✅ Elixir process architecture and supervision
- ✅ Protocol parsing and state machines  
- ✅ GenServer patterns and message passing
- ✅ Clean code organization and separation of concerns

**Ready to Deep Dive Into**:
- 🎯 ETS concurrent data structures
- 🎯 High-frequency timer-based processing
- 🎯 Binary protocol optimization
- 🎯 Performance profiling and bottleneck analysis

## Summary

This refactor demonstrates sophisticated architectural thinking and strong OTP foundations. The separation of concerns is excellent, the supervision strategy is robust, and the protocol handling shows deep understanding of stateful network programming.

**Key Strengths**: Clean architecture, proper supervision, extensible design
**Critical Path**: Implement the batching GenServer and ETS canvas storage
**Risk Areas**: Error handling, memory management, buffer edge cases

The codebase is well-positioned for the next major milestone: implementing the real-time pixel canvas with ETS and batching. The architectural foundation will support the performance targets while maintaining clean, maintainable code.

**Overall Assessment: Strong architectural progress with solid engineering practices** 🚀

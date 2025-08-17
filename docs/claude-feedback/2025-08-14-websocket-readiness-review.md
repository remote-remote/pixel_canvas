# WebSocket Readiness Review - Server Architecture Issues

**Date**: 2025-08-14  
**Context**: Pre-WebSocket implementation review of existing HTTP server  
**Type**: Critical architectural feedback  

## Critical Issues That Need Addressing

You're absolutely right to pause here. Your current server has several fundamental problems that will bite you hard when you add WebSocket support. Here's the brutal assessment:

### 1. **Connection Tracking is Broken**
Your current "connection counting" is **counting requests, not connections**. Lines 17 and 63 in `server.ex` increment/decrement for each HTTP request-response cycle. WebSocket connections are **persistent** - they don't close after sending a response.

**What you need**: A connection registry that tracks actual socket processes, not request counts.

### 2. **No Process Supervision Strategy** 
You're spawning `Task.start_link` for each connection (line 18) with no supervision. When a WebSocket connection crashes, you have no way to clean it up or restart it.

**What you need**: A proper supervision tree with connection workers under a `DynamicSupervisor`.

### 3. **HTTP Request Parser Won't Work for WebSocket**
Your request parser uses `:packet => :http_bin` mode (line 70). This is fine for HTTP but **completely wrong** for WebSocket frames. After the handshake, you need raw binary mode to parse WebSocket frames.

**What you need**: Connection process that can switch packet modes mid-stream.

### 4. **No Connection State Management**
WebSocket connections need to maintain state (user info, subscription topics, etc.). Your current model has no place for this.

**What you need**: Stateful connection processes that can hold WebSocket-specific data.

### 5. **Broadcasting Architecture Missing**
You have no way to send messages to multiple connections. The pixel canvas needs to broadcast updates to all connected clients.

**What you need**: A pub/sub system or connection registry that supports fan-out messaging.

## Key Questions to Research

Before implementing WebSocket support, figure out:

1. **How will you structure connection processes?** (GenServer per connection? Task with receive loop?)
2. **How will you supervise connection processes?** (DynamicSupervisor? Registry?)
3. **How will you switch from HTTP parsing to WebSocket frame parsing** in the same socket?
4. **How will you track which connections should receive pixel updates?**
5. **How will you handle connection cleanup** when clients disconnect ungracefully?

## Architectural Decisions to Make

- **Connection Process Design**: Stateful GenServer vs lightweight Task
- **Process Registry**: Built-in Registry vs custom tracking
- **Message Broadcasting**: Pub/sub pattern vs direct process messaging
- **Resource Cleanup**: Monitor-based vs heartbeat-based connection tracking

## Action Items

Don't write a single line of WebSocket code until you've solved these foundational issues. The current architecture will crumble under persistent connections.

### Immediate Next Steps

1. **Research Elixir supervision patterns** for dynamic connection management
2. **Design connection process architecture** - stateful vs stateless approaches
3. **Plan socket mode switching** strategy for HTTP → WebSocket transition
4. **Design connection registry** for tracking and messaging
5. **Prototype connection cleanup** mechanisms

### Learning Focus Areas

- **DynamicSupervisor** and process lifecycle management
- **Registry** for process discovery and messaging
- **GenServer** state management patterns
- **Process monitoring** and automatic cleanup
- **Socket programming** mode switching and packet handling

## References

- [Elixir Supervision Trees](https://hexdocs.pm/elixir/Supervisor.html)
- [DynamicSupervisor](https://hexdocs.pm/elixir/DynamicSupervisor.html)
- [Registry](https://hexdocs.pm/elixir/Registry.html)
- [GenServer](https://hexdocs.pm/elixir/GenServer.html)
- [:gen_tcp socket options](https://www.erlang.org/doc/man/gen_tcp.html)

---

**Next Review**: After addressing these architectural foundations, re-evaluate readiness for WebSocket implementation.
# WebSocket Server Implementation Steps

## Overview

This document outlines the step-by-step approach for implementing a WebSocket server from scratch in Elixir, building on the existing HTTP server foundation. The goal is to handle WebSocket connections for the real-time collaborative pixel canvas.

## WebSocket Protocol Fundamentals

### Key Concepts to Understand
- **HTTP Upgrade Handshake**: WebSocket connections start as HTTP requests with specific headers
- **Frame Format**: WebSocket data is sent in frames with specific encoding/masking rules
- **Connection Lifecycle**: Open → Data Exchange → Close (with ping/pong for keepalive)
- **Binary vs Text Frames**: Different frame types for different data

### WebSocket Handshake Process
1. Client sends HTTP request with `Upgrade: websocket` header
2. Server validates required headers (`Sec-WebSocket-Key`, `Connection`, etc.)
3. Server generates response key using SHA-1 hash + magic string
4. Server responds with HTTP 101 status and upgrade headers
5. Connection switches to WebSocket protocol

## Implementation Steps

### Step 1: HTTP Request Enhancement
**Goal**: Extend existing HTTP parser to detect WebSocket upgrade requests

**Tasks**:
- [ ] Add WebSocket header detection to `HTTPRequest` module
- [ ] Validate required headers: `Connection`, `Upgrade`, `Sec-WebSocket-Version`
- [ ] Extract `Sec-WebSocket-Key` for handshake response
- [ ] Create WebSocket request struct/module

**Key Headers to Handle**:
```
Connection: Upgrade
Upgrade: websocket
Sec-WebSocket-Version: 13
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==
```

### Step 2: WebSocket Handshake Response
**Goal**: Generate proper WebSocket handshake response

**Tasks**:
- [ ] Implement `Sec-WebSocket-Accept` generation algorithm
- [ ] Create WebSocket handshake response builder
- [ ] Send HTTP 101 switching protocols response
- [ ] Handle handshake validation errors

**Response Generation**:
```
Sec-WebSocket-Accept = base64(sha1(Sec-WebSocket-Key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
```

### Step 3: WebSocket Frame Parser
**Goal**: Parse incoming WebSocket frames from binary data

**Frame Structure** (RFC 6455):
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-------+-+-------------+-------------------------------+
|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
|I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
|N|V|V|V|       |S|             |   (if payload len==126/127)   |
| |1|2|3|       |K|             |                               |
+-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
|     Extended payload length continued, if payload len == 127  |
+ - - - - - - - - - - - - - - - +-------------------------------+
|                               |Masking-key, if MASK set to 1  |
+-------------------------------+-------------------------------+
| Masking-key (continued)       |          Payload Data         |
+-------------------------------- - - - - - - - - - - - - - - - +
:                     Payload Data continued ...                :
+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
|                     Payload Data continued ...                |
+---------------------------------------------------------------+
```

**Tasks**:
- [ ] Create WebSocket frame parser module
- [ ] Parse frame header (FIN, opcode, mask, payload length)
- [ ] Handle extended payload lengths (16-bit and 64-bit)
- [ ] Implement payload unmasking for client frames
- [ ] Handle frame fragmentation

**Frame Types to Support**:
- `0x1`: Text frame
- `0x2`: Binary frame  
- `0x8`: Connection close
- `0x9`: Ping frame
- `0xA`: Pong frame

### Step 4: WebSocket Frame Builder
**Goal**: Create outgoing WebSocket frames for server responses

**Tasks**:
- [ ] Build text frames for JSON messages
- [ ] Build binary frames for efficient pixel data
- [ ] Build ping/pong frames for keepalive
- [ ] Build close frames for connection termination
- [ ] Handle frame fragmentation for large messages

**Note**: Server frames are NOT masked (only client→server frames are masked)

### Step 5: Connection State Management
**Goal**: Track WebSocket connections and their state

**Tasks**:
- [ ] Create WebSocket connection process/GenServer
- [ ] Maintain connection registry
- [ ] Handle connection lifecycle (open → active → closing → closed)
- [ ] Implement connection cleanup on process death
- [ ] Add connection monitoring and health checks

### Step 6: Message Protocol Design
**Goal**: Define application-level message format for pixel canvas

**Message Types**:
```elixir
# Client → Server
%{type: "pixel_update", x: 100, y: 150, color: "#FF0000"}
%{type: "cursor_move", x: 200, y: 300}

# Server → Client  
%{type: "pixel_changed", x: 100, y: 150, color: "#FF0000", user_id: "abc123"}
%{type: "canvas_state", pixels: [...]}
%{type: "user_joined", user_id: "def456"}
```

**Tasks**:
- [ ] Define message schemas
- [ ] Implement JSON encoding/decoding
- [ ] Add message validation
- [ ] Handle malformed messages gracefully

### Step 7: Integration with HTTP Server
**Goal**: Seamlessly upgrade HTTP connections to WebSocket

**Tasks**:
- [ ] Modify HTTP router to detect WebSocket upgrade requests
- [ ] Hand off upgraded connections to WebSocket handler
- [ ] Ensure clean process transitions
- [ ] Maintain existing HTTP functionality

## Testing Strategy

### Unit Tests
- WebSocket handshake key generation
- Frame parsing and building
- Message validation and encoding

### Integration Tests  
- Full handshake flow
- Frame exchange scenarios
- Connection lifecycle management
- Error handling and edge cases

### Property Tests (Optional)
- Frame parsing with random binary data
- Message protocol with various inputs

## Key Learning Areas

### WebSocket Protocol Details
- RFC 6455 specification nuances
- Frame masking/unmasking algorithms
- Connection state machine
- Error handling and close codes

### Elixir Process Architecture
- Connection process design patterns
- Supervision strategies for connections
- Process registry and monitoring
- Clean resource cleanup

### Binary Protocol Handling
- Efficient binary parsing in Elixir
- Memory-conscious frame processing
- Streaming vs buffered approaches

## Performance Considerations

- **Memory Usage**: Avoid copying large binaries unnecessarily
- **Process Spawning**: One process per connection vs shared workers
- **Frame Buffering**: Handle partial frames and streaming data
- **Message Batching**: Group small messages for efficiency

## Error Scenarios to Handle

- Malformed HTTP upgrade requests
- Invalid WebSocket frames
- Client disconnections (graceful and abrupt)
- Protocol violations and security issues
- Resource exhaustion (too many connections)

## Next Steps After Implementation

1. **Basic Pixel Canvas Integration**: Connect WebSocket to pixel storage
2. **Broadcasting Engine**: Fan-out updates to all connections
3. **Rate Limiting**: Prevent abuse and flooding
4. **Performance Testing**: Measure throughput and latency
5. **Client Implementation**: HTML5 Canvas WebSocket client

## References

- [RFC 6455 - The WebSocket Protocol](https://tools.ietf.org/html/rfc6455)
- [WebSocket Frame Format](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers#format)
- [Elixir Binary Pattern Matching](https://elixir-lang.org/getting-started/binaries-strings-and-char-lists.html)
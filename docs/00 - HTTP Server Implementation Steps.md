## Overview

Building a robust HTTP server from scratch using pure Elixir and OTP, without external libraries like Plug or Phoenix. This approach will give us deep understanding of HTTP protocol handling and TCP socket programming.

## Implementation Steps

### Phase 1: Basic TCP Server Foundation

1. **Create the GenServer structure**
   - `PixelCanvas.Http.Server` as a GenServer
   - Accept port configuration in `start_link/1`
   - Initialize with `:gen_tcp.listen/3`

2. **Implement connection acceptance**
   - Use `:gen_tcp.accept/1` in a loop
   - Spawn processes for each connection
   - Handle connection lifecycle

3. **Basic socket operations**
   - Receive raw TCP data with `:gen_tcp.recv/3`
   - Send responses with `:gen_tcp.send/2`
   - Proper socket closing and error handling

### Phase 2: HTTP Protocol Parsing

4. **HTTP request parsing**
   - Parse request line (method, path, version)
   - Extract headers (line-by-line parsing)
   - Handle request body based on Content-Length
   - Support for common HTTP methods (GET, POST, PUT, DELETE)

5. **HTTP response generation**
   - Status line formatting
   - Header management
   - Body handling with proper Content-Length
   - Connection management (keep-alive vs close)

### Phase 3: Request Routing & Handling

6. **Basic routing system**
   - Pattern matching on paths
   - Method-based dispatch
   - Route parameter extraction
   - Fallback to 404 handling

7. **Response types**
   - Plain text responses
   - JSON responses
   - Error responses (400, 404, 500)
   - Proper Content-Type headers

### Phase 4: Robustness & Performance

8. **Error handling**
   - Malformed request handling
   - Socket errors and timeouts
   - Process crash isolation
   - Graceful degradation

9. **Connection management**
   - Connection pooling/limiting
   - Timeout handling
   - Resource cleanup
   - Monitoring active connections

10. **Testing & Validation**
    - Unit tests for parsing functions
    - Integration tests with real TCP connections
    - Load testing with concurrent requests
    - Edge case validation

## Key Technical Decisions

### Socket Configuration

- Use `[:binary, packet: :raw, active: false]` for explicit control
- Handle backlog size for connection queuing
- Configure socket options for performance

### Process Architecture

- One supervisor for the listener process
- Dynamic supervisor for connection processes
- Connection processes should be temporary and isolated

### HTTP Compliance

- Implement minimal HTTP/1.1 compliance
- Support essential headers
- Handle Connection: close/keep-alive
- Proper status code usage

## Testing Strategy

### Unit Tests

- HTTP parsing functions
- Response generation
- Error conditions
- State management

### Integration Tests

- Real TCP socket connections
- Concurrent request handling
- Server lifecycle (start/stop)
- Resource cleanup verification

### Manual Testing

- Use `curl` for various request types
- Test with browser requests
- Load testing with simple scripts
- Monitor with `:observer.start()`

## Learning Objectives

- **TCP Socket Programming**: Raw socket handling in Elixir
- **HTTP Protocol**: Deep understanding of request/response cycle
- **OTP Design**: GenServer patterns for network services
- **Process Management**: Supervisor trees for fault tolerance
- **Binary Pattern Matching**: Efficient parsing of network protocols
- **Resource Management**: Connection limits and cleanup

## Potential Challenges

1. **HTTP Parsing Complexity**: Handling edge cases in malformed requests
2. **Memory Management**: Preventing memory leaks with long-running connections
3. **Concurrency**: Race conditions in connection handling
4. **Performance**: Balancing robustness with speed
5. **Standards Compliance**: HTTP specification nuances

## Success Criteria

- [x] Server starts and accepts connections on specified port
- [x] Handles basic GET/POST requests correctly
- [x] Returns appropriate status codes and headers
- [x] Gracefully handles malformed requests
- [x] Supports concurrent connections
- [x] Can be started/stopped cleanly
- [x] All tests pass consistently
- [x] No resource leaks during normal operation

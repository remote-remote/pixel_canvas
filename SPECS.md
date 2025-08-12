## Real-Time Collaborative Pixel Canvas

## Project Goal

Build a high-concurrency collaborative pixel art canvas from scratch using raw Elixir (no Phoenix/LiveView). Support 1000+ simultaneous users painting on a shared canvas with 60fps broadcast rates.

## Core Architecture Components

### 1. TCP WebSocket Server

- Accept raw TCP connections on a port
- Handle HTTP upgrade handshake manually
- Parse WebSocket frames (masking, fragmentation, ping/pong)
- Maintain connection registry

### 2. Pixel Canvas Core

- Store 1M+ pixels efficiently (likely ETS table)
- Handle coordinate validation and bounds checking
- Detect and batch pixel changes
- Maintain canvas state consistency

### 3. Connection Management

- Track active client connections
- Handle connection cleanup on disconnect
- Manage per-client state (cursor position, user info)
- Monitor connection health

### 4. Broadcast Engine

- Fan-out pixel updates to all connected clients
- Batch updates for efficiency (target 60fps)
- Handle slow/disconnected clients gracefully
- Implement backpressure mechanisms

### 5. Rate Limiting & Abuse Prevention

- Per-IP rate limiting with token buckets
- Prevent canvas flooding/griefing
- Handle malformed messages gracefully

## High-Level Implementation Phases

### Phase 1: Basic TCP Foundation

- [ ] Simple TCP echo server
- [ ] Accept loop with connection spawning
- [ ] Basic message passing between processes
- [ ] Connection cleanup on disconnect

### Phase 2: WebSocket Protocol Implementation

- [ ] HTTP request parsing
- [ ] WebSocket handshake generation
- [ ] WebSocket frame encoding/decoding
- [ ] Handle ping/pong frames for keepalive

### Phase 3: Pixel Canvas Logic

- [ ] ETS table for pixel storage
- [ ] Coordinate validation (bounds checking)
- [ ] Pixel update operations
- [ ] Basic get/set pixel functionality

### Phase 4: Real-Time Broadcasting

- [ ] Connection registry management
- [ ] Broadcast pixel changes to all clients
- [ ] Batch updates for efficiency
- [ ] Handle client backpressure

### Phase 5: Performance & Scaling

- [ ] Rate limiting implementation
- [ ] Performance benchmarking
- [ ] Memory usage optimization
- [ ] Load testing with 1000+ connections

### Phase 6: Client Interface

- [ ] Basic HTML5 Canvas client
- [ ] WebSocket client connection handling
- [ ] Mouse/touch input capture
- [ ] Render received pixel updates

## Technical Constraints

- **No Phoenix/LiveView** - Raw Elixir and :gen_tcp only
- **60fps target** - Sub-16ms broadcast latency
- **1000+ concurrent users** - Efficient connection handling
- **Memory efficient** - Smart pixel storage strategies

## Success Metrics

- [ ] Handle 1000+ simultaneous TCP connections
- [ ] Maintain 60fps broadcast rate under load
- [ ] Graceful degradation under stress
- [ ] Memory usage stays reasonable (< 1GB for full canvas)
- [ ] Clean connection handling (no memory leaks)

## Learning Objectives

- Deep understanding of Elixir process architecture
- Real-time systems and low-latency programming
- WebSocket protocol implementation
- High-concurrency connection management
- Binary protocol design and optimization
- ETS performance characteristics
- Backpressure and flow control mechanisms

## Future Extensions (Musical Canvas)

After completing the pixel canvas, extend the concept to a collaborative musical canvas where:

- Each grid cell contains musical patterns instead of pixels
- Client-side audio synthesis (Web Audio API)
- Spatial audio based on viewport position
- Global tempo with user-selectable subdivisions
- Real-time collaborative music creation PixelCanvas

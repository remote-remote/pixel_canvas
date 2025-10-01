# Pixel Canvas

This is a learning project that I'm working on to understand Elixir and OTP on a deeper level.

## Goals

- [x] understand the basics of OTP
    - [x] Supervisision Trees
    - [x] GenServers
    - [x] Tasks
- [x] handle TCP packets directly
    - [x] assemble HTTP requests
    - [x] handle HTTP upgrade handshake
    - [x] parse WebSocket frames, including masking and fragmentation
- [ ] handle 1000+ simultaneous websocket connections (100k pixel updates per second)
    - this works pretty consistently on the first 1000, but we need to reuse handler processes 
    - [ ] pool connections and reuse processes to avoid spawn storms
- [x] maintain 60fps broadcast rate under 100k messages/second load
- [ ] expose telemetry metrics to all clients via websocket

## Architecture

- Supervisor - the PixelCanvas application starts the PixelCanvas.Supervisor, which manages all of the top-level processes.

- WebSocket.Broadcaster - a GenServer that keeps a registry of WebsocketConnections, and can broadcast messages to them.
- Telemetry - a GenServer that writes and aggregates telemetry metrics to an ets table.
- TelemetryMonitor - a GenServer that collects certain telemetry metrics on a cadence. This is used for the connection count.
- ConnectionSupervisor - a DynamicSupervisor that manages TcpConnections.
- TcpListener - a simple module with an accept loop that spawns new TcpConnections under the ConnectionSupervisor.
- PixelBatcher - a GenServer that batches pixel messages and broadcasts them to all connected clients at 60fps.
- PixelStore - a GenServer that stores pixel messages in an ETS table.

## The Canvas

I've left room in the message protocol and pixel storage to allow expanding the canvas to a grid of 1024x1024 regions, each with a resolution of 1024x1024. This is massive, and I'll likely run in to some memory issues with the current storage strategy. We'll handle that when we get there. For now, we're only using the region at 0,0, effectively making our canvas a 1024x1024 square.

## Messages
The original implementation was to use a single message type for all pixels, but I'm starting to rethink this.

### Original
Every pixel is a single message. The opcode was meant to leave room for further expansion, but I can't think of any use cases beyond draw or erase, so it could 
be replaced with a single bit.
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1  
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     opcode    |     region x      |    region y       | loc x |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| loc x cont|       loc y       |             color             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### Proposed Batch Messages
We will want to have better compression and observability. We need a client to be able to identify its own messages to compute round trip time.
One way to do this is to encode the user id in each pixel. We can then use that to identify the messages that belong to the client.

This would require a few changes:
- when a connection is established, the server sends a message with the user id and all of the pixels in the region.
- we can compress the messages by prepending with some header data:
    - region x - 10 bits
    - region y 10 bits
    - number of user pixel blocks - 20 bits
    - total of 5 bytes (40 bits)
- then each pixel block is
    - user id (20 bits)
    - number of pixels in block (20 bits, up to a whole 1024 x 1024 region)
    - pixels
        - opcode - 4 bits
        - x - 10 bits
        - y - 10 bits
        - color - 16 bits
        - total 5 bytes
    - total of 10 bytes (80 bits)
For a single pixel, we end up with a larger message size than the original message, but we're optimizing for the batch case so I think it's fine.

#### Message Header (3 bytes)
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     region x          |    region y           |  --------------
```
#### Block Header (5 bytes)
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                user id                |   number of pixels... |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| num of pixels |  ...pixels
```
#### Pixel (5 bytes each)
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| opcode|    local x        |    local y        |     color...  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     color     |
```

#### Comparison
These are apples to oranges, because the old implementation didn't have user ids. But just for the sake of comparison:

##### 1 user, 1000 pixels
**Old** - 8kb
**New** - 5kb

##### 1000 users, 1 pixel each
**Old** - 8kb
**New** - ~10kb (1000 10-byte blocks + 5 byte header)

##### 1000 users, 10 pixels each 
This is very fast drawing! We're unlikely to have to send this many pixels in a single message.

**Old** - 8mb
**New** - ~5.5kb (1000 55-byte blocks + 5 byte header)

### Proposed Client -> Server Messages
These can be much less efficient. 

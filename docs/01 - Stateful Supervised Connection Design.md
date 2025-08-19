# Redesign Web Server for future WebSocket

## Supervision Strategy

- `PixelCanvas.Supervisor (Supervisor)`
  - `PixelCanvas.ConnectionSupervisor (DynamicSupervisor)` - supervises connections
    - `PixelCanvas.ConnectionHandler (GenServer)` - tracks connection state, temporary
  - `PixelCanvas.Server (GenServer)` - tracks server state, singleton. Is a connection registry, sort of.

### Supervisor

This is the top level supervisor that starts the other supervisors.

### WebSocket Connection Supervisor

This is a DynamicSupervisor that starts WebSocketConnections for each new connection.

### WebSocketConnection

This is a GenServer that tracks the state of a single WebSocket connection.

#### State

- `:state` - the current state of the connection
- `:socket` - the socket for the connection
- `:ref` - the reference for the connection
- `:buffer` - the buffer for the connection
- `:ping_timer` - the timer for the ping

#### API

##### `start_link/1`

Starts a new WebSocketConnection.

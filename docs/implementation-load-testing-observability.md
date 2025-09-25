# Load Testing Observability Implementation

## Objective
Measure and optimize 1K connections × 100px/sec performance with comprehensive telemetry.

## Protocol Changes

### Client ID Addition
- **Format**: Prepend 4-byte client ID to each pixel message
- **Structure**: `[client_id: 4 bytes][x: 2 bytes][y: 2 bytes][color: 3 bytes]`
- **Purpose**: Enable client-side round-trip latency measurement

## Telemetry Implementation Checklist

### Core Infrastructure
- [ ] Create `PixelCanvas.Telemetry` module
- [ ] Define telemetry events and metrics
- [ ] Set up logging/monitoring output

### Connection Pipeline Instrumentation
- [ ] **TCP Accept Loop**:
  - Time between accepts
  - Failed vs successful handshakes
  - Process spawn rate
- [ ] **WebSocket Handshake**:
  - Handshake parsing time
  - Connection establishment success rate
  - Concurrent connection count

### Message Flow Instrumentation
- [ ] **Broadcaster Performance**:
  - Messages per second throughput
  - Time to broadcast to all connections
  - Connection list iteration time
- [ ] **Batcher Performance**:
  - Batch assembly time
  - Batch size distribution
  - Queue depth

### Client-Side Measurement
- [ ] **Round-Trip Latency**:
  - Client adds timestamp when sending pixel
  - Measures time when receiving own pixel back
  - Tracks latency distribution per client

### Load Testing Improvements
- [ ] **Connection Ramp-Up**:
  - Gradual connection establishment (100/sec)
  - Staged testing: 100 → 500 → 1K connections
  - Connection failure analysis

### Monitoring Dashboard
- [ ] **Real-time Metrics**:
  - Active connection count
  - Message throughput
  - Latency percentiles
  - Error rates

## Key Metrics to Track

### Performance
- Messages/second (total and per-client)
- Round-trip latency (p50, p95, p99)
- Broadcaster iteration time
- Memory usage under load

### Reliability
- Connection establishment success rate
- WebSocket handshake failures
- Process crash rate
- Message delivery success rate

### Scalability
- Connection limit testing
- Memory growth patterns
- CPU utilization
- Network throughput

## Implementation Priority
1. Telemetry module foundation
2. Protocol update with client ID
3. Connection pipeline instrumentation
4. Load test improvements
5. Client-side measurement
6. Dashboard/logging
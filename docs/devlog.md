# Devlog

## 2025-08-18

- [x] Improve connection tracking. We need to be able to keep connections alive. Need to track the actual processes in a ConnectionRegistry or something.
- [x] Stop simply using Task.start_link when handling connections. We will need a `DynamicSupervisor`
- [ ] improve HTTP Request Parser to handle websockets
  - will need to be able to switch packet modes mid-stream
- [x] The connection manager will need to also maintain state for the user
- [ ] Implement some broadcasting architecture - explore pub/sub implementations

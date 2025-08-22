# Devlog

## 2025-08-18

- [x] Improve connection tracking. We need to be able to keep connections alive. Need to track the actual processes in a ConnectionRegistry or something.
- [x] Stop simply using Task.start_link when handling connections. We will need a `DynamicSupervisor`
- [x] The connection manager will need to also maintain state for the user

## 2025-08-19

- [x] improve HTTP Request Parser to handle websockets
  - will need to be able to switch packet modes mid-stream

## 2025-08-21


## TODO
- [ ] Implement some broadcasting architecture - explore pub/sub implementations

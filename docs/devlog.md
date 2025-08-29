# Devlog

## 2025-08-18

- [x] Improve connection tracking. We need to be able to keep connections alive. Need to track the actual processes in a ConnectionRegistry or something.
- [x] Stop simply using Task.start_link when handling connections. We will need a `DynamicSupervisor`
- [x] The connection manager will need to also maintain state for the user

## 2025-08-19

- [x] improve HTTP Request Parser to handle websockets
  - will need to be able to switch packet modes mid-stream

## 2025-08-21 - 2025-08-26
- [x] some broadcasting architecture - explore pub/sub implementations
- [x] websocket connection manager
- [x] pixel store implementation
- [x] pixel batcher sends to broadcaster
- [x] load test infrastructure, still wip

## TODO
- [ ] persist pixel store on restart
- [ ] load test improvements
    - [ ] increase number of connections over time to find max
    - [ ] increase send rate over time to find max
    - [ ] have some sequence of increasing load until failure, then provide a report
- [ ] add user management
    - [ ] no auth, just a user name and id
    - [ ] every pixel update should be signed with a user id
- [ ] change pixel store layout to 256x256 x 256x256. This gets us 4 bits back, but still not enough to store a user id
    - [ ] the user id will need to be large enough to be random uuid, so we should probably update the protocol to include a user id, the number of pixels, and the coordinates. Or even better, we could batch by user id and color, so we might have <<opcode::8, userid::128, len::8, region::16, loc::16, color::8>> = 184 bits

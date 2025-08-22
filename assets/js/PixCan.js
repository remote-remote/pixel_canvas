export class PixCan {
  constructor() {
  }

  start() {
    const canvas = document.getElementById("pixcan")
    this.ws = new WebSocket("/ws")

    this.ws.addEventListener("open", () => {
      this.ws.send("HELLO")
    })

    this.ws.addEventListener("message", (e) => {
      console.log(e)
    })

    this.context = canvas.getContext('2d')
  }
}

/*
  * 
  * 1. send the server the canvas dimensions
  * 2. wait for response with an initial canvas state
  *
  * messages
  *
  * opcode(1byte) - row(2bytes) - col(2bytes)
  *
  * CHUNKS
  * 8 * 8 = 64 * 2bytes per pixel (rgba, each 0-15) = 128 bytes per 8x8 chunk
  *
  * SINGLE PIXEL
  * position of 1 pixel - need the chunk coordinate ([0-1027, 0-1027])
  * and the pixel coordinate ([0-1024]) - 40bits for 1 position = 5 bytes + 2bytes for color
  *
  * [opcode (8)][chunk-x (10)][chunk-y (10)][ px-x (10)][pxy (10)][color (16)] = 64 bits = 8 bytes
  *
  *
  * TOTAL SIZE OF BOARD =  chunks * 
  * 1024 x 1024 chunks of 1024x 1024 px = 1048576 x 1048576
  *
  *
  * */

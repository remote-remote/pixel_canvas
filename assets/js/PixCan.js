export class PixCan {
  constructor() {
    this.isDrawing = false
    this.point = { x: null, y: null }
  }

  start() {
    const canvas = document.getElementById("pixcan")
    this.context = canvas.getContext('2d')

    canvas.addEventListener("mousedown", (event) => {
      this.isDrawing = true
      this.point = {
        x: event.offsetX,
        y: event.offsetY
      }
      this.sendPoint()
    })

    canvas.addEventListener("mousemove", (event) => {
      if (this.isDrawing) {
        this.point = {
          x: event.offsetX,
          y: event.offsetY
        }
        this.sendPoint()
      }
    })

    canvas.addEventListener("mouseup", (event) => {
      this.isDrawing = false
    })

    this.ws = new WebSocket("/ws")

    this.ws.addEventListener("open", () => {
      this.ws.send("I'm alive!")
    })

    this.ws.addEventListener("message", async (e) => {
      const message = await PixCan.parseMessage(e.data)
      const { r, g, b, a } = message.color


      this.context.fillStyle = `rgba(${r}, ${g}, ${b}, ${a / 255})`
      this.context.fillRect(message.locationX, message.locationY, 1, 1)

      console.log(message)
    })

  }

  sendPoint() {
    const opcode = 1
    const regionX = 0
    const regionY = 0
    const locationX = this.point.x
    const locationY = this.point.y
    const color = 0x000F

    const buffer = new ArrayBuffer(8)
    const view = new DataView(buffer)

    // Pack into 64 bits: opcode(8) + regionX(10) + regionY(10) + locationX(10) + locationY(10) + color(16)
    const high32 = (opcode << 24) | (regionX << 14) | (regionY << 4) | (locationX >> 6)
    const low32 = ((locationX & 0x3F) << 26) | (locationY << 16) | color

    view.setUint32(0, high32, false) // big-endian
    view.setUint32(4, low32, false)

    this.ws.send(buffer)
  }

  static async parseMessage(blob) {
    const buffer = await blob.arrayBuffer()
    const view = new DataView(buffer)
    const high32 = view.getUint32(0, false)
    const low32 = view.getUint32(4, false)

    const opcode = (high32 >>> 24) & 0xFF
    const regionX = (high32 >>> 14) & 0x3FF
    const regionY = (high32 >>> 4) & 0x3FF
    const locationX = ((high32 & 0xF) << 6) | ((low32 >>> 26) & 0x3F)
    const locationY = (low32 >>> 16) & 0x3FF
    const color = low32 & 0xFFFF

    // Convert 16-bit color to RGBA (assuming 4-bit per channel RGBA)
    const r = ((color >>> 12) & 0xF) * 17  // Scale 0-15 to 0-255
    const g = ((color >>> 8) & 0xF) * 17
    const b = ((color >>> 4) & 0xF) * 17
    const a = (color & 0xF) * 17

    return {
      opcode,
      regionX,
      regionY,
      locationX,
      locationY,
      color: {
        r,
        g,
        b,
        a
      }
    }
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
  * and the pixel coordinate ([0-1023]) - 40bits for 1 position = 5 bytes + 2bytes for color
  *
  * [opcode (8)][chunk-x (10)][chunk-y (10)][ px-x (10)][pxy (10)][color (16)] = 64 bits = 8 bytes
  *
  *
  * TOTAL SIZE OF BOARD =  chunks * 
  * 1024 x 1024 chunks of 1024x 1024 px = 1048576 x 1048576
  *
  *
  * */

const KEY_ACCELERATION = 0.1
const MAX_VELOCITY = 2

export class PixCan {
  constructor() {
    this.isDrawing = false
    this.pen = { x: null, y: null }
  }

  loop() {
    for (const key in this.keys) {
      if (this.keys[key].pressed) {
        this.keys[key].action()
      }
    }
    this.viewport.x += this.viewport.vx
    this.viewport.y += this.viewport.vy
    if (this.viewport.vx > MAX_VELOCITY) {
      this.viewport.vx = MAX_VELOCITY
    }
    if (this.viewport.vy > MAX_VELOCITY) {
      this.viewport.vy = MAX_VELOCITY
    }
    this.context.clearRect(0, 0, this.viewport.width * this.viewport.scale, this.viewport.height * this.viewport.scale)
    const sliced = this.grid.slice(this.viewport.y, this.viewport.y + this.viewport.height).map((row) => {
      return row.slice(this.viewport.x, this.viewport.x + this.viewport.width)
    })
    sliced.forEach((row, y) => row.forEach((color, x) => this.drawPixel(x, y, color)))
    window.requestAnimationFrame(() => this.loop())
  }

  start() {
    const canvas = document.getElementById("pixcan")
    const colorSelect = document.getElementById("color-select")

    this.context = canvas.getContext('2d')
    this.color = "000"
    this.viewport = {
      vx: 0,
      vy: 0,
      x: 0,
      y: 0,
      width: 256,
      height: 256,
      scale: 4
    }
    this.grid = Array.from({ length: 1024 }, () => Array.from({ length: 1024 }, () => ({ r: 0, g: 0, b: 0, a: 0 })))

    canvas.addEventListener("mousedown", (event) => {
      this.isDrawing = true
      this.pen = {
        x: event.offsetX / this.viewport.scale + this.viewport.x,
        y: event.offsetY / this.viewport.scale + this.viewport.y
      }
      this.sendPoint()
    })

    canvas.addEventListener("mousemove", (event) => {
      if (this.isDrawing) {
        this.pen = {
          x: event.offsetX / this.viewport.scale + this.viewport.x,
          y: event.offsetY / this.viewport.scale + this.viewport.y
        }
        this.sendPoint()
      }
    })

    canvas.addEventListener("mouseup", (event) => {
      this.isDrawing = false
    })

    colorSelect.addEventListener("change", (event) => {
      this.color = event.target.value
    })

    this.keys = {
      ArrowLeft: {
        pressed: false,
        action: () => this.viewport.vx += KEY_ACCELERATION
      },
      ArrowRight: {
        pressed: false,
        action: () => this.viewport.vx -= KEY_ACCELERATION
      },
      ArrowUp: {
        pressed: false,
        action: () => this.viewport.vy -= KEY_ACCELERATION
      },
      ArrowDown: {
        pressed: false,
        action: () => this.viewport.vy += KEY_ACCELERATION
      },
    }

    document.onkeydown = (event) => {
      if (this.keys[event.key] == null) {
        return
      }
      this.keys[event.key].pressed = true
    }

    document.onkeyup = event => {
      if (this.keys[event.key] == null) {
        return
      }
      this.keys[event.key].pressed = false
    }

    this.ws = new WebSocket("/ws")

    this.ws.addEventListener("close", () => {
      console.log("WebSocket connection closed")
    })

    this.ws.addEventListener("error", () => {
      console.log("WebSocket connection error")
    })

    this.ws.addEventListener("open", () => {
      console.log("WebSocket connection established")
    })

    this.ws.addEventListener("message", async (e) => {
      const messages = await PixCan.parseMessages(e.data)

      messages.forEach(message => {
        this.grid[message.localY][message.localX] = message.color
        // this.drawPixel(message.localX, message.localY, message.color)
      })
    })
    this.loop()
  }

  drawPixel(x, y, { r, g, b, a }) {
    this.context.fillStyle = `rgba(${r}, ${g}, ${b}, ${a / 255})`
    this.context.fillRect(x * this.viewport.scale, y * this.viewport.scale, this.viewport.scale, this.viewport.scale)
  }

  sendPoint() {
    const opcode = 1
    const regionX = 0
    const regionY = 0
    const localX = this.pen.x
    const localY = this.pen.y
    const color = parseInt(this.color + "f", 16)

    const buffer = new ArrayBuffer(8)
    const view = new DataView(buffer)

    // Pack into 64 bits: opcode(8) + regionX(10) + regionY(10) + localX(10) + localY(10) + color(16)
    const high32 = (opcode << 24) | (regionX << 14) | (regionY << 4) | (localX >> 6)
    const low32 = ((localX & 0x3F) << 26) | (localY << 16) | color

    view.setUint32(0, high32, false) // big-endian
    view.setUint32(4, low32, false)

    this.ws.send(buffer)
  }

  static async parseMessages(blob) {
    const messages = []
    const buffer = await blob.arrayBuffer()
    const view = new DataView(buffer)

    for (let i = 0; i < buffer.byteLength; i += 8) {
      const high32 = view.getUint32(i, false)
      const low32 = view.getUint32(i + 4, false)

      const opcode = (high32 >>> 24) & 0xFF
      const regionX = (high32 >>> 14) & 0x3FF
      const regionY = (high32 >>> 4) & 0x3FF
      const localX = ((high32 & 0xF) << 6) | ((low32 >>> 26) & 0x3F)
      const localY = (low32 >>> 16) & 0x3FF
      const color = low32 & 0xFFFF

      // Convert 16-bit color to RGBA (assuming 4-bit per channel RGBA)
      const r = ((color >>> 12) & 0xF) * 17  // Scale 0-15 to 0-255
      const g = ((color >>> 8) & 0xF) * 17
      const b = ((color >>> 4) & 0xF) * 17
      const a = (color & 0xF) * 17

      messages.push({
        opcode,
        regionX,
        regionY,
        localX,
        localY,
        color: {
          r,
          g,
          b,
          a
        }
      })
    }
    return messages
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

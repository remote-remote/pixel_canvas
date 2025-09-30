const KEY_ACCELERATION = 0.1
const MAX_VELOCITY = 2

function computePos(pos, velocity) {
  const newPos = pos + velocity
  if (newPos > 1023) {
    return 1023
  }
  if (newPos < 0) {
    return 0
  }
  return newPos
}

export class PixCan {
  constructor() {
    this.isDrawing = false
    this.pen = { x: null, y: null }
  }

  loop() {
    for (const key in this.keys) {
      if (this.keys[key].down) {
        this.keys[key].whileDown()
      }
    }
    this.viewport.x = computePos(this.viewport.x, this.viewport.vx)
    this.viewport.y = computePos(this.viewport.y, this.viewport.vy)

    this.context.clearRect(0, 0, this.viewport.width * this.viewport.scale, this.viewport.height * this.viewport.scale)
    this.offCanvas.getContext('2d').putImageData(this.img, 0, 0)
    this.context.drawImage(this.offCanvas, this.viewport.x, this.viewport.y, this.viewport.width, this.viewport.height, 0, 0, this.canvas.width, this.canvas.height)

    window.requestAnimationFrame(() => this.loop())
  }

  start() {
    /**
      * @type {HTMLCanvasElement}
      */
    const canvas = document.getElementById("pixcan")
    /**
      * @type {HTMLSelectElement}
      */
    const colorSelect = document.getElementById("color-select")
    /**
      * @type {HTMLCanvasElement}
      */
    this.offCanvas = document.getElementById("off-canvas")
    this.offCanvas.width = 1024
    this.offCanvas.height = 1024

    this.context = canvas.getContext('2d')
    this.context.imageSmoothingEnabled = false
    this.color = {
      r: 0,
      g: 0,
      b: 0,
    }
    this.viewport = {
      vx: 0,
      vy: 0,
      x: 0,
      y: 0,
      width: 256,
      height: 256,
      scale: 4
    }
    this.img = new ImageData(1024, 1024)

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
          x: Math.floor(event.offsetX / this.viewport.scale + this.viewport.x),
          y: Math.floor(event.offsetY / this.viewport.scale + this.viewport.y)
        }
        this.sendPoint()

        const imgIndex = (this.pen.y * 1024 + this.pen.x) * 4
        this.img.data[imgIndex] = this.color.r
        this.img.data[imgIndex + 1] = this.color.g
        this.img.data[imgIndex + 2] = this.color.b
        this.img.data[imgIndex + 3] = 255
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
        down: false,
        whileDown: () => this.viewport.vx = Math.max(this.viewport.vx - KEY_ACCELERATION, -MAX_VELOCITY),
        onUp: () => this.viewport.vx = 0
      },
      ArrowRight: {
        down: false,
        whileDown: () => this.viewport.vx = Math.min(this.viewport.vx + KEY_ACCELERATION, MAX_VELOCITY),
        onUp: () => this.viewport.vx = 0
      },
      ArrowUp: {
        down: false,
        whileDown: () => this.viewport.vy = Math.max(this.viewport.vy - KEY_ACCELERATION, -MAX_VELOCITY),
        onUp: () => this.viewport.vy = 0
      },
      ArrowDown: {
        down: false,
        whileDown: () => this.viewport.vy = Math.min(this.viewport.vy + KEY_ACCELERATION, MAX_VELOCITY),
        onUp: () => this.viewport.vy = 0
      },
    }

    document.onkeydown = (event) => {
      if (this.keys[event.key] == null) {
        return
      }
      this.keys[event.key].down = true
    }

    document.onkeyup = (event) => {
      if (this.keys[event.key] == null) {
        return
      }
      this.keys[event.key].down = false
      this.keys[event.key].onUp()
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
      console.log("Message event", e)
      const messages = await PixCan.parseMessages(e.data)

      messages.forEach(message => {
        this.img.data[(message.localY * 1024 + message.localX) * 4] = message.color.r
        this.img.data[(message.localY * 1024 + message.localX) * 4 + 1] = message.color.g
        this.img.data[(message.localY * 1024 + message.localX) * 4 + 2] = message.color.b
        this.img.data[(message.localY * 1024 + message.localX) * 4 + 3] = 255
      })
    })
    this.canvas = canvas
    this.loop()
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
      if (opcode == 1) {
        messages.push(parsePixelMessage(high32, low32))
      } else {
        console.log("Unknown opcode", opcode)
      }
    }
    return messages
  }
}

function parseMetricsMessage(high32, low32) {
  return {
    ts: low32,
    metricId,
    value
  }
}

function parsePixelMessage(high32, low32) {
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

  return {
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

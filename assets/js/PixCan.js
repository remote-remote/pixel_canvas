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
      const message = await PixCan.parseMessage(e.data)
      switch (message.type) {
        case 'pixel':
          this.handlePixelMessage(message)
          break
        case 'hello':
          this.userId = message.userId
          break
        case 'metrics':
          this.handleMetricsMessage(message)
          break
        default:
          console.log("Unknown message type", message.type)
          break
      }
    })

    this.canvas = canvas
    this.metrics = {}
    this.metricsDiv = document.getElementById("metrics")
    this.loop()

    setInterval(() => {
      this.setMetrics()
    }, 1000)
  }

  setMetrics() {
    for (const [name, { type, values }] of Object.entries(this.metrics)) {
      if (type == "histogram") {
        document.getElementById(`${name}-min`).innerText = values[0]?.value.min
        document.getElementById(`${name}-max`).innerText = values[0]?.value.max
        document.getElementById(`${name}-sum`).innerText = values[0]?.value.sum
        document.getElementById(`${name}-count`).innerText = values[0]?.value.count
      } else {
        document.getElementById(name).innerText = values[0]?.value || 0
      }
    }
  }

  handleMetricsMessage(message) {
    console.log("Metrics", this.metrics)
    if (!this.metrics[message.name]) {
      const div = document.createElement("div")
      const title = document.createElement("h3")
      title.innerText = message.name
      const value = document.createElement("div")

      value.setAttribute("id", message.name)
      if (message.metricType === "histogram") {
        const min = document.createElement("div")
        const minValue = document.createElement("span")
        minValue.setAttribute("id", `${message.name}-min`)
        const max = document.createElement("div")
        const maxValue = document.createElement("span")
        maxValue.setAttribute("id", `${message.name}-max`)
        const sum = document.createElement("div")
        const sumValue = document.createElement("span")
        sumValue.setAttribute("id", `${message.name}-sum`)
        const count = document.createElement("div")
        const countValue = document.createElement("span")
        countValue.setAttribute("id", `${message.name}-count`)

        min.appendChild(minValue)
        max.appendChild(maxValue)
        sum.appendChild(sumValue)
        count.appendChild(countValue)

        value.appendChild(min)
        value.appendChild(max)
        value.appendChild(sum)
        value.appendChild(count)
      }
      div.appendChild(title)
      div.appendChild(value)
      this.metricsDiv.appendChild(div)
    }

    this.metrics[message.name] = {
      type: message.metricType,
      values: message.timeseries
    }
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

  static async parseMessage(data) {
    if (data instanceof Blob) {
      const buffer = await data.arrayBuffer()
      const view = new DataView(buffer)

      const high = view.getUint32(0, false)
      const messageType = high >>> 28

      switch (messageType) {
        case 0:
          return parsePixelMessage(view, buffer.byteLength)
        case 1:
          return {
            type: 'hello',
            userId: view.getUint32(0, false) >>> 8 & 0xFFFFF
          }
        case 2:
          return {
            type: 'metrics',
            ts: view.getUint32(0, false),
            metricId: view.getUint32(4, false),
            value: view.getUint32(8, false)
          }
      }
    } else {
      return JSON.parse(data)
    }
  }

  handlePixelMessage(message) {
    message.pixels.forEach(pixel => {
      this.img.data[(pixel.localY * 1024 + pixel.localX) * 4] = pixel.color.r
      this.img.data[(pixel.localY * 1024 + pixel.localX) * 4 + 1] = pixel.color.g
      this.img.data[(pixel.localY * 1024 + pixel.localX) * 4 + 2] = pixel.color.b
      this.img.data[(pixel.localY * 1024 + pixel.localX) * 4 + 3] = 255
    })
  }
}


function parsePixelMessage(view, length) {
  const pixels = []
  const bytes = view.getUint32(0, false)
  const regionX = bytes >>> 22 & 0x3FF
  const regionY = bytes >>> 12 & 0x3FF
  let i = 3

  while (i < length) {
    const userId = view.getUint32(i, false) >>> 12
    const numPixels = (view.getUint32(i + 2, false) >>> 8) & 0xFFFFF
    i += 5

    for (let j = 0; j < numPixels; j++, i += 5) {
      const opcode = view.getUint8(i) >>> 4
      const localX = view.getUint16(i) >>> 2 & 0x3FF
      const localY = view.getUint16(i + 1) & 0x3FF
      const color = view.getUint16(i + 3)
      const r = ((color >>> 12) & 0xF) * 17  // Scale 0-15 to 0-255
      const g = ((color >>> 8) & 0xF) * 17
      const b = ((color >>> 4) & 0xF) * 17
      const a = (color & 0xF) * 17
      pixels.push({
        userId,
        opcode,
        localX,
        localY,
        color: {
          r, g, b, a
        }
      })
    }
  }

  return {
    type: 'pixel',
    pixels
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

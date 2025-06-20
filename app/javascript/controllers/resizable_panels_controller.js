import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chat", "log", "divider"]
  static values = { 
    mobileBreakpoint: { type: Number, default: 768 },
    minPanelWidth: { type: Number, default: 0.1 }, // 10% minimum
    maxPanelWidth: { type: Number, default: 0.9 }  // 90% maximum
  }

  connect() {
    this.boundMouseMove = this.onMouseMove.bind(this)
    this.boundMouseUp = this.stopResize.bind(this)
    this.setupResizeObserver()
    this.updateVisibility()
  }

  setupResizeObserver() {
    this.resizeObserver = new ResizeObserver(entries => {
      for (let entry of entries) {
        this.updateVisibility()
      }
    })
    this.resizeObserver.observe(this.element)
  }

  disconnect() {
    this.stopResize()
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
  }

  startResize(event) {
    if (this.isMobile()) return
    
    this.isResizing = true
    document.addEventListener("mousemove", this.boundMouseMove)
    document.addEventListener("mouseup", this.boundMouseUp)
    document.body.style.cursor = "col-resize"
    document.body.style.userSelect = "none"
    event.preventDefault()
  }

  onMouseMove(event) {
    if (!this.isResizing) return

    const rect = this.element.getBoundingClientRect()
    const containerWidth = rect.width
    let newChatWidth = event.clientX - rect.left

    const min = containerWidth * this.minPanelWidthValue
    const max = containerWidth * this.maxPanelWidthValue
    newChatWidth = Math.min(Math.max(newChatWidth, min), max)

    const chatPercent = (newChatWidth / containerWidth) * 100
    this.chatTarget.style.width = `${chatPercent}%`
    this.logTarget.style.width = `${100 - chatPercent}%`
  }

  stopResize() {
    if (!this.isResizing) return
    
    this.isResizing = false
    document.removeEventListener("mousemove", this.boundMouseMove)
    document.removeEventListener("mouseup", this.boundMouseUp)
    document.body.style.cursor = ""
    document.body.style.userSelect = ""
  }

  updateVisibility() {
    if (this.isMobile()) {
      this.dividerTarget.style.display = "none"
      this.resetPanelWidths()
    } else {
      this.dividerTarget.style.display = "block"
    }
  }

  resetPanelWidths() {
    this.chatTarget.style.width = ""
    this.logTarget.style.width = ""
  }

  isMobile() {
    return window.innerWidth <= this.mobileBreakpointValue
  }
}
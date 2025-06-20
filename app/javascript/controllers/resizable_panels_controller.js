import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chat", "log", "divider"]
  static values = { mobileBreakpoint: { type: Number, default: 768 } }

  connect() {
    this.boundMouseMove = this.onMouseMove.bind(this)
    this.boundMouseUp = this.stopResize.bind(this)
    this.updateVisibility()
    window.addEventListener("resize", this.updateVisibility.bind(this))
  }

  disconnect() {
    window.removeEventListener("resize", this.updateVisibility.bind(this))
    this.stopResize()
  }

  startResize(event) {
    if (this.isMobile()) return
    this.isResizing = true
    document.addEventListener("mousemove", this.boundMouseMove)
    document.addEventListener("mouseup", this.boundMouseUp)
    event.preventDefault()
  }

  onMouseMove(event) {
    if (!this.isResizing) return

    const rect = this.element.getBoundingClientRect()
    const containerWidth = rect.width
    let newChatWidth = event.clientX - rect.left

    const min = containerWidth * 0.1
    const max = containerWidth * 0.9
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
  }

  updateVisibility() {
    if (this.isMobile()) {
      this.dividerTarget.style.display = "none"
      this.chatTarget.style.width = ""
      this.logTarget.style.width = ""
    } else {
      this.dividerTarget.style.display = "block"
    }
  }

  isMobile() {
    return window.innerWidth <= this.mobileBreakpointValue
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["leftPanel", "rightPanel", "divider"]

  connect() {
    this.isDragging = false
    this.minWidth = 200
    this.setupEventListeners()
  }

  setupEventListeners() {
    this.dividerTarget.addEventListener("mousedown", this.startDrag.bind(this))
    document.addEventListener("mousemove", this.drag.bind(this))
    document.addEventListener("mouseup", this.stopDrag.bind(this))
  }

  disconnect() {
    document.removeEventListener("mousemove", this.drag.bind(this))
    document.removeEventListener("mouseup", this.stopDrag.bind(this))
  }

  startDrag(e) {
    this.isDragging = true
    e.preventDefault()
    document.body.style.cursor = "col-resize"
    document.body.style.userSelect = "none"
  }

  drag(e) {
    if (!this.isDragging) return

    const containerRect = this.element.getBoundingClientRect()
    const containerWidth = containerRect.width
    const mouseX = e.clientX - containerRect.left
    
    const leftWidth = Math.max(this.minWidth, Math.min(mouseX, containerWidth - this.minWidth))
    const rightWidth = containerWidth - leftWidth
    
    const leftPercent = (leftWidth / containerWidth) * 100
    const rightPercent = (rightWidth / containerWidth) * 100
    
    this.leftPanelTarget.style.width = `${leftPercent}%`
    this.rightPanelTarget.style.width = `${rightPercent}%`
  }

  stopDrag() {
    this.isDragging = false
    document.body.style.cursor = ""
    document.body.style.userSelect = ""
  }
}
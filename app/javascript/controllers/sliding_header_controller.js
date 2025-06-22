import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header", "pullTab"]
  static values = { 
    slideDistance: { type: Number, default: 60 },
    mobileBreakpoint: { type: Number, default: 768 }
  }
  
  connect() {
    this.isShowing = true
    this.isMobile = window.innerWidth <= this.mobileBreakpointValue
    this.mouseTimer = null
    
    // Wait for DOM to settle before calculating height
    requestAnimationFrame(() => {
      this.headerHeight = this.headerTarget.offsetHeight
      this.updateHeaderPosition()
      this.addEventListeners()
      
      // Hide header initially on desktop after a short delay
      if (!this.isMobile) {
        setTimeout(() => {
          this.hideHeader()
        }, 500)
      }
    })
  }
  
  disconnect() {
    this.removeEventListeners()
    if (this.mouseTimer) {
      clearTimeout(this.mouseTimer)
    }
  }
  
  addEventListeners() {
    this.handleMouseMove = this.onMouseMove.bind(this)
    this.handleResize = this.onResize.bind(this)
    
    document.addEventListener('mousemove', this.handleMouseMove)
    window.addEventListener('resize', this.handleResize)
  }
  
  removeEventListeners() {
    document.removeEventListener('mousemove', this.handleMouseMove)
    window.removeEventListener('resize', this.handleResize)
  }
  
  onMouseMove(event) {
    if (this.isMobile) return
    
    const mouseY = event.clientY
    
    // Clear any existing timer
    if (this.mouseTimer) {
      clearTimeout(this.mouseTimer)
    }
    
    if (mouseY <= this.slideDistanceValue && !this.isShowing) {
      this.showHeader()
    } else if (mouseY > this.headerHeight + 50 && this.isShowing) {
      this.hideHeader()
    }
  }
  
  onResize() {
    this.isMobile = window.innerWidth <= this.mobileBreakpointValue
    this.headerHeight = this.headerTarget.offsetHeight
    this.updateHeaderPosition()
  }
  
  showHeader() {
    this.isShowing = true
    this.headerTarget.style.transform = 'translateY(0)'
    this.dismissFlashAlerts()
  }
  
  hideHeader() {
    if (this.isMobile) return
    this.isShowing = false
    this.headerTarget.style.transform = `translateY(-${this.headerHeight}px)`
  }
  
  updateHeaderPosition() {
    if (this.isMobile) {
      this.showHeader()
    } else if (!this.isShowing) {
      this.hideHeader()
    }
  }
  
  dismissFlashAlerts() {
    const flashAlerts = document.querySelectorAll('[data-controller="alert"]')
    flashAlerts.forEach(alert => {
      alert.remove()
    })
  }
}
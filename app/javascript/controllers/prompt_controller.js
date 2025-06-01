import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "form"]

  connect() {
    this.updateTextareaAttributes()
  }

  keydown(event) {
    if (event.key === "Enter") {
      if (this.isMobile()) {
        // On mobile, Enter creates a new line, no form submission
        return
      } else {
        // On desktop, maintain existing behavior
        if (event.shiftKey) {
          return
        } else {
          event.preventDefault()
          this.submitForm()
        }
      }
    }
  }

  submitForm() {
    const form = this.textareaTarget.closest("form")
    if (form) {
      form.requestSubmit()
    }
  }

  clearForm() {
    this.textareaTarget.value = ""
  }

  isMobile() {
    // Check for mobile device using multiple indicators
    const userAgent = navigator.userAgent.toLowerCase()
    const hasTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0
    const smallScreen = window.matchMedia("(max-width: 768px)").matches
    
    // Check for mobile user agents
    const mobileUserAgents = /android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini/
    
    return hasTouch && (smallScreen || mobileUserAgents.test(userAgent))
  }

  updateTextareaAttributes() {
    if (this.isMobile()) {
      // On mobile, set enterkeyhint to "go" for better UX
      this.textareaTarget.setAttribute('enterkeyhint', 'enter')
    } else {
      // On desktop, set enterkeyhint to "send" 
      this.textareaTarget.setAttribute('enterkeyhint', 'send')
    }
  }
}
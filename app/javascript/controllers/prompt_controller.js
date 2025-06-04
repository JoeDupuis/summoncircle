import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "form"]

  connect() {
    this.updateTextareaAttributes()
    this.adjustHeight()
  }

  keydown(event) {
    if (event.key === "Enter") {
      if (this.isMobile()) {
        return
      } else {
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
    this.adjustHeight()
  }

  adjustHeight() {
    const textarea = this.textareaTarget
    textarea.style.height = 'auto'
    textarea.style.height = textarea.scrollHeight + 'px'
  }

  isMobile() {
    const userAgent = navigator.userAgent.toLowerCase()
    const hasTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0
    const smallScreen = window.matchMedia("(max-width: 768px)").matches
    
    const mobileUserAgents = /android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini/
    
    return hasTouch && (smallScreen || mobileUserAgents.test(userAgent))
  }

  updateTextareaAttributes() {
    if (this.isMobile()) {
      this.textareaTarget.setAttribute('enterkeyhint', 'enter')
    } else {
      this.textareaTarget.setAttribute('enterkeyhint', 'send')
    }
  }
}
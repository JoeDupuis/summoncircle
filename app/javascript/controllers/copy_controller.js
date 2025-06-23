import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]
  static classes = ["success", "error"]

  async copy(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    // For template elements, we need to access the content property
    const content = this.sourceTarget.content ? 
      this.sourceTarget.content.textContent.trim() : 
      this.sourceTarget.textContent.trim()
    
    if (!content) {
      this.showFeedback(button, 'Nothing to copy', false)
      return
    }
    
    try {
      await navigator.clipboard.writeText(content)
      this.showFeedback(button, 'Copied!', true)
    } catch (error) {
      console.error('Error copying to clipboard:', error)
      this.showFeedback(button, 'Failed to copy', false)
    }
  }
  
  showFeedback(button, message, success) {
    const originalText = button.textContent
    button.textContent = message
    button.disabled = true
    
    if (success && this.hasSuccessClass) {
      button.classList.add(this.successClass)
    } else if (!success && this.hasErrorClass) {
      button.classList.add(this.errorClass)
    }
    
    setTimeout(() => {
      button.textContent = originalText
      button.disabled = false
      if (this.hasSuccessClass) button.classList.remove(this.successClass)
      if (this.hasErrorClass) button.classList.remove(this.errorClass)
    }, 2000)
  }
}
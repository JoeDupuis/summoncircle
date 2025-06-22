import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    repositoryDiffUrl: String
  }
  
  static classes = ["success", "error"]

  async copy(event) {
    event.preventDefault()
    
    try {
      const response = await fetch(this.repositoryDiffUrlValue, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      if (!response.ok) {
        throw new Error('Failed to fetch diff')
      }
      
      const data = await response.json()
      const diff = data.diff
      
      if (!diff || diff.trim() === '') {
        this.showFeedback(event.target, 'No changes to copy', false)
        return
      }
      
      await navigator.clipboard.writeText(diff)
      this.showFeedback(event.target, 'Copied!', true)
      
    } catch (error) {
      console.error('Error copying diff:', error)
      this.showFeedback(event.target, 'Failed to copy', false)
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
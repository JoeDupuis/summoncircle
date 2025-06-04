import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "toggle"]
  static values = { maxLength: Number }

  connect() {
    this.maxLengthValue = this.maxLengthValue || 200
    this.checkLength()
  }

  checkLength() {
    const content = this.contentTarget.textContent
    if (content.length > this.maxLengthValue) {
      this.truncate()
    } else {
      this.hideToggle()
    }
  }

  truncate() {
    const content = this.contentTarget.textContent
    this.fullContent = content
    this.truncatedContent = content.substring(0, this.maxLengthValue) + "..."
    this.contentTarget.textContent = this.truncatedContent
    this.showToggle()
    this.toggleTarget.textContent = "Show more"
    this.isExpanded = false
  }

  toggle() {
    if (this.isExpanded) {
      this.contentTarget.textContent = this.truncatedContent
      this.toggleTarget.textContent = "Show more"
      this.isExpanded = false
    } else {
      this.contentTarget.textContent = this.fullContent
      this.toggleTarget.textContent = "Show less"
      this.isExpanded = true
    }
  }

  showToggle() {
    this.toggleTarget.style.display = "inline"
  }

  hideToggle() {
    this.toggleTarget.style.display = "none"
  }
}
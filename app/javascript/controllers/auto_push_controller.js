import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["branchSelection"]
  static values = { 
    enabled: Boolean
  }

  toggleAutoPush(event) {
    const isEnabled = event.target.checked
    if (isEnabled) {
      this.branchSelectionTarget.style.display = ''
    } else {
      this.branchSelectionTarget.style.display = 'none'
    }
  }
}
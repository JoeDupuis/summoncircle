import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { target: String }

  connect() {
    // Find and click the tab with the matching data-tab-panel
    const tab = document.querySelector(`[data-tab-panel="${this.targetValue}"]`)
    if (tab && !tab.classList.contains('-active')) {
      tab.click()
    }
    
    // Remove this element after switching
    this.element.remove()
  }
}
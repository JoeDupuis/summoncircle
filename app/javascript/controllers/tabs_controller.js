import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  switchTab(event) {
    const clickedTab = event.currentTarget
    const targetPanel = clickedTab.dataset.tabPanel

    this.tabTargets.forEach(tab => {
      tab.classList.remove("active")
    })

    this.panelTargets.forEach(panel => {
      panel.classList.remove("active")
    })

    clickedTab.classList.add("active")

    const activePanel = this.panelTargets.find(panel => panel.dataset.panelId === targetPanel)
    if (activePanel) {
      activePanel.classList.add("active")
    }
  }
}
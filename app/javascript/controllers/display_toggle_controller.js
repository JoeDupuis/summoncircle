import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "display", "edit"]

  toggle(event) {
    const isChecked = event.target.checked
    this.contentTargets.forEach(target => {
      target.style.display = isChecked ? '' : 'none'
    })
  }

  showEdit() {
    this.displayTarget.style.display = 'none'
    this.editTarget.style.display = 'block'
  }

  showDisplay() {
    this.editTarget.style.display = 'none'
    this.displayTarget.style.display = 'block'
  }
}
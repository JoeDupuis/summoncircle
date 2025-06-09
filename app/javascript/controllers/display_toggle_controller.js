import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  toggle(event) {
    const isChecked = event.target.checked
    this.contentTargets.forEach(target => {
      target.style.display = isChecked ? '' : 'none'
    })
  }
}
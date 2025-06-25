import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fields", "template"]

  connect() {
    this.index = this.element.querySelectorAll('.nested-field').length
  }

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(/__INDEX__/g, this.index)
    this.fieldsTarget.insertAdjacentHTML('beforeend', content)
    this.index++
  }

  remove(event) {
    event.preventDefault()
    const field = event.target.closest('.nested-field')
    
    if (field) {
      const destroyInput = field.querySelector('input[name*="_destroy"]')
      
      if (destroyInput) {
        destroyInput.value = '1'
        field.style.display = 'none'
      } else {
        field.remove()
      }
    }
  }
}
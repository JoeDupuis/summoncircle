import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fields", "hiddenField", "template"]
  static values = { fieldName: String }

  connect() {
    this.updateHiddenField()
  }

  add(event) {
    event.preventDefault()
    
    const template = this.templateTarget
    const clone = template.content.cloneNode(true)
    
    this.fieldsTarget.appendChild(clone)
    this.reindexFields()
    this.updateHiddenField()
  }

  remove(event) {
    event.preventDefault()
    event.target.closest('.nested-field').remove()
    this.reindexFields()
    this.updateHiddenField()
  }

  updateValue() {
    this.updateHiddenField()
  }

  reindexFields() {
    // No longer needed since we don't use index attributes
  }

  updateHiddenField() {
    const inputs = this.fieldsTarget.querySelectorAll('input[type="text"]')
    const values = Array.from(inputs).map(input => input.value).filter(v => v !== '')
    this.hiddenFieldTarget.value = JSON.stringify(values)
  }
}
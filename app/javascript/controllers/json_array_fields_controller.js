import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fields", "hiddenField"]
  static values = { fieldName: String }

  connect() {
    this.updateHiddenField()
  }

  add(event) {
    event.preventDefault()
    
    const newIndex = this.fieldsTarget.children.length
    const fieldHtml = `
      <div class="nested-field" style="display: flex; gap: 10px; margin-bottom: 10px;">
        <input type="text" 
               value="" 
               data-index="${newIndex}"
               data-action="input->json-array-fields#updateValue"
               style="flex: 1;">
        <button type="button" data-action="click->json-array-fields#remove" data-index="${newIndex}" style="padding: 5px 10px;">Remove</button>
      </div>
    `
    
    this.fieldsTarget.insertAdjacentHTML('beforeend', fieldHtml)
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
    const fields = this.fieldsTarget.querySelectorAll('.nested-field')
    fields.forEach((field, index) => {
      const input = field.querySelector('input')
      const button = field.querySelector('button')
      input.dataset.index = index
      button.dataset.index = index
    })
  }

  updateHiddenField() {
    const inputs = this.fieldsTarget.querySelectorAll('input[type="text"]')
    const values = Array.from(inputs).map(input => input.value).filter(v => v !== '')
    this.hiddenFieldTarget.value = JSON.stringify(values)
  }
}
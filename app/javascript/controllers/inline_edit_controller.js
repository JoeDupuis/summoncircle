import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "edit", "input", "cancelButton", "saveButton"]
  static values = { 
    url: String,
    attribute: String,
    model: String
  }

  connect() {
    this.hideEditMode()
  }

  startEdit() {
    this.showEditMode()
    this.inputTarget.value = this.displayTarget.textContent.trim()
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  save() {
    const value = this.inputTarget.value.trim()
    
    if (value === this.displayTarget.textContent.trim()) {
      this.cancel()
      return
    }

    this.disableButtons()
    
    const formData = new FormData()
    formData.append(`${this.modelValue}[${this.attributeValue}]`, value)
    formData.append("_method", "PATCH")

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: formData
    })
    .then(response => {
      if (response.ok) {
        this.displayTarget.textContent = value
        this.hideEditMode()
      } else {
        throw new Error("Failed to save")
      }
    })
    .catch(error => {
      console.error("Error saving:", error)
      alert("Failed to save. Please try again.")
    })
    .finally(() => {
      this.enableButtons()
    })
  }

  cancel() {
    this.hideEditMode()
  }

  keydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.save()
    } else if (event.key === "Escape") {
      this.cancel()
    }
  }

  showEditMode() {
    this.displayTarget.classList.add("hidden")
    this.editTarget.classList.remove("hidden")
  }

  hideEditMode() {
    this.displayTarget.classList.remove("hidden")
    this.editTarget.classList.add("hidden")
  }

  disableButtons() {
    this.saveButtonTarget.disabled = true
    this.cancelButtonTarget.disabled = true
  }

  enableButtons() {
    this.saveButtonTarget.disabled = false
    this.cancelButtonTarget.disabled = false
  }
}
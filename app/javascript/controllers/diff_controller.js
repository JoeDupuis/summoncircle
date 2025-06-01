import { Controller } from "@hotwired/stimulus"
import { html } from "diff2html"

export default class extends Controller {
  static targets = ["output"]
  static values = {
    diffText: String
  }

  connect() {
    if (this.hasDiffTextValue && this.diffTextValue.trim()) {
      this.render()
    }
  }

  diffTextValueChanged() {
    if (this.diffTextValue.trim()) {
      this.render()
    }
  }

  render() {
    const diffHtml = html(this.diffTextValue, {
      drawFileList: false,
      fileListToggle: false,
      fileListStartVisible: false,
      fileContentToggle: false,
      matching: 'lines',
      outputFormat: 'line-by-line',
      synchronisedScroll: true,
      renderNothingWhenEmpty: false
    })
    
    this.outputTarget.innerHTML = diffHtml
  }
}
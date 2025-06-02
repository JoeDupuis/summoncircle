import { Controller } from "@hotwired/stimulus"

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
    if (typeof Diff2HtmlUI === 'undefined') {
      console.error('Diff2HtmlUI is not available')
      return
    }

    // Get the shadow root from the output target
    const shadowRoot = this.outputTarget.shadowRoot
    if (!shadowRoot) {
      console.error('Shadow root not found')
      return
    }

    // Find the content container in the shadow DOM
    const contentContainer = shadowRoot.querySelector('[data-diff-target="shadowContent"]')
    if (!contentContainer) {
      console.error('Shadow content container not found')
      return
    }

    // Create Diff2HtmlUI instance targeting the shadow DOM container
    const diff2htmlUi = new Diff2HtmlUI(contentContainer, this.diffTextValue, {
      drawFileList: false,
      fileListToggle: false,
      fileListStartVisible: false,
      fileContentToggle: false,
      matching: 'lines',
      outputFormat: 'line-by-line',
      synchronisedScroll: true,
      renderNothingWhenEmpty: false
    })
    
    diff2htmlUi.draw()
  }
}
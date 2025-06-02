import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "viewToggle"]
  static values = {
    diffText: String
  }

  connect() {
    this.outputFormat = 'side-by-side'
    if (this.hasDiffTextValue && this.diffTextValue.trim()) {
      this.render()
    }
  }

  diffTextValueChanged() {
    if (this.diffTextValue.trim()) {
      this.render()
    }
  }

  toggleView() {
    this.outputFormat = this.viewToggleTarget.checked ? 'side-by-side' : 'line-by-line'
    this.render()
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
      drawFileList: true,
      fileListToggle: true,
      fileListStartVisible: false,
      fileContentToggle: true,
      matching: 'lines',
      outputFormat: this.outputFormat,
      synchronisedScroll: true,
      renderNothingWhenEmpty: false,
      highlight: true,
      fileListCloseable: false,
      colorScheme: 'auto'
    })
    
    diff2htmlUi.draw()
  }
}
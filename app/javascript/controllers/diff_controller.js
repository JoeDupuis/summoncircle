import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "viewToggle"]
  static values = {
    diffText: String
  }

  connect() {
    this.outputFormat = 'side-by-side'
    // Ensure the shadow root is available
    this.ensureShadowRoot()
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

  ensureShadowRoot() {
    // Check if shadow root already exists
    if (this.outputTarget.shadowRoot) {
      return this.outputTarget.shadowRoot
    }

    // If there's a template with shadowrootmode, the browser should have already created the shadow root
    // But in case it hasn't (e.g., due to timing issues with Turbo), we'll create it manually
    const template = this.outputTarget.querySelector('template[shadowrootmode]')
    if (template && !this.outputTarget.shadowRoot) {
      const shadowRoot = this.outputTarget.attachShadow({ mode: 'open' })
      shadowRoot.appendChild(template.content.cloneNode(true))
      return shadowRoot
    }

    return this.outputTarget.shadowRoot
  }

  render() {
    if (typeof Diff2HtmlUI === 'undefined') {
      console.error('Diff2HtmlUI is not available')
      return
    }

    // Ensure shadow root exists
    const shadowRoot = this.ensureShadowRoot()
    if (!shadowRoot) {
      console.error('Shadow root not found and could not be created')
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
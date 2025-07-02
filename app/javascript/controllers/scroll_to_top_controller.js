import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "container"]

  connect() {
    this.setupScrollListeners()
  }

  disconnect() {
    this.teardownScrollListeners()
  }

  setupScrollListeners() {
    if (this.hasContainerTarget) {
      this.containerTargets.forEach((container, index) => {
        const button = this.buttonTargets[index]
        if (button) {
          const handleScroll = () => this.toggleVisibility(container, button)
          container.addEventListener('scroll', handleScroll)
          container._scrollHandler = handleScroll
          this.toggleVisibility(container, button)
        }
      })
    } else {
      const handleScroll = () => this.toggleWindowVisibility()
      window.addEventListener('scroll', handleScroll)
      window._scrollHandler = handleScroll
      this.toggleWindowVisibility()
    }
  }

  teardownScrollListeners() {
    if (this.hasContainerTarget) {
      this.containerTargets.forEach(container => {
        if (container._scrollHandler) {
          container.removeEventListener('scroll', container._scrollHandler)
          delete container._scrollHandler
        }
      })
    } else {
      if (window._scrollHandler) {
        window.removeEventListener('scroll', window._scrollHandler)
        delete window._scrollHandler
      }
    }
  }

  toggleVisibility(container, button) {
    if (container.scrollTop > 300) {
      button.classList.add('visible')
    } else {
      button.classList.remove('visible')
    }
  }

  toggleWindowVisibility() {
    if (window.scrollY > 300) {
      this.element.classList.add('visible')
    } else {
      this.element.classList.remove('visible')
    }
  }

  scrollToTop(event) {
    const button = event.currentTarget
    const index = this.buttonTargets.indexOf(button)

    if (this.hasContainerTarget && index >= 0) {
      const container = this.containerTargets[index]
      container.scrollTo({
        top: 0,
        behavior: 'smooth'
      })
    } else {
      window.scrollTo({
        top: 0,
        behavior: 'smooth'
      })
    }
  }
}
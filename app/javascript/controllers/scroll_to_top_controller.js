import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { container: String }

  connect() {
    this.scrollContainer = this.getScrollContainer()
    this.toggleVisibility()

    if (this.scrollContainer === window) {
      window.addEventListener('scroll', this.handleScroll)
    } else {
      this.scrollContainer.addEventListener('scroll', this.handleScroll)
    }
  }

  disconnect() {
    if (this.scrollContainer === window) {
      window.removeEventListener('scroll', this.handleScroll)
    } else {
      this.scrollContainer.removeEventListener('scroll', this.handleScroll)
    }
  }

  getScrollContainer() {
    if (!this.hasContainerValue) {
      return window
    }

    if (this.containerValue === 'chat') {
      return this.element.closest('.chat-panel')
    } else if (this.containerValue === 'runs') {
      return this.element.closest('.log-panel')
    }

    return window
  }

  handleScroll = () => {
    this.toggleVisibility()
  }

  toggleVisibility() {
    const scrollTop = this.scrollContainer === window
      ? window.scrollY
      : this.scrollContainer.scrollTop

    if (scrollTop > 300) {
      this.element.classList.add('visible')
    } else {
      this.element.classList.remove('visible')
    }
  }

  scrollToTop() {
    if (this.scrollContainer === window) {
      window.scrollTo({
        top: 0,
        behavior: 'smooth'
      })
    } else {
      this.scrollContainer.scrollTo({
        top: 0,
        behavior: 'smooth'
      })
    }
  }
}
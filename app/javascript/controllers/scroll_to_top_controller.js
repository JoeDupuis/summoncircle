import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.toggleVisibility()
    window.addEventListener('scroll', this.handleScroll)
  }

  disconnect() {
    window.removeEventListener('scroll', this.handleScroll)
  }

  handleScroll = () => {
    this.toggleVisibility()
  }

  toggleVisibility() {
    if (window.scrollY > 300) {
      this.element.classList.add('visible')
    } else {
      this.element.classList.remove('visible')
    }
  }

  scrollToTop() {
    window.scrollTo({
      top: 0,
      behavior: 'smooth'
    })
  }
}
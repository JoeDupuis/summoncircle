import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.scrollContainer = this.findScrollContainer()
    this.useWindow = this.scrollContainer === window
    this.follow = true
    this.boundCheck = this.check.bind(this)
    this.boundMaybe = this.maybe.bind(this)
    this.scrollContainer.addEventListener("scroll", this.boundCheck)
    this.observer = new MutationObserver(this.boundMaybe)
    this.observer.observe(this.element, { childList: true, subtree: true })
    this.scroll()
  }

  disconnect() {
    this.scrollContainer.removeEventListener("scroll", this.boundCheck)
    if (this.observer) this.observer.disconnect()
  }

  check() {
    const el = this.useWindow ? document.documentElement : this.scrollContainer
    const bottom = el.scrollHeight - el.scrollTop - el.clientHeight <= 5
    this.follow = bottom
  }

  maybe() {
    if (this.follow) this.scroll()
  }

  scroll() {
    if (this.useWindow) {
      window.scrollTo(0, document.documentElement.scrollHeight)
    } else {
      this.scrollContainer.scrollTop = this.scrollContainer.scrollHeight
    }
  }

  findScrollContainer() {
    let el = this.element
    while (el && el !== document.body) {
      const overflow = getComputedStyle(el).overflowY
      if (overflow === "auto" || overflow === "scroll") {
        return el
      }
      el = el.parentElement
    }
    return window
  }
}

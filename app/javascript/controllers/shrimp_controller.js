import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { enabled: Boolean, trigger: Boolean }

  connect() {
    if (this.enabledValue && this.triggerValue) {
      this.launch()
    }
  }

  launch() {
    const count = 30
    for (let i = 0; i < count; i++) {
      const el = document.createElement("div")
      el.textContent = "\ud83c\udf64"
      el.classList.add("shrimp")
      el.style.left = Math.random() * 100 + "vw"
      el.style.animationDelay = Math.random() * 0.5 + "s"
      document.body.appendChild(el)
      el.addEventListener("animationend", () => el.remove())
    }
  }
}

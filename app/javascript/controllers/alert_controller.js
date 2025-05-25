import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["alert"]
  static classes = [ "closeBtn" ]

  connect() {
    if(!this.element.querySelector(`.${this.closeBtnClass}`)){
      const $btn = document.createElement("button");
      $btn.innerHTML = "&times;";
      $btn.classList.add(this.closeBtnClass);
      $btn.setAttribute("aria-hidden", true);
      $btn.addEventListener("click", this.dismiss.bind(this));

      this.element.prepend($btn);
    }
  }

  dismiss(event) {
    this.element.remove();
  }
}
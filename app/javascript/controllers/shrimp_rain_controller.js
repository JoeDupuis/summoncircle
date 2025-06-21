import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.createShrimpExplosion()
  }

  createShrimpExplosion() {
    const shrimpCount = 30
    const container = document.createElement('div')
    container.style.position = 'fixed'
    container.style.top = '0'
    container.style.left = '0'
    container.style.width = '100%'
    container.style.height = '100%'
    container.style.pointerEvents = 'none'
    container.style.zIndex = '9999'
    
    for (let i = 0; i < shrimpCount; i++) {
      const shrimp = this.createShrimp()
      container.appendChild(shrimp)
      this.animateShrimp(shrimp, i)
    }
    
    document.body.appendChild(container)
    
    setTimeout(() => {
      container.remove()
    }, 3000)
  }

  createShrimp() {
    const shrimp = document.createElement('div')
    shrimp.innerText = '🍤'
    shrimp.style.position = 'absolute'
    shrimp.style.fontSize = Math.random() * 30 + 20 + 'px'
    shrimp.style.userSelect = 'none'
    shrimp.style.transform = 'rotate(' + (Math.random() * 360) + 'deg)'
    shrimp.style.left = Math.random() * 100 + '%'
    shrimp.style.top = '-50px'
    return shrimp
  }

  animateShrimp(shrimp, index) {
    const duration = Math.random() * 2 + 1
    const horizontalMovement = (Math.random() - 0.5) * 200
    const rotation = (Math.random() - 0.5) * 720
    
    shrimp.animate([
      { 
        transform: `translateY(0) translateX(0) rotate(${shrimp.style.transform.match(/\d+/)[0]}deg)`,
        opacity: 1
      },
      { 
        transform: `translateY(${window.innerHeight + 100}px) translateX(${horizontalMovement}px) rotate(${rotation}deg)`,
        opacity: 0.3
      }
    ], {
      duration: duration * 1000,
      easing: 'cubic-bezier(0.25, 0.46, 0.45, 0.94)',
      delay: index * 50
    })
  }
}
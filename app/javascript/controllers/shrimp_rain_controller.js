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
    container.style.overflow = 'hidden'
    
    for (let i = 0; i < shrimpCount; i++) {
      const shrimp = this.createShrimp()
      container.appendChild(shrimp)
      this.animateShrimp(shrimp, i)
    }
    
    document.body.appendChild(container)
    
    const maxDelay = (shrimpCount - 1) * 20
    const maxDuration = 3 * 1000
    const totalTime = Math.min(maxDelay + maxDuration, 2000)
    
    setTimeout(() => {
      container.remove()
    }, totalTime)
  }

  createShrimp() {
    const shrimp = document.createElement('div')
    shrimp.innerText = '🍤'
    shrimp.style.position = 'absolute'
    const fontSize = Math.random() * 30 + 20
    shrimp.style.fontSize = fontSize + 'px'
    shrimp.style.userSelect = 'none'
    shrimp.style.transform = 'rotate(' + (Math.random() * 360) + 'deg)'
    shrimp.style.left = Math.random() * 100 + '%'
    shrimp.style.top = -(fontSize + 20) + 'px'
    return shrimp
  }

  animateShrimp(shrimp, index) {
    const duration = Math.random() * 2 + 1
    const horizontalMovement = (Math.random() - 0.5) * 200
    const rotation = (Math.random() - 0.5) * 720
    const delay = index * 20
    
    shrimp.animate([
      { 
        transform: `translateY(0) translateX(0) rotate(${shrimp.style.transform.match(/\d+/)[0]}deg)`,
        opacity: 1,
        offset: 0
      },
      { 
        transform: `translateY(${window.innerHeight * 0.3}px) translateX(${horizontalMovement * 0.3}px) rotate(${rotation * 0.3}deg)`,
        opacity: 1,
        offset: 0.3
      },
      { 
        transform: `translateY(${window.innerHeight * 0.6}px) translateX(${horizontalMovement * 0.6}px) rotate(${rotation * 0.6}deg)`,
        opacity: 0.5,
        offset: 0.6
      },
      { 
        transform: `translateY(${window.innerHeight + 100}px) translateX(${horizontalMovement}px) rotate(${rotation}deg)`,
        opacity: 0,
        offset: 1
      }
    ], {
      duration: duration * 1000,
      easing: 'cubic-bezier(0.25, 0.46, 0.45, 0.94)',
      delay: delay,
      fill: 'forwards'
    })
  }
}
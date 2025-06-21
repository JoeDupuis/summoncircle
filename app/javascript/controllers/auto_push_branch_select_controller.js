import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "loading"]
  static values = { projectId: Number }
  
  connect() {
    this.loadBranches()
  }
  
  async loadBranches() {
    if (!this.projectIdValue) return
    
    const currentValue = this.selectTarget.value
    this.showLoading()
    
    try {
      const response = await fetch(`/projects/${this.projectIdValue}/project_branches`)
      const data = await response.json()
      
      if (response.ok) {
        this.populateSelect(data.branches, currentValue)
      } else {
        console.error("Failed to load branches:", data.error)
        this.hideLoading()
      }
    } catch (error) {
      console.error("Error loading branches:", error)
      this.hideLoading()
    }
  }
  
  populateSelect(branches, currentValue) {
    this.selectTarget.innerHTML = ""
    
    // Add empty option
    const emptyOption = document.createElement("option")
    emptyOption.value = ""
    emptyOption.text = "Select branch..."
    this.selectTarget.appendChild(emptyOption)
    
    // Add branch options
    branches.forEach(branch => {
      const option = document.createElement("option")
      option.value = branch
      option.text = branch
      if (branch === currentValue) {
        option.selected = true
      }
      this.selectTarget.appendChild(option)
    })
    
    this.selectTarget.disabled = false
    this.hideLoading()
  }
  
  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.style.display = "inline"
    }
  }
  
  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.style.display = "none"
    }
  }
}
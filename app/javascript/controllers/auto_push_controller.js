import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["branchSelect", "branchSelection"]
  static values = { 
    taskId: Number,
    branchesUrl: String,
    enabled: Boolean,
    currentBranch: String
  }

  connect() {
    if (this.enabledValue) {
      this.fetchBranches()
    }
  }

  toggleAutoPush(event) {
    const isEnabled = event.target.checked
    if (isEnabled) {
      this.branchSelectionTarget.style.display = ''
      this.fetchBranches()
    } else {
      this.branchSelectionTarget.style.display = 'none'
    }
  }

  async fetchBranches() {
    try {
      const response = await fetch(this.branchesUrlValue)
      const data = await response.json()
      
      if (data.branches) {
        this.updateBranchOptions(data.branches)
      } else if (data.error) {
        alert(`Error fetching branches: ${data.error}`)
      }
    } catch (error) {
      alert(`Failed to fetch branches: ${error.message}`)
    }
  }

  updateBranchOptions(branches) {
    const select = this.branchSelectTarget
    const currentValue = this.currentBranchValue || select.value
    
    select.innerHTML = '<option value="">Select a branch...</option>'
    
    branches.forEach(branch => {
      const option = document.createElement('option')
      option.value = branch
      option.textContent = branch
      option.selected = branch === currentValue
      select.appendChild(option)
    })
  }
}
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["listPanel", "detailPanel", "searchBar", "searchInput", "filterDrawer", "filterForm", "tab"]
  static values = { tab: String }

  connect() {
    this.searchDebounce = null
    this._onFrameLoad = this._handleFrameLoad.bind(this)
    this.element.addEventListener("turbo:frame-load", this._onFrameLoad)
    this._setActiveTab(this.tabValue)
    this._syncConversationTargets()
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this._onFrameLoad)
    clearTimeout(this.searchDebounce)
  }

  // Called when a conversation is clicked
  conversationSelected(event) {
    this._highlightConversation(event?.currentTarget)

    if (this._isMobile()) {
      event?.preventDefault()

      const href = event?.currentTarget?.href
      if (href && window.Turbo?.visit) {
        window.Turbo.visit(href)
      }
    }
  }

  backToList() {
    if (this.hasListPanelTarget) this.listPanelTarget.classList.remove("hidden")
    if (this.hasDetailPanelTarget) this.detailPanelTarget.classList.add("hidden")
  }

  toggleSearch() {
    if (!this.hasSearchBarTarget) return
    const hidden = this.searchBarTarget.classList.toggle("hidden")
    if (!hidden && this.hasSearchInputTarget) {
      this.searchInputTarget.focus()
    }
  }

  toggleFilters() {
    if (this.hasFilterDrawerTarget) {
      this.filterDrawerTarget.classList.toggle("hidden")
    }
  }

  tabSelected(event) {
    const selectedTab = event?.currentTarget?.dataset?.tabName
    if (!selectedTab) return

    this.tabValue = selectedTab
    this._setActiveTab(selectedTab)
  }

  debouncedSearch() {
    clearTimeout(this.searchDebounce)
    this.searchDebounce = setTimeout(() => this._submitSearch(), 400)
  }

  _handleFrameLoad(event) {
    if (event.target.id === "conversation_detail" && this._isMobile()) {
      if (this.hasListPanelTarget) this.listPanelTarget.classList.add("hidden")
      if (this.hasDetailPanelTarget) {
        this.detailPanelTarget.classList.remove("hidden")
        this.detailPanelTarget.classList.add("flex", "flex-col")
      }
    }

    if (event.target.id === "conversation_list") {
      this._syncConversationTargets()
    }
  }

  _submitSearch() {
    if (this.hasFilterFormTarget) {
      this.filterFormTarget.requestSubmit()
    }
  }

  _setActiveTab(selectedTab) {
    if (!this.hasTabTarget) return

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tabName === selectedTab

      tab.classList.toggle("bg-white", active)
      tab.classList.toggle("text-deep", active)
      tab.classList.toggle("shadow-sm", active)

      tab.classList.toggle("text-slate-500", !active)
      if (!active) tab.classList.add("hover:text-deep")
    })
  }

  _highlightConversation(selectedElement) {
    if (!selectedElement) return

    this.element.querySelectorAll('[data-conversation-id]').forEach((element) => {
      const isSelected = element === selectedElement

      element.classList.toggle("bg-electric/5", isSelected)
      element.classList.toggle("border-l-2", isSelected)
      element.classList.toggle("border-electric", isSelected)

      if (isSelected) {
        element.classList.remove("bg-electric/[0.03]")
      }
    })
  }

  _isMobile() {
    return window.innerWidth < 640
  }

  _syncConversationTargets() {
    const targetFrame = this._isMobile() ? "_top" : "conversation_detail"

    this.element.querySelectorAll('[data-conversation-id]').forEach((element) => {
      element.dataset.turboFrame = targetFrame
    })
  }
}

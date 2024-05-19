window.setTabByName = (tabName) => {
  window.location.hash = `tab-${tabName}`

  return tabName
}

// The conditionals and currIndex stuff ensures that
// the tab index is always set to 0 if the hash is empty
// AND other hash values are ignored
window.getTabFromHash = (currentTabName, defaultTabName) => {
  if (window.location.hash === '' || window.location.hash === '#') {
    return defaultTabName
  }

  if (window.location.hash.startsWith('#tab-')) {
    return window.location.hash.replace('#tab-', '')
  }

  return currentTabName
}

window.setTabIndex = (index) => {
  window.location.hash = `tab-${index}`

  return index
}

// The conditionals and currIndex stuff ensures that
// the tab index is always set to 0 if the hash is empty
// AND other hash values are ignored
window.getTabIndex = (currIndex) => {
  if (window.location.hash === '' || window.location.hash === '#') {
    return 0
  }

  if (window.location.hash.startsWith('#tab-')) {
    return parseInt(window.location.hash.replace('#tab-', ''))
  }

  return currIndex
}

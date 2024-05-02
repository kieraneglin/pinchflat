window.copyTextToClipboard = async (text) => {
  // Navigator clipboard api needs a secure context (https)
  if (navigator.clipboard && window.isSecureContext) {
    await navigator.clipboard.writeText(text)
  } else {
    const textArea = document.createElement('textarea')
    textArea.value = text
    // Move textarea out of the viewport so it's not visible
    textArea.style.position = 'absolute'
    textArea.style.left = '-999999px'

    document.body.prepend(textArea)
    textArea.select()

    try {
      document.execCommand('copy')
    } catch (error) {
      console.error(error)
    } finally {
      textArea.remove()
    }
  }
}

window.markVersionAsSeen = (versionString) => {
  localStorage.setItem('seenVersion', versionString)
}

window.isVersionSeen = (versionString) => {
  return localStorage.getItem('seenVersion') === versionString
}

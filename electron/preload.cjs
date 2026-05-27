const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  onStateChange: (callback) => {
    const handler = (_, state) => callback(state)
    ipcRenderer.on('state-change', handler)
    return () => ipcRenderer.removeListener('state-change', handler)
  },
  setState: (state) => ipcRenderer.send('set-state', state),
  quit: () => ipcRenderer.send('quit'),
  getTheme: () => ipcRenderer.invoke('get-theme'),
  setTheme: (theme) => ipcRenderer.send('set-theme', theme),
  onThemeChange: (callback) => {
    const handler = (_, theme) => callback(theme)
    ipcRenderer.on('theme-change', handler)
    return () => ipcRenderer.removeListener('theme-change', handler)
  },
  getStyle: () => ipcRenderer.invoke('get-style'),
  setStyle: (style) => ipcRenderer.send('set-style', style),
  onStyleChange: (callback) => {
    const handler = (_, style) => callback(style)
    ipcRenderer.on('style-change', handler)
    return () => ipcRenderer.removeListener('style-change', handler)
  },
  focusApp: () => ipcRenderer.send('focus-app'),
  getMute: () => ipcRenderer.invoke('get-mute'),
  setMute: (muted) => ipcRenderer.send('set-mute', muted),
  getStats: () => ipcRenderer.invoke('get-stats'),
  setWindowHeight: (h) => ipcRenderer.send('set-window-height', h),
})

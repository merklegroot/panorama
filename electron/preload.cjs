const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('explorer', {
  getLocations: () => ipcRenderer.invoke('fs:locations'),
  readDirectory: (path, showHidden) => ipcRenderer.invoke('fs:readDirectory', path, showHidden),
  getThumbnail: (path) => ipcRenderer.invoke('fs:thumbnail', path),
  open: (path) => ipcRenderer.invoke('fs:open', path),
  reveal: (path) => ipcRenderer.invoke('fs:reveal', path),
  chooseFolder: () => ipcRenderer.invoke('fs:chooseFolder'),
  newFolder: (path) => ipcRenderer.invoke('fs:newFolder', path),
  rename: (path, name) => ipcRenderer.invoke('fs:rename', path, name),
  trash: (paths) => ipcRenderer.invoke('fs:trash', paths),
  setClipboard: (paths, cut) => ipcRenderer.invoke('fs:setClipboard', paths, cut),
  getClipboard: () => ipcRenderer.invoke('fs:getClipboard'),
  paste: (path) => ipcRenderer.invoke('fs:paste', path),
  listNotes: () => ipcRenderer.invoke('notes:list'),
  addNote: (body, folderPath) => ipcRenderer.invoke('notes:add', body, folderPath),
  setNoteStatus: (id, status) => ipcRenderer.invoke('notes:setStatus', id, status),
})

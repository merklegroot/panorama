const { app, BrowserWindow, dialog, ipcMain, nativeImage, shell } = require('electron')
const fs = require('node:fs/promises')
const os = require('node:os')
const path = require('node:path')

app.setName('Panorama')

const isDev = !app.isPackaged
let mainWindow
let clipboard = { paths: [], cut: false }
let notesPath

function resolveNotesPath() {
  if (notesPath) return notesPath

  if (!app.isPackaged) {
    notesPath = path.join(__dirname, '..', 'notes', 'improvements.json')
    return notesPath
  }

  // Packaged builds used via the repo launcher live at:
  //   <repo>/release/mac-<arch>/Panorama.app/Contents/MacOS/Panorama
  // Notes must stay in the repo (outside app.asar) so Cursor can read them.
  const repoRoot = path.resolve(path.dirname(app.getPath('exe')), '..', '..', '..', '..', '..')
  notesPath = path.join(repoRoot, 'notes', 'improvements.json')
  return notesPath
}

async function readNotesFile() {
  try {
    const raw = await fs.readFile(resolveNotesPath(), 'utf8')
    const parsed = JSON.parse(raw)
    return Array.isArray(parsed.notes) ? parsed : { notes: [] }
  } catch (error) {
    if (error && error.code === 'ENOENT') return { notes: [] }
    throw error
  }
}

async function writeNotesFile(data) {
  const target = resolveNotesPath()
  await fs.mkdir(path.dirname(target), { recursive: true })
  await fs.writeFile(target, `${JSON.stringify(data, null, 2)}\n`, 'utf8')
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1240,
    height: 780,
    minWidth: 850,
    minHeight: 520,
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 18, y: 18 },
    backgroundColor: '#f6f7f9',
    vibrancy: 'under-window',
    visualEffectState: 'active',
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  })

  if (isDev) {
    mainWindow.loadURL('http://localhost:5173')
  } else {
    mainWindow.loadFile(path.join(__dirname, '..', 'dist', 'index.html'))
  }
}

function registerIpc() {
  ipcMain.handle('fs:locations', async () => {
    const home = os.homedir()
    const candidates = [
      ['Home', home, 'home'],
      ['Desktop', path.join(home, 'Desktop'), 'monitor'],
      ['Documents', path.join(home, 'Documents'), 'file'],
      ['Downloads', path.join(home, 'Downloads'), 'download'],
      ['Pictures', path.join(home, 'Pictures'), 'image'],
      ['Music', path.join(home, 'Music'), 'music'],
      ['Movies', path.join(home, 'Movies'), 'video'],
    ]
    const locations = []
    for (const [name, locationPath, icon] of candidates) {
      try {
        await fs.access(locationPath)
        locations.push({ name, path: locationPath, icon })
      } catch {
        // Standard folders can be absent.
      }
    }
    return locations
  })

  ipcMain.handle('fs:readDirectory', async (_event, directoryPath, showHidden = false) => {
    const dirents = await fs.readdir(directoryPath, { withFileTypes: true })
    const visible = showHidden ? dirents : dirents.filter((item) => !item.name.startsWith('.'))
    const entries = await Promise.all(
      visible.map(async (dirent) => {
        const fullPath = path.join(directoryPath, dirent.name)
        try {
          const stats = await fs.stat(fullPath)
          return {
            name: dirent.name,
            path: fullPath,
            isDirectory: dirent.isDirectory(),
            isSymbolicLink: dirent.isSymbolicLink(),
            size: stats.size,
            modified: stats.mtime.toISOString(),
            extension: dirent.isDirectory() ? '' : path.extname(dirent.name).slice(1).toLowerCase(),
          }
        } catch {
          return null
        }
      }),
    )
    return entries.filter(Boolean)
  })

  ipcMain.handle('fs:open', async (_event, targetPath) => {
    const error = await shell.openPath(targetPath)
    if (error) throw new Error(error)
  })

  ipcMain.handle('fs:thumbnail', async (_event, targetPath) => {
    try {
      const image = await nativeImage.createThumbnailFromPath(targetPath, { width: 144, height: 144 })
      return image.isEmpty() ? null : image.toDataURL()
    } catch {
      return null
    }
  })

  ipcMain.handle('fs:reveal', (_event, targetPath) => shell.showItemInFolder(targetPath))

  ipcMain.handle('fs:chooseFolder', async () => {
    const result = await dialog.showOpenDialog(mainWindow, {
      properties: ['openDirectory', 'createDirectory'],
      title: 'Choose a folder',
    })
    return result.canceled ? null : result.filePaths[0]
  })

  ipcMain.handle('fs:newFolder', async (_event, parentPath) => {
    const folderPath = await uniquePath(parentPath, 'New folder')
    await fs.mkdir(folderPath)
    return folderPath
  })

  ipcMain.handle('fs:rename', async (_event, oldPath, newName) => {
    if (!newName || newName.includes('/') || newName.includes('\0')) {
      throw new Error('That name is not valid.')
    }
    const destination = path.join(path.dirname(oldPath), newName)
    await fs.rename(oldPath, destination)
    return destination
  })

  ipcMain.handle('fs:trash', async (_event, paths) => {
    for (const targetPath of paths) await shell.trashItem(targetPath)
  })

  ipcMain.handle('fs:setClipboard', (_event, paths, cut) => {
    clipboard = { paths, cut }
    return clipboard
  })

  ipcMain.handle('fs:getClipboard', () => clipboard)

  ipcMain.handle('fs:paste', async (_event, destinationDirectory) => {
    const pasted = []
    for (const source of clipboard.paths) {
      const destination = await uniquePath(destinationDirectory, path.basename(source))
      if (clipboard.cut) await fs.rename(source, destination)
      else await fs.cp(source, destination, { recursive: true, errorOnExist: true })
      pasted.push(destination)
    }
    if (clipboard.cut) clipboard = { paths: [], cut: false }
    return pasted
  })

  ipcMain.handle('notes:list', async () => {
    const data = await readNotesFile()
    return data.notes
  })

  ipcMain.handle('notes:add', async (_event, body, folderPath = null) => {
    const text = typeof body === 'string' ? body.trim() : ''
    if (!text) throw new Error('Note text is required.')
    const data = await readNotesFile()
    const note = {
      id: `note_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`,
      body: text,
      status: 'open',
      createdAt: new Date().toISOString(),
      completedAt: null,
      folderPath: typeof folderPath === 'string' && folderPath ? folderPath : null,
    }
    data.notes.unshift(note)
    await writeNotesFile(data)
    return note
  })

  ipcMain.handle('notes:setStatus', async (_event, id, status) => {
    if (status !== 'open' && status !== 'done') throw new Error('Status must be open or done.')
    const data = await readNotesFile()
    const note = data.notes.find((item) => item.id === id)
    if (!note) throw new Error('Note not found.')
    note.status = status
    note.completedAt = status === 'done' ? new Date().toISOString() : null
    await writeNotesFile(data)
    return note
  })
}

async function uniquePath(directory, originalName) {
  const extension = path.extname(originalName)
  const stem = path.basename(originalName, extension)
  let candidate = path.join(directory, originalName)
  let number = 1
  while (true) {
    try {
      await fs.access(candidate)
      const suffix = number === 1 ? ' copy' : ` copy ${number}`
      candidate = path.join(directory, `${stem}${suffix}${extension}`)
      number += 1
    } catch {
      return candidate
    }
  }
}

app.whenReady().then(() => {
  registerIpc()
  createWindow()
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})

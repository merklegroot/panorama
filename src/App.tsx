import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  ArrowDown, ArrowLeft, ArrowRight, ArrowUp, Clipboard, Copy, Download, Eye,
  File, FileArchive, FileCode2, FileImage, FileText, Folder, FolderOpen,
  Grid2X2, HardDrive, Home, Image, Info, List, Monitor, MoreHorizontal, Music,
  Pencil, Plus, RefreshCw, Scissors, Search, Trash2, Video, ChevronRight,
} from 'lucide-react'
import './App.css'
import type { FileEntry, Location } from './types'

type SortKey = 'name' | 'modified' | 'type' | 'size'
type ViewMode = 'list' | 'grid'

const locationIcons = { home: Home, monitor: Monitor, file: FileText, download: Download, image: Image, music: Music, video: Video }
const imageExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'heic']

function formatSize(bytes: number, isDirectory: boolean) {
  if (isDirectory) return '—'
  if (bytes < 1024) return `${bytes} B`
  const units = ['KB', 'MB', 'GB', 'TB']
  let size = bytes / 1024
  let unit = 0
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024
    unit += 1
  }
  return `${size < 10 ? size.toFixed(1) : Math.round(size)} ${units[unit]}`
}

function fileType(entry: FileEntry) {
  if (entry.isDirectory) return 'Folder'
  return entry.extension ? `${entry.extension.toUpperCase()} file` : 'File'
}

function FileIcon({ entry, size = 20 }: { entry: FileEntry; size?: number }) {
  if (entry.isDirectory) return <Folder className="folder-icon" size={size} fill="currentColor" />
  if (imageExtensions.includes(entry.extension))
    return <FileImage className="image-icon" size={size} />
  if (['js', 'jsx', 'ts', 'tsx', 'css', 'html', 'py', 'rs', 'go', 'json'].includes(entry.extension))
    return <FileCode2 className="code-icon" size={size} />
  if (['zip', 'rar', '7z', 'tar', 'gz', 'dmg'].includes(entry.extension))
    return <FileArchive className="archive-icon" size={size} />
  if (['txt', 'md', 'pdf', 'doc', 'docx', 'rtf'].includes(entry.extension))
    return <FileText className="document-icon" size={size} />
  return <File className="generic-icon" size={size} />
}

function ImagePreview({ entry }: { entry: FileEntry }) {
  const [source, setSource] = useState<string | null>(null)

  useEffect(() => {
    let active = true
    setSource(null)
    window.explorer?.getThumbnail(entry.path)
      .then((thumbnail) => { if (active) setSource(thumbnail) })
      .catch(() => { if (active) setSource(null) })
    return () => { active = false }
  }, [entry.path])

  if (!source) return <FileIcon entry={entry} size={48} />
  return <img className="image-preview" src={source} alt="" draggable={false} />
}

function App() {
  const api = window.explorer
  const [locations, setLocations] = useState<Location[]>([])
  const [currentPath, setCurrentPath] = useState('')
  const [entries, setEntries] = useState<FileEntry[]>([])
  const [history, setHistory] = useState<string[]>([])
  const [historyIndex, setHistoryIndex] = useState(-1)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [search, setSearch] = useState('')
  const [view, setView] = useState<ViewMode>('list')
  const [sort, setSort] = useState<{ key: SortKey; ascending: boolean }>({ key: 'name', ascending: true })
  const [columnWidths, setColumnWidths] = useState<Partial<Record<SortKey, number>>>({})
  const [showHidden, setShowHidden] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [refreshToken, setRefreshToken] = useState(0)
  const [editingAddress, setEditingAddress] = useState(false)
  const [addressValue, setAddressValue] = useState('')
  const [renaming, setRenaming] = useState<string | null>(null)
  const [contextMenu, setContextMenu] = useState<{ x: number; y: number; entry?: FileEntry } | null>(null)
  const renameRef = useRef<HTMLInputElement>(null)

  const navigate = useCallback((targetPath: string) => {
    if (!targetPath || targetPath === currentPath) return
    const nextHistory = history.slice(0, historyIndex + 1)
    nextHistory.push(targetPath)
    setHistory(nextHistory)
    setHistoryIndex(nextHistory.length - 1)
    setCurrentPath(targetPath)
    setSelected(new Set())
    setSearch('')
    setError('')
  }, [currentPath, history, historyIndex])

  useEffect(() => {
    if (!api) {
      setLoading(false)
      setError('Panorama needs to run as a desktop app. Use npm run dev to launch it.')
      return
    }
    api.getLocations().then((items) => {
      setLocations(items)
      const initialPath = items.find((item) => item.name === 'Home')?.path ?? '/'
      setCurrentPath(initialPath)
      setHistory([initialPath])
      setHistoryIndex(0)
    }).catch((reason: unknown) => setError(reason instanceof Error ? reason.message : String(reason)))
  }, [api])

  const refresh = useCallback(() => setRefreshToken((value) => value + 1), [])

  useEffect(() => {
    if (!api || !currentPath) return
    let active = true
    setLoading(true)
    setError('')
    api.readDirectory(currentPath, showHidden)
      .then((items) => { if (active) setEntries(items) })
      .catch((reason: unknown) => { if (active) setError(reason instanceof Error ? reason.message : String(reason)) })
      .finally(() => { if (active) setLoading(false) })
    return () => { active = false }
  }, [api, currentPath, showHidden, refreshToken])

  useEffect(() => {
    if (renaming) {
      renameRef.current?.focus()
      renameRef.current?.select()
    }
  }, [renaming])

  const visibleEntries = useMemo(() => {
    const query = search.toLocaleLowerCase()
    return entries.filter((entry) => entry.name.toLocaleLowerCase().includes(query)).sort((a, b) => {
      if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1
      let result = 0
      if (sort.key === 'name') result = a.name.localeCompare(b.name, undefined, { numeric: true })
      if (sort.key === 'modified') result = new Date(a.modified).getTime() - new Date(b.modified).getTime()
      if (sort.key === 'type') result = fileType(a).localeCompare(fileType(b))
      if (sort.key === 'size') result = a.size - b.size
      return sort.ascending ? result : -result
    })
  }, [entries, search, sort])

  const goBack = useCallback(() => {
    if (historyIndex <= 0) return
    const nextIndex = historyIndex - 1
    setHistoryIndex(nextIndex)
    setCurrentPath(history[nextIndex])
    setSelected(new Set())
  }, [history, historyIndex])

  const goForward = useCallback(() => {
    if (historyIndex >= history.length - 1) return
    const nextIndex = historyIndex + 1
    setHistoryIndex(nextIndex)
    setCurrentPath(history[nextIndex])
    setSelected(new Set())
  }, [history, historyIndex])

  const goUp = useCallback(() => {
    if (!currentPath || currentPath === '/') return
    navigate(currentPath.slice(0, currentPath.lastIndexOf('/')) || '/')
  }, [currentPath, navigate])

  const selectedEntries = entries.filter((entry) => selected.has(entry.path))

  const chooseEntry = (entry: FileEntry, event: React.MouseEvent) => {
    if (event.metaKey || event.ctrlKey) {
      setSelected((previous) => {
        const next = new Set(previous)
        if (next.has(entry.path)) next.delete(entry.path)
        else next.add(entry.path)
        return next
      })
    } else setSelected(new Set([entry.path]))
  }

  const openEntry = useCallback((entry: FileEntry) => {
    if (entry.isDirectory) navigate(entry.path)
    else api?.open(entry.path).catch((reason: unknown) => setError(String(reason)))
  }, [api, navigate])

  const createFolder = async () => {
    if (!api) return
    try {
      const newPath = await api.newFolder(currentPath)
      refresh()
      setSelected(new Set([newPath]))
      setRenaming(newPath)
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : String(reason))
    }
  }

  const submitRename = async (entry: FileEntry, newName: string) => {
    setRenaming(null)
    if (!api || !newName.trim() || newName === entry.name) return
    try {
      await api.rename(entry.path, newName.trim())
      refresh()
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : String(reason))
    }
  }

  const removeSelected = useCallback(async () => {
    if (!api || selected.size === 0) return
    try {
      await api.trash([...selected])
      setSelected(new Set())
      refresh()
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : String(reason))
    }
  }, [api, refresh, selected])

  const copySelected = useCallback(async (cut: boolean) => {
    if (!api || selected.size === 0) return
    await api.setClipboard([...selected], cut)
  }, [api, selected])

  const paste = useCallback(async () => {
    if (!api) return
    try {
      await api.paste(currentPath)
      refresh()
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : String(reason))
    }
  }, [api, currentPath, refresh])

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement
      if (target.tagName === 'INPUT') return
      if (event.key === 'Backspace' && !event.metaKey) goBack()
      if ((event.key === 'Delete' || (event.metaKey && event.key === 'Backspace')) && selected.size) {
        event.preventDefault()
        void removeSelected()
      }
      if (event.metaKey && event.key.toLowerCase() === 'c') void copySelected(false)
      if (event.metaKey && event.key.toLowerCase() === 'x') void copySelected(true)
      if (event.metaKey && event.key.toLowerCase() === 'v') void paste()
      if (event.metaKey && event.key.toLowerCase() === 'l') {
        event.preventDefault()
        setAddressValue(currentPath)
        setEditingAddress(true)
      }
      if (event.metaKey && event.key.toLowerCase() === 'a') {
        event.preventDefault()
        setSelected(new Set(visibleEntries.map((entry) => entry.path)))
      }
      if (event.key === 'Enter' && selectedEntries.length === 1) openEntry(selectedEntries[0])
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  })

  const setSortKey = (key: SortKey) => {
    setSort((previous) => ({ key, ascending: previous.key === key ? !previous.ascending : true }))
  }

  const startColumnResize = (key: SortKey, event: React.PointerEvent<HTMLSpanElement>) => {
    event.preventDefault()
    event.stopPropagation()
    const header = event.currentTarget.parentElement
    if (!header) return

    const startX = event.clientX
    const startWidth = header.getBoundingClientRect().width
    const minimumWidths: Record<SortKey, number> = { name: 140, modified: 130, type: 90, size: 70 }

    const onPointerMove = (moveEvent: PointerEvent) => {
      const width = Math.max(minimumWidths[key], startWidth + moveEvent.clientX - startX)
      setColumnWidths((previous) => ({ ...previous, [key]: width }))
    }
    const onPointerUp = () => {
      window.removeEventListener('pointermove', onPointerMove)
      window.removeEventListener('pointerup', onPointerUp)
      document.body.classList.remove('resizing-column')
    }

    document.body.classList.add('resizing-column')
    window.addEventListener('pointermove', onPointerMove)
    window.addEventListener('pointerup', onPointerUp)
  }

  const showContextMenu = (event: React.MouseEvent, entry?: FileEntry) => {
    event.preventDefault()
    if (entry && !selected.has(entry.path)) setSelected(new Set([entry.path]))
    setContextMenu({ x: event.clientX, y: event.clientY, entry })
  }

  const pathParts = currentPath.split('/').filter(Boolean)

  return (
    <main className="app-shell" onClick={() => setContextMenu(null)}>
      <aside className="sidebar">
        <div className="sidebar-drag-region" />
        <div className="brand"><div className="brand-mark"><FolderOpen size={17} fill="currentColor" /></div><span>Panorama</span></div>
        <nav>
          <p className="nav-label">Quick access</p>
          {locations.map((location) => {
            const Icon = locationIcons[location.icon as keyof typeof locationIcons] ?? Folder
            return (
              <button className={`nav-item ${currentPath === location.path ? 'active' : ''}`} key={location.path} onClick={() => navigate(location.path)}>
                <Icon size={17} /><span>{location.name}</span>
              </button>
            )
          })}
          <p className="nav-label devices-label">Locations</p>
          <button className={`nav-item ${currentPath === '/' ? 'active' : ''}`} onClick={() => navigate('/')}>
            <HardDrive size={17} /><span>Macintosh HD</span>
          </button>
          <button className="nav-item" onClick={async () => {
            const folder = await api?.chooseFolder()
            if (folder) navigate(folder)
          }}>
            <Plus size={17} /><span>Open folder…</span>
          </button>
        </nav>
        <div className="sidebar-footer"><Info size={14} /><span>{selected.size ? `${selected.size} selected` : `${entries.length} items`}</span></div>
      </aside>

      <section className="workspace">
        <header className="titlebar">
          <div className="nav-controls">
            <button title="Back" disabled={historyIndex <= 0} onClick={goBack}><ArrowLeft /></button>
            <button title="Forward" disabled={historyIndex >= history.length - 1} onClick={goForward}><ArrowRight /></button>
            <button title="Up one level" disabled={currentPath === '/'} onClick={goUp}><ArrowUp /></button>
            <button title="Refresh" onClick={refresh}><RefreshCw className={loading ? 'spinning' : ''} /></button>
          </div>

          {editingAddress ? (
            <form className="address-input-wrap" onSubmit={(event) => {
              event.preventDefault()
              setEditingAddress(false)
              navigate(addressValue)
            }}>
              <Folder size={15} />
              <input autoFocus value={addressValue} onFocus={(event) => event.currentTarget.select()} onChange={(event) => setAddressValue(event.target.value)} onBlur={() => setEditingAddress(false)} />
            </form>
          ) : (
            <div className="breadcrumbs" title="Click to type a path" onClick={() => { setAddressValue(currentPath); setEditingAddress(true) }}>
              <button title="Macintosh HD"><HardDrive size={15} /></button>
              {pathParts.map((part, index) => {
                const partPath = `/${pathParts.slice(0, index + 1).join('/')}`
                return <span className="breadcrumb-part" key={partPath}><ChevronRight size={14} /><button>{part}</button></span>
              })}
            </div>
          )}

          <label className="search-box">
            <Search size={15} />
            <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search this folder" />
            {search && <button onClick={() => setSearch('')}>×</button>}
          </label>
        </header>

        <div className="commandbar">
          <button className="primary-action" onClick={() => void createFolder()}><Plus size={16} /><span>New folder</span></button>
          <div className="separator" />
          <button disabled={!selected.size} title="Cut" onClick={() => void copySelected(true)}><Scissors /></button>
          <button disabled={!selected.size} title="Copy" onClick={() => void copySelected(false)}><Copy /></button>
          <button title="Paste" onClick={() => void paste()}><Clipboard /></button>
          <button disabled={selected.size !== 1} title="Rename" onClick={() => selectedEntries[0] && setRenaming(selectedEntries[0].path)}><Pencil /></button>
          <button disabled={!selected.size} title="Move to Trash" onClick={() => void removeSelected()}><Trash2 /></button>
          <div className="command-spacer" />
          <button className={showHidden ? 'toggled' : ''} title={showHidden ? 'Hide hidden files' : 'Show hidden files'} onClick={() => setShowHidden((value) => !value)}><Eye /></button>
          <div className="view-switcher">
            <button className={view === 'list' ? 'active' : ''} onClick={() => setView('list')} title="Details view"><List /></button>
            <button className={view === 'grid' ? 'active' : ''} onClick={() => setView('grid')} title="Icon view"><Grid2X2 /></button>
          </div>
          <button title="More options" onClick={(event) => {
            event.stopPropagation()
            setContextMenu({ x: window.innerWidth - 225, y: 96 })
          }}><MoreHorizontal /></button>
        </div>

        <div
          className={`file-area ${view}`}
          style={{
            '--column-name': columnWidths.name ? `${columnWidths.name}px` : undefined,
            '--column-modified': columnWidths.modified ? `${columnWidths.modified}px` : undefined,
            '--column-type': columnWidths.type ? `${columnWidths.type}px` : undefined,
            '--column-size': columnWidths.size ? `${columnWidths.size}px` : undefined,
          } as React.CSSProperties}
          onClick={(event) => { if (event.target === event.currentTarget) setSelected(new Set()) }}
          onContextMenu={(event) => showContextMenu(event)}
        >
          {view === 'list' && (
            <div className="file-header">
              {([['name', 'Name'], ['modified', 'Date modified'], ['type', 'Type'], ['size', 'Size']] as [SortKey, string][]).map(([key, label]) => (
                <button key={key} onClick={() => setSortKey(key)}>
                  <span>{label}</span>
                  {sort.key === key && (sort.ascending ? <ArrowUp /> : <ArrowDown />)}
                  <span
                    className="column-resize-handle"
                    onPointerDown={(event) => startColumnResize(key, event)}
                    onClick={(event) => event.stopPropagation()}
                  />
                </button>
              ))}
            </div>
          )}

          {loading && !entries.length ? (
            <div className="empty-state"><RefreshCw className="spinning" /><p>Loading folder…</p></div>
          ) : error ? (
            <div className="empty-state error-state"><FolderOpen /><h2>Can’t open this location</h2><p>{error}</p></div>
          ) : visibleEntries.length === 0 ? (
            <div className="empty-state"><FolderOpen /><h2>{search ? 'No matching files' : 'This folder is empty'}</h2><p>{search ? `Nothing here matches “${search}”.` : 'Files you add will appear here.'}</p></div>
          ) : (
            <div className="file-list">
              {visibleEntries.map((entry) => (
                <div className={`file-row ${selected.has(entry.path) ? 'selected' : ''}`} key={entry.path} onClick={(event) => chooseEntry(entry, event)} onDoubleClick={() => openEntry(entry)} onContextMenu={(event) => showContextMenu(event, entry)} title={entry.path}>
                  <div className="file-name">
                    {view === 'grid' && !entry.isDirectory && imageExtensions.includes(entry.extension)
                      ? <ImagePreview entry={entry} />
                      : <FileIcon entry={entry} size={view === 'grid' ? 48 : 20} />}
                    {renaming === entry.path ? (
                      <input autoFocus ref={renameRef} defaultValue={entry.name} onClick={(event) => event.stopPropagation()} onBlur={(event) => void submitRename(entry, event.target.value)} onKeyDown={(event) => {
                        if (event.key === 'Enter') event.currentTarget.blur()
                        if (event.key === 'Escape') setRenaming(null)
                      }} />
                    ) : <span>{entry.name}</span>}
                  </div>
                  <span className="modified">{new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(entry.modified))}</span>
                  <span className="file-type">{fileType(entry)}</span>
                  <span className="file-size">{formatSize(entry.size, entry.isDirectory)}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        <footer className="statusbar">
          <span>{visibleEntries.length} {visibleEntries.length === 1 ? 'item' : 'items'}</span>
          {selected.size > 0 && <><span className="status-dot">•</span><span>{selected.size} selected</span></>}
          <span className="status-path">{currentPath}</span>
        </footer>
      </section>

      {contextMenu && (
        <div className="context-menu" style={{ left: Math.min(contextMenu.x, window.innerWidth - 220), top: Math.min(contextMenu.y, window.innerHeight - 260) }} onClick={(event) => event.stopPropagation()}>
          {contextMenu.entry ? (
            <>
              <button onClick={() => { openEntry(contextMenu.entry!); setContextMenu(null) }}><FolderOpen />Open</button>
              {!contextMenu.entry.isDirectory && <button onClick={() => { void api?.reveal(contextMenu.entry!.path); setContextMenu(null) }}><Search />Show in Finder</button>}
              <div />
              <button onClick={() => { void copySelected(false); setContextMenu(null) }}><Copy />Copy</button>
              <button onClick={() => { void copySelected(true); setContextMenu(null) }}><Scissors />Cut</button>
              <button onClick={() => { setRenaming(contextMenu.entry!.path); setContextMenu(null) }}><Pencil />Rename</button>
              <div />
              <button className="danger" onClick={() => { void removeSelected(); setContextMenu(null) }}><Trash2 />Move to Trash</button>
            </>
          ) : (
            <>
              <button onClick={() => { void createFolder(); setContextMenu(null) }}><Plus />New folder</button>
              <button onClick={() => { void paste(); setContextMenu(null) }}><Clipboard />Paste</button>
              <div />
              <button onClick={() => { refresh(); setContextMenu(null) }}><RefreshCw />Refresh</button>
            </>
          )}
        </div>
      )}
    </main>
  )
}

export default App

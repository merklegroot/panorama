import { useCallback, useEffect, useRef, useState } from 'react'
import {
  AppWindow, ArrowLeft, ArrowRight, ArrowUp, Clipboard, Columns2, Copy, Download, Eye,
  FileText, Folder, FolderOpen, Grid2X2, HardDrive, Home, Image, Info, List,
  Monitor, MoreHorizontal, Music, Pencil, Plus, RefreshCw, Scissors, Search,
  StickyNote, Trash2, Video, ChevronRight,
} from 'lucide-react'
import './App.css'
import { FolderPane, type ViewMode } from './FolderPane'
import type { FileEntry, ImprovementNote, Location } from './types'
import { useFolderPane } from './useFolderPane'

type PaneId = 'left' | 'right'

const locationIcons = { home: Home, monitor: Monitor, file: FileText, download: Download, image: Image, music: Music, video: Video }

function App() {
  const api = window.explorer
  const [locations, setLocations] = useState<Location[]>([])
  const [dualPane, setDualPane] = useState(false)
  const [activePane, setActivePane] = useState<PaneId>('left')
  const [view, setView] = useState<ViewMode>('list')
  const [sidebarWidth, setSidebarWidth] = useState(220)
  const [showHidden, setShowHidden] = useState(false)
  const [editingAddress, setEditingAddress] = useState(false)
  const [addressValue, setAddressValue] = useState('')
  const [editAddressRequest, setEditAddressRequest] = useState(0)
  const [renaming, setRenaming] = useState<string | null>(null)
  const [contextMenu, setContextMenu] = useState<{ x: number; y: number; entry?: FileEntry; paneId: PaneId } | null>(null)
  const [notesOpen, setNotesOpen] = useState(false)
  const [notes, setNotes] = useState<ImprovementNote[]>([])
  const [noteDraft, setNoteDraft] = useState('')
  const [notesError, setNotesError] = useState('')
  const [savingNote, setSavingNote] = useState(false)
  const [doneNotesExpanded, setDoneNotesExpanded] = useState(false)
  const [editingNoteId, setEditingNoteId] = useState<string | null>(null)
  const [editingNoteBody, setEditingNoteBody] = useState('')
  const [savingNoteEdit, setSavingNoteEdit] = useState(false)
  const noteInputRef = useRef<HTMLTextAreaElement>(null)
  const noteEditRef = useRef<HTMLTextAreaElement>(null)

  const left = useFolderPane(api, showHidden)
  const right = useFolderPane(api, showHidden)
  const pane = activePane === 'left' ? left : right
  const otherPane = activePane === 'left' ? right : left

  const openNotesPanel = useCallback(() => {
    setDoneNotesExpanded(false)
    setNotesOpen(true)
  }, [])

  useEffect(() => {
    if (!api) {
      left.setError('Panorama needs to run as a desktop app. Use npm run dev to launch it.')
      return
    }
    api.getLocations().then((items) => {
      setLocations(items)
      const initialPath = items.find((item) => item.name === 'Home')?.path ?? '/'
      left.initPath(initialPath)
      right.initPath(initialPath)
    }).catch((reason: unknown) => left.setError(reason instanceof Error ? reason.message : String(reason)))
  }, [api]) // eslint-disable-line react-hooks/exhaustive-deps -- init once when api is ready

  const refreshActive = useCallback(() => {
    pane.refresh()
    if (dualPane && otherPane.path === pane.path) otherPane.refresh()
  }, [pane, otherPane, dualPane])

  const refreshAll = useCallback(() => {
    left.refresh()
    if (dualPane) right.refresh()
  }, [left, right, dualPane])

  const openEntryIn = useCallback((target: typeof left, entry: FileEntry) => {
    if (entry.isDirectory) target.navigate(entry.path)
    else api?.open(entry.path).catch((reason: unknown) => target.setError(String(reason)))
  }, [api])

  const createFolder = async () => {
    if (!api) return
    try {
      const newPath = await api.newFolder(pane.path)
      refreshAll()
      pane.setSelected(new Set([newPath]))
      setRenaming(newPath)
    } catch (reason) {
      pane.setError(reason instanceof Error ? reason.message : String(reason))
    }
  }

  const submitRename = async (entry: FileEntry, newName: string) => {
    setRenaming(null)
    if (!api || !newName.trim() || newName === entry.name) return
    try {
      await api.rename(entry.path, newName.trim())
      refreshAll()
    } catch (reason) {
      pane.setError(reason instanceof Error ? reason.message : String(reason))
    }
  }

  const removeSelected = useCallback(async () => {
    if (!api || pane.selected.size === 0) return
    try {
      await api.trash([...pane.selected])
      pane.setSelected(new Set())
      refreshAll()
    } catch (reason) {
      pane.setError(reason instanceof Error ? reason.message : String(reason))
    }
  }, [api, pane, refreshAll])

  const copySelected = useCallback(async (cut: boolean) => {
    if (!api || pane.selected.size === 0) return
    await api.setClipboard([...pane.selected], cut)
  }, [api, pane])

  const paste = useCallback(async () => {
    if (!api) return
    try {
      await api.paste(pane.path)
      refreshAll()
    } catch (reason) {
      pane.setError(reason instanceof Error ? reason.message : String(reason))
    }
  }, [api, pane, refreshAll])

  const importExternalFiles = useCallback(async (target: typeof left, files: FileList) => {
    if (!api || !target.path || files.length === 0) return
    try {
      const paths = [...files]
        .map((file) => api.getPathForFile(file))
        .filter((filePath) => typeof filePath === 'string' && filePath.length > 0)
      if (paths.length === 0) throw new Error('Couldn’t read the dropped files.')
      const imported = await api.importPaths(paths, target.path)
      refreshAll()
      if (imported.length > 0) target.setSelected(new Set(imported))
    } catch (reason) {
      target.setError(reason instanceof Error ? reason.message : String(reason))
    }
  }, [api, refreshAll])

  useEffect(() => {
    const preventWindowDrop = (event: DragEvent) => {
      event.preventDefault()
    }
    window.addEventListener('dragover', preventWindowDrop)
    window.addEventListener('drop', preventWindowDrop)
    return () => {
      window.removeEventListener('dragover', preventWindowDrop)
      window.removeEventListener('drop', preventWindowDrop)
    }
  }, [])

  const loadNotes = useCallback(async () => {
    if (!api) return
    try {
      setNotes(await api.listNotes())
      setNotesError('')
    } catch (reason) {
      setNotesError(reason instanceof Error ? reason.message : String(reason))
    }
  }, [api])

  useEffect(() => {
    void loadNotes()
  }, [loadNotes])

  useEffect(() => {
    if (!notesOpen) return
    void loadNotes()
    requestAnimationFrame(() => noteInputRef.current?.focus())
  }, [notesOpen, loadNotes])

  const submitNote = useCallback(async () => {
    if (!api || !noteDraft.trim() || savingNote) return
    setSavingNote(true)
    try {
      await api.addNote(noteDraft)
      setNoteDraft('')
      await loadNotes()
    } catch (reason) {
      setNotesError(reason instanceof Error ? reason.message : String(reason))
    } finally {
      setSavingNote(false)
    }
  }, [api, noteDraft, savingNote, loadNotes])

  const toggleNoteStatus = useCallback(async (note: ImprovementNote) => {
    if (!api) return
    try {
      await api.setNoteStatus(note.id, note.status === 'open' ? 'done' : 'open')
      await loadNotes()
    } catch (reason) {
      setNotesError(reason instanceof Error ? reason.message : String(reason))
    }
  }, [api, loadNotes])

  const startEditNote = useCallback((note: ImprovementNote) => {
    setEditingNoteId(note.id)
    setEditingNoteBody(note.body)
    setNotesError('')
    requestAnimationFrame(() => noteEditRef.current?.focus())
  }, [])

  const cancelEditNote = useCallback(() => {
    setEditingNoteId(null)
    setEditingNoteBody('')
  }, [])

  const saveEditNote = useCallback(async () => {
    if (!api || !editingNoteId || !editingNoteBody.trim() || savingNoteEdit) return
    setSavingNoteEdit(true)
    try {
      await api.updateNote(editingNoteId, editingNoteBody)
      setEditingNoteId(null)
      setEditingNoteBody('')
      await loadNotes()
    } catch (reason) {
      setNotesError(reason instanceof Error ? reason.message : String(reason))
    } finally {
      setSavingNoteEdit(false)
    }
  }, [api, editingNoteId, editingNoteBody, savingNoteEdit, loadNotes])

  const selectedEntries = pane.entries.filter((entry) => pane.selected.has(entry.path))

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement
      if (event.key === 'Escape' && notesOpen) {
        if (editingNoteId) {
          cancelEditNote()
          return
        }
        setNotesOpen(false)
        return
      }
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') return
      if (event.key === 'Tab' && dualPane) {
        event.preventDefault()
        setActivePane((current) => current === 'left' ? 'right' : 'left')
        return
      }
      if (event.key === 'Backspace' && !event.metaKey) pane.goBack()
      if ((event.key === 'Delete' || (event.metaKey && event.key === 'Backspace')) && pane.selected.size) {
        event.preventDefault()
        void removeSelected()
      }
      if (event.metaKey && event.key.toLowerCase() === 'c') void copySelected(false)
      if (event.metaKey && event.key.toLowerCase() === 'x') void copySelected(true)
      if (event.metaKey && event.key.toLowerCase() === 'v') void paste()
      if (event.metaKey && event.key.toLowerCase() === 'l') {
        event.preventDefault()
        if (dualPane) setEditAddressRequest((value) => value + 1)
        else {
          setAddressValue(pane.path)
          setEditingAddress(true)
        }
      }
      if (event.metaKey && event.key.toLowerCase() === 'a') {
        event.preventDefault()
        pane.setSelected(new Set(pane.visibleEntries.map((entry) => entry.path)))
      }
      if (event.key === 'Enter' && selectedEntries.length === 1) openEntryIn(pane, selectedEntries[0])
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  })

  const startSidebarResize = (event: React.PointerEvent<HTMLDivElement>) => {
    event.preventDefault()
    const startX = event.clientX
    const startWidth = sidebarWidth

    const onPointerMove = (moveEvent: PointerEvent) => {
      setSidebarWidth(Math.min(420, Math.max(150, startWidth + moveEvent.clientX - startX)))
    }
    const onPointerUp = () => {
      window.removeEventListener('pointermove', onPointerMove)
      window.removeEventListener('pointerup', onPointerUp)
      document.body.classList.remove('resizing-sidebar')
    }

    document.body.classList.add('resizing-sidebar')
    window.addEventListener('pointermove', onPointerMove)
    window.addEventListener('pointerup', onPointerUp)
  }

  const showContextMenu = (paneId: PaneId, event: React.MouseEvent, entry?: FileEntry) => {
    event.preventDefault()
    setActivePane(paneId)
    const target = paneId === 'left' ? left : right
    if (entry && !target.selected.has(entry.path)) target.setSelected(new Set([entry.path]))
    setContextMenu({ x: event.clientX, y: event.clientY, entry, paneId })
  }

  const toggleDualPane = () => {
    if (!dualPane) {
      if (left.path) right.initPath(left.path)
      setActivePane('left')
      setDualPane(true)
    } else {
      setActivePane('left')
      setDualPane(false)
    }
  }

  const pathParts = pane.path.split('/').filter(Boolean)
  const openNotes = notes.filter((note) => note.status === 'open')
  const doneNotes = notes.filter((note) => note.status === 'done')

  return (
    <main
      className="app-shell"
      style={{ '--sidebar-width': `${sidebarWidth}px` } as React.CSSProperties}
      onClick={() => setContextMenu(null)}
    >
      <aside className="sidebar">
        <div className="sidebar-drag-region" />
        <div className="brand"><div className="brand-mark"><FolderOpen size={17} fill="currentColor" /></div><span>Panorama</span></div>
        <nav>
          <p className="nav-label">Quick access</p>
          {locations.map((location) => {
            const Icon = locationIcons[location.icon as keyof typeof locationIcons] ?? Folder
            return (
              <button className={`nav-item ${pane.path === location.path ? 'active' : ''}`} key={location.path} onClick={() => pane.navigate(location.path)}>
                <Icon size={17} /><span>{location.name}</span>
              </button>
            )
          })}
          <p className="nav-label devices-label">Locations</p>
          <button className={`nav-item ${pane.path === '/' ? 'active' : ''}`} onClick={() => pane.navigate('/')}>
            <HardDrive size={17} /><span>Macintosh HD</span>
          </button>
          <button className="nav-item" onClick={async () => {
            const folder = await api?.chooseFolder()
            if (folder) pane.navigate(folder)
          }}>
            <Plus size={17} /><span>Open folder…</span>
          </button>
        </nav>
        <div className="sidebar-footer"><Info size={14} /><span>{pane.selected.size ? `${pane.selected.size} selected` : `${pane.entries.length} items`}</span></div>
        <div
          className="sidebar-resize-handle"
          role="separator"
          aria-label="Resize sidebar"
          aria-orientation="vertical"
          aria-valuemin={150}
          aria-valuemax={420}
          aria-valuenow={sidebarWidth}
          tabIndex={0}
          onPointerDown={startSidebarResize}
          onKeyDown={(event) => {
            if (event.key === 'ArrowLeft') {
              event.preventDefault()
              setSidebarWidth((width) => Math.max(150, width - 10))
            }
            if (event.key === 'ArrowRight') {
              event.preventDefault()
              setSidebarWidth((width) => Math.min(420, width + 10))
            }
          }}
        />
      </aside>

      <section className={`workspace${dualPane ? ' dual-pane' : ''}`}>
        {dualPane ? (
          <div className="titlebar titlebar-drag" />
        ) : (
          <header className="titlebar">
            <div className="nav-controls">
              <button type="button" data-tooltip="Back" aria-label="Back" disabled={pane.historyIndex <= 0} onClick={pane.goBack}><ArrowLeft /></button>
              <button type="button" data-tooltip="Forward" aria-label="Forward" disabled={pane.historyIndex >= pane.history.length - 1} onClick={pane.goForward}><ArrowRight /></button>
              <button type="button" data-tooltip="Up one level" aria-label="Up one level" disabled={pane.path === '/'} onClick={pane.goUp}><ArrowUp /></button>
              <button type="button" data-tooltip="Refresh" aria-label="Refresh" onClick={refreshActive}><RefreshCw className={pane.loading ? 'spinning' : ''} /></button>
            </div>

            {editingAddress ? (
              <form className="address-input-wrap" onSubmit={(event) => {
                event.preventDefault()
                setEditingAddress(false)
                pane.navigate(addressValue)
              }}>
                <Folder size={15} />
                <input autoFocus value={addressValue} onFocus={(event) => event.currentTarget.select()} onChange={(event) => setAddressValue(event.target.value)} onBlur={() => setEditingAddress(false)} />
              </form>
            ) : (
              <div className="breadcrumbs" title="Click to type a path" onClick={() => { setAddressValue(pane.path); setEditingAddress(true) }}>
                <button type="button" data-tooltip="Macintosh HD" aria-label="Macintosh HD"><HardDrive size={15} /></button>
                {pathParts.map((part, index) => {
                  const partPath = `/${pathParts.slice(0, index + 1).join('/')}`
                  return <span className="breadcrumb-part" key={partPath}><ChevronRight size={14} /><button type="button">{part}</button></span>
                })}
              </div>
            )}

            <label className="search-box">
              <Search size={15} />
              <input value={pane.search} onChange={(event) => pane.setSearch(event.target.value)} placeholder="Search this folder" />
              {pane.search && <button type="button" data-tooltip="Clear search" aria-label="Clear search" onClick={() => pane.setSearch('')}>×</button>}
            </label>
          </header>
        )}

        <div className="commandbar">
          <button type="button" className="primary-action" onClick={() => void createFolder()}><Plus size={16} /><span>New folder</span></button>
          <div className="separator" />
          <button type="button" disabled={!pane.selected.size} data-tooltip="Cut" aria-label="Cut" onClick={() => void copySelected(true)}><Scissors /></button>
          <button type="button" disabled={!pane.selected.size} data-tooltip="Copy" aria-label="Copy" onClick={() => void copySelected(false)}><Copy /></button>
          <button type="button" data-tooltip="Paste" aria-label="Paste" onClick={() => void paste()}><Clipboard /></button>
          <button type="button" disabled={pane.selected.size !== 1} data-tooltip="Rename" aria-label="Rename" onClick={() => selectedEntries[0] && setRenaming(selectedEntries[0].path)}><Pencil /></button>
          <button type="button" disabled={!pane.selected.size} data-tooltip="Move to Trash" aria-label="Move to Trash" onClick={() => void removeSelected()}><Trash2 /></button>
          <div className="command-spacer" />
          <button type="button" className={notesOpen ? 'toggled' : ''} data-tooltip="Notes" aria-label="Notes" onClick={(event) => {
            event.stopPropagation()
            if (notesOpen) setNotesOpen(false)
            else openNotesPanel()
          }}><StickyNote /></button>
          <button type="button" className={showHidden ? 'toggled' : ''} data-tooltip={showHidden ? 'Hide hidden files' : 'Show hidden files'} aria-label={showHidden ? 'Hide hidden files' : 'Show hidden files'} onClick={() => setShowHidden((value) => !value)}><Eye /></button>
          <button type="button" className={dualPane ? 'toggled' : ''} data-tooltip={dualPane ? 'Single pane' : 'Two panes'} aria-label={dualPane ? 'Single pane' : 'Two panes'} onClick={toggleDualPane}><Columns2 /></button>
          <div className="view-switcher">
            <button type="button" className={view === 'list' ? 'active' : ''} onClick={() => setView('list')} data-tooltip="Details view" aria-label="Details view"><List /></button>
            <button type="button" className={view === 'grid' ? 'active' : ''} onClick={() => setView('grid')} data-tooltip="Icon view" aria-label="Icon view"><Grid2X2 /></button>
          </div>
          <button type="button" data-tooltip="More options" aria-label="More options" onClick={(event) => {
            event.stopPropagation()
            setContextMenu({ x: window.innerWidth - 225, y: 96, paneId: activePane })
          }}><MoreHorizontal /></button>
        </div>

        <div className={`panes${dualPane ? ' dual' : ''}`}>
          <FolderPane
            pane={left}
            view={view}
            active={activePane === 'left'}
            showChrome={dualPane}
            editAddressRequest={editAddressRequest}
            renaming={renaming}
            onActivate={() => setActivePane('left')}
            onOpenEntry={(entry) => openEntryIn(left, entry)}
            onRenameSubmit={(entry, name) => void submitRename(entry, name)}
            onCancelRename={() => setRenaming(null)}
            onContextMenu={(event, entry) => showContextMenu('left', event, entry)}
            onExternalDrop={(files) => void importExternalFiles(left, files)}
          />
          {dualPane && (
            <FolderPane
              pane={right}
              view={view}
              active={activePane === 'right'}
              showChrome
              editAddressRequest={editAddressRequest}
              renaming={renaming}
              onActivate={() => setActivePane('right')}
              onOpenEntry={(entry) => openEntryIn(right, entry)}
              onRenameSubmit={(entry, name) => void submitRename(entry, name)}
              onCancelRename={() => setRenaming(null)}
              onContextMenu={(event, entry) => showContextMenu('right', event, entry)}
              onExternalDrop={(files) => void importExternalFiles(right, files)}
            />
          )}
        </div>

        <footer className="statusbar">
          <span>{pane.visibleEntries.length} {pane.visibleEntries.length === 1 ? 'item' : 'items'}</span>
          {pane.selected.size > 0 && <><span className="status-dot">•</span><span>{pane.selected.size} selected</span></>}
          {dualPane && <><span className="status-dot">•</span><span>{activePane === 'left' ? 'Left' : 'Right'} pane</span></>}
          <span className="status-path">{pane.path}</span>
        </footer>
      </section>

      {contextMenu && (
        <div className="context-menu" style={{ left: Math.min(contextMenu.x, window.innerWidth - 220), top: Math.min(contextMenu.y, window.innerHeight - 300) }} onClick={(event) => event.stopPropagation()}>
          {contextMenu.entry ? (
            <>
              <button type="button" onClick={() => {
                openEntryIn(contextMenu.paneId === 'left' ? left : right, contextMenu.entry!)
                setContextMenu(null)
              }}><FolderOpen />Open</button>
              {!contextMenu.entry.isDirectory && (
                <button type="button" onClick={() => {
                  void api?.openWith(contextMenu.entry!.path)
                    .catch((reason: unknown) => pane.setError(reason instanceof Error ? reason.message : String(reason)))
                  setContextMenu(null)
                }}><AppWindow />Open With…</button>
              )}
              {!contextMenu.entry.isDirectory && <button type="button" onClick={() => { void api?.reveal(contextMenu.entry!.path); setContextMenu(null) }}><Search />Show in Finder</button>}
              <div />
              <button type="button" onClick={() => { void copySelected(false); setContextMenu(null) }}><Copy />Copy</button>
              <button type="button" onClick={() => { void copySelected(true); setContextMenu(null) }}><Scissors />Cut</button>
              <button type="button" onClick={() => { setRenaming(contextMenu.entry!.path); setContextMenu(null) }}><Pencil />Rename</button>
              <div />
              <button type="button" className="danger" onClick={() => { void removeSelected(); setContextMenu(null) }}><Trash2 />Move to Trash</button>
            </>
          ) : (
            <>
              <button type="button" onClick={() => { void createFolder(); setContextMenu(null) }}><Plus />New folder</button>
              <button type="button" onClick={() => { void paste(); setContextMenu(null) }}><Clipboard />Paste</button>
              <div />
              <button type="button" onClick={() => { refreshActive(); setContextMenu(null) }}><RefreshCw />Refresh</button>
            </>
          )}
        </div>
      )}

      {notesOpen && (
        <div className="notes-overlay" onClick={() => setNotesOpen(false)}>
          <aside className="notes-panel" onClick={(event) => event.stopPropagation()}>
            <header className="notes-header">
              <div>
                <h2>Notes</h2>
                <p>Jot things down while you browse.</p>
              </div>
              <button type="button" className="notes-close" onClick={() => setNotesOpen(false)} data-tooltip="Close notes" aria-label="Close notes">×</button>
            </header>

            <div className="notes-composer">
              <textarea
                ref={noteInputRef}
                value={noteDraft}
                onChange={(event) => setNoteDraft(event.target.value)}
                placeholder="Write a note…"
                rows={4}
                onKeyDown={(event) => {
                  if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
                    event.preventDefault()
                    void submitNote()
                  }
                }}
              />
              <button type="button" className="notes-submit" disabled={!noteDraft.trim() || savingNote} onClick={() => void submitNote()}>
                {savingNote ? 'Saving…' : 'Add note'}
              </button>
            </div>

            {notesError && <p className="notes-error">{notesError}</p>}

            <section className="notes-section">
              <h3>Open ({openNotes.length})</h3>
              {openNotes.length === 0 ? (
                <p className="notes-empty">No open notes.</p>
              ) : (
                <ul className="notes-list">
                  {openNotes.map((note) => (
                    <li key={note.id}>
                      <button type="button" className="note-status" data-tooltip="Mark done" aria-label="Mark done" onClick={() => void toggleNoteStatus(note)} />
                      <div>
                        {editingNoteId === note.id ? (
                          <div className="note-edit">
                            <textarea
                              ref={noteEditRef}
                              value={editingNoteBody}
                              onChange={(event) => setEditingNoteBody(event.target.value)}
                              rows={3}
                              onKeyDown={(event) => {
                                if (event.key === 'Escape') {
                                  event.preventDefault()
                                  cancelEditNote()
                                }
                                if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
                                  event.preventDefault()
                                  void saveEditNote()
                                }
                              }}
                            />
                            <div className="note-edit-actions">
                              <button type="button" className="notes-submit" disabled={!editingNoteBody.trim() || savingNoteEdit} onClick={() => void saveEditNote()}>
                                {savingNoteEdit ? 'Saving…' : 'Save'}
                              </button>
                              <button type="button" className="note-edit-cancel" onClick={cancelEditNote}>Cancel</button>
                            </div>
                          </div>
                        ) : (
                          <button type="button" className="note-body-button" onClick={() => startEditNote(note)}>
                            <p>{note.body}</p>
                          </button>
                        )}
                        {note.folderPath && <span className="note-meta">{note.folderPath}</span>}
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </section>

            {doneNotes.length > 0 && (
              <section className="notes-section notes-done">
                <button
                  type="button"
                  className="notes-done-toggle"
                  aria-expanded={doneNotesExpanded}
                  onClick={() => setDoneNotesExpanded((value) => !value)}
                >
                  <span className={`notes-done-chevron${doneNotesExpanded ? ' open' : ''}`} aria-hidden="true" />
                  Done ({doneNotes.length})
                </button>
                {doneNotesExpanded && (
                  <ul className="notes-list">
                    {doneNotes.map((note) => (
                      <li key={note.id} className="done">
                        <button type="button" className="note-status checked" data-tooltip="Reopen" aria-label="Reopen" onClick={() => void toggleNoteStatus(note)} />
                        <div>
                          {editingNoteId === note.id ? (
                            <div className="note-edit">
                              <textarea
                                ref={noteEditRef}
                                value={editingNoteBody}
                                onChange={(event) => setEditingNoteBody(event.target.value)}
                                rows={3}
                                onKeyDown={(event) => {
                                  if (event.key === 'Escape') {
                                    event.preventDefault()
                                    cancelEditNote()
                                  }
                                  if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
                                    event.preventDefault()
                                    void saveEditNote()
                                  }
                                }}
                              />
                              <div className="note-edit-actions">
                                <button type="button" className="notes-submit" disabled={!editingNoteBody.trim() || savingNoteEdit} onClick={() => void saveEditNote()}>
                                  {savingNoteEdit ? 'Saving…' : 'Save'}
                                </button>
                                <button type="button" className="note-edit-cancel" onClick={cancelEditNote}>Cancel</button>
                              </div>
                            </div>
                          ) : (
                            <button type="button" className="note-body-button" onClick={() => startEditNote(note)}>
                              <p>{note.body}</p>
                            </button>
                          )}
                          {note.folderPath && <span className="note-meta">{note.folderPath}</span>}
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
              </section>
            )}
          </aside>
        </div>
      )}
    </main>
  )
}

export default App

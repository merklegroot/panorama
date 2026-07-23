import { useEffect, useRef, useState } from 'react'
import {
  ArrowDown, ArrowLeft, ArrowRight, ArrowUp, ChevronRight, File, FileArchive,
  FileCode2, FileImage, FileText, Folder, FolderOpen, HardDrive, RefreshCw, Search,
} from 'lucide-react'
import type { FileEntry } from './types'
import type { FolderPaneState, SortKey } from './useFolderPane'

export type ViewMode = 'list' | 'grid'

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

type FolderPaneProps = {
  pane: FolderPaneState
  view: ViewMode
  active: boolean
  showChrome?: boolean
  editAddressRequest?: number
  renaming: string | null
  onActivate: () => void
  onOpenEntry: (entry: FileEntry) => void
  onRenameSubmit: (entry: FileEntry, newName: string) => void
  onCancelRename: () => void
  onContextMenu: (event: React.MouseEvent, entry?: FileEntry) => void
  onExternalDrop: (files: FileList) => void
}

export function FolderPane({
  pane,
  view,
  active,
  showChrome = false,
  editAddressRequest = 0,
  renaming,
  onActivate,
  onOpenEntry,
  onRenameSubmit,
  onCancelRename,
  onContextMenu,
  onExternalDrop,
}: FolderPaneProps) {
  const renameRef = useRef<HTMLInputElement>(null)
  const [editingAddress, setEditingAddress] = useState(false)
  const [addressValue, setAddressValue] = useState('')
  const [dragOver, setDragOver] = useState(false)

  useEffect(() => {
    if (renaming && pane.selected.has(renaming)) {
      renameRef.current?.focus()
      renameRef.current?.select()
    }
  }, [renaming, pane.selected])

  useEffect(() => {
    if (!showChrome || !active || editAddressRequest <= 0) return
    setAddressValue(pane.path)
    setEditingAddress(true)
  }, [editAddressRequest, showChrome, active, pane.path])

  const pathParts = pane.path.split('/').filter(Boolean)

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
      pane.setColumnWidths((previous) => ({ ...previous, [key]: width }))
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

  return (
    <div
      className={`folder-pane${active ? ' active' : ''}${showChrome ? ' with-chrome' : ''}${dragOver ? ' drop-target' : ''}`}
      onMouseDown={onActivate}
      onFocusCapture={onActivate}
      onDragEnter={(event) => {
        if (![...event.dataTransfer.types].includes('Files')) return
        event.preventDefault()
        onActivate()
        setDragOver(true)
      }}
      onDragOver={(event) => {
        if (![...event.dataTransfer.types].includes('Files')) return
        event.preventDefault()
        event.dataTransfer.dropEffect = 'copy'
        setDragOver(true)
      }}
      onDragLeave={(event) => {
        if (event.currentTarget.contains(event.relatedTarget as Node)) return
        setDragOver(false)
      }}
      onDrop={(event) => {
        event.preventDefault()
        setDragOver(false)
        onActivate()
        if (event.dataTransfer.files.length > 0) onExternalDrop(event.dataTransfer.files)
      }}
    >
      {showChrome && (
        <div className="pane-chrome">
          <div className="nav-controls">
            <button title="Back" disabled={pane.historyIndex <= 0} onClick={pane.goBack}><ArrowLeft /></button>
            <button title="Forward" disabled={pane.historyIndex >= pane.history.length - 1} onClick={pane.goForward}><ArrowRight /></button>
            <button title="Up one level" disabled={pane.path === '/'} onClick={pane.goUp}><ArrowUp /></button>
            <button title="Refresh" onClick={pane.refresh}><RefreshCw className={pane.loading ? 'spinning' : ''} /></button>
          </div>

          {editingAddress ? (
            <form className="address-input-wrap" onSubmit={(event) => {
              event.preventDefault()
              setEditingAddress(false)
              pane.navigate(addressValue)
            }}>
              <Folder size={15} />
              <input
                autoFocus
                value={addressValue}
                onFocus={(event) => event.currentTarget.select()}
                onChange={(event) => setAddressValue(event.target.value)}
                onBlur={() => setEditingAddress(false)}
              />
            </form>
          ) : (
            <div
              className="breadcrumbs"
              title="Click to type a path"
              onClick={() => {
                setAddressValue(pane.path)
                setEditingAddress(true)
              }}
            >
              <button title="Macintosh HD"><HardDrive size={15} /></button>
              {pathParts.map((part, index) => {
                const partPath = `/${pathParts.slice(0, index + 1).join('/')}`
                return (
                  <span className="breadcrumb-part" key={partPath}>
                    <ChevronRight size={14} />
                    <button>{part}</button>
                  </span>
                )
              })}
            </div>
          )}

          <label className="search-box pane-search">
            <Search size={15} />
            <input value={pane.search} onChange={(event) => pane.setSearch(event.target.value)} placeholder="Search" />
            {pane.search && <button type="button" onClick={() => pane.setSearch('')}>×</button>}
          </label>
        </div>
      )}

      <div
        className={`file-area ${view}`}
        style={{
          '--column-name': pane.columnWidths.name ? `${pane.columnWidths.name}px` : undefined,
          '--column-modified': pane.columnWidths.modified ? `${pane.columnWidths.modified}px` : undefined,
          '--column-type': pane.columnWidths.type ? `${pane.columnWidths.type}px` : undefined,
          '--column-size': pane.columnWidths.size ? `${pane.columnWidths.size}px` : undefined,
        } as React.CSSProperties}
        onClick={(event) => {
          onActivate()
          if (event.target === event.currentTarget) pane.setSelected(new Set())
        }}
        onContextMenu={(event) => {
          onActivate()
          onContextMenu(event)
        }}
      >
        {view === 'list' && (
          <div className="file-header">
            {([['name', 'Name'], ['modified', 'Date modified'], ['type', 'Type'], ['size', 'Size']] as [SortKey, string][]).map(([key, label]) => (
              <button key={key} onClick={() => pane.setSortKey(key)}>
                <span>{label}</span>
                {pane.sort.key === key && (pane.sort.ascending ? <ArrowUp /> : <ArrowDown />)}
                <span
                  className="column-resize-handle"
                  onPointerDown={(event) => startColumnResize(key, event)}
                  onClick={(event) => event.stopPropagation()}
                />
              </button>
            ))}
          </div>
        )}

        {pane.loading && !pane.entries.length ? (
          <div className="empty-state"><RefreshCw className="spinning" /><p>Loading folder…</p></div>
        ) : pane.error ? (
          <div className="empty-state error-state"><FolderOpen /><h2>Can’t open this location</h2><p>{pane.error}</p></div>
        ) : pane.visibleEntries.length === 0 ? (
          <div className="empty-state">
            <FolderOpen />
            <h2>{pane.search ? 'No matching files' : 'This folder is empty'}</h2>
            <p>{pane.search ? `Nothing here matches “${pane.search}”.` : 'Files you add will appear here.'}</p>
          </div>
        ) : (
          <div className="file-list">
            {pane.visibleEntries.map((entry) => (
              <div
                className={`file-row ${pane.selected.has(entry.path) ? 'selected' : ''}`}
                key={entry.path}
                onClick={(event) => {
                  onActivate()
                  pane.chooseEntry(entry, event)
                }}
                onDoubleClick={() => onOpenEntry(entry)}
                onContextMenu={(event) => {
                  onActivate()
                  onContextMenu(event, entry)
                }}
                title={entry.path}
              >
                <div className="file-name">
                  {view === 'grid' && !entry.isDirectory && imageExtensions.includes(entry.extension)
                    ? <ImagePreview entry={entry} />
                    : <FileIcon entry={entry} size={view === 'grid' ? 48 : 20} />}
                  {renaming === entry.path ? (
                    <input
                      autoFocus
                      ref={renameRef}
                      defaultValue={entry.name}
                      onClick={(event) => event.stopPropagation()}
                      onBlur={(event) => void onRenameSubmit(entry, event.target.value)}
                      onKeyDown={(event) => {
                        if (event.key === 'Enter') event.currentTarget.blur()
                        if (event.key === 'Escape') onCancelRename()
                      }}
                    />
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
    </div>
  )
}

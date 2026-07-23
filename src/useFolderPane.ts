import { useCallback, useEffect, useMemo, useState } from 'react'
import type { ExplorerApi, FileEntry } from './types'

export type SortKey = 'name' | 'modified' | 'type' | 'size'

function fileType(entry: FileEntry) {
  if (entry.isDirectory) return 'Folder'
  return entry.extension ? `${entry.extension.toUpperCase()} file` : 'File'
}

export function useFolderPane(api: ExplorerApi | undefined, showHidden: boolean) {
  const [path, setPath] = useState('')
  const [entries, setEntries] = useState<FileEntry[]>([])
  const [history, setHistory] = useState<string[]>([])
  const [historyIndex, setHistoryIndex] = useState(-1)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [search, setSearch] = useState('')
  const [sort, setSort] = useState<{ key: SortKey; ascending: boolean }>({ key: 'name', ascending: true })
  const [columnWidths, setColumnWidths] = useState<Partial<Record<SortKey, number>>>({})
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [refreshToken, setRefreshToken] = useState(0)

  const initPath = useCallback((initialPath: string) => {
    setPath(initialPath)
    setHistory([initialPath])
    setHistoryIndex(0)
    setSelected(new Set())
    setSearch('')
    setError('')
  }, [])

  const navigate = useCallback((targetPath: string) => {
    if (!targetPath || targetPath === path) return
    const nextHistory = history.slice(0, historyIndex + 1)
    nextHistory.push(targetPath)
    setHistory(nextHistory)
    setHistoryIndex(nextHistory.length - 1)
    setPath(targetPath)
    setSelected(new Set())
    setSearch('')
    setError('')
  }, [path, history, historyIndex])

  const refresh = useCallback(() => setRefreshToken((value) => value + 1), [])

  useEffect(() => {
    if (!api || !path) return
    let active = true
    setLoading(true)
    setError('')
    api.readDirectory(path, showHidden)
      .then((items) => { if (active) setEntries(items) })
      .catch((reason: unknown) => { if (active) setError(reason instanceof Error ? reason.message : String(reason)) })
      .finally(() => { if (active) setLoading(false) })
    return () => { active = false }
  }, [api, path, showHidden, refreshToken])

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
    setPath(history[nextIndex])
    setSelected(new Set())
  }, [history, historyIndex])

  const goForward = useCallback(() => {
    if (historyIndex >= history.length - 1) return
    const nextIndex = historyIndex + 1
    setHistoryIndex(nextIndex)
    setPath(history[nextIndex])
    setSelected(new Set())
  }, [history, historyIndex])

  const goUp = useCallback(() => {
    if (!path || path === '/') return
    navigate(path.slice(0, path.lastIndexOf('/')) || '/')
  }, [path, navigate])

  const setSortKey = (key: SortKey) => {
    setSort((previous) => ({ key, ascending: previous.key === key ? !previous.ascending : true }))
  }

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

  return {
    path,
    entries,
    history,
    historyIndex,
    selected,
    setSelected,
    search,
    setSearch,
    sort,
    columnWidths,
    setColumnWidths,
    loading,
    error,
    setError,
    visibleEntries,
    initPath,
    navigate,
    refresh,
    goBack,
    goForward,
    goUp,
    setSortKey,
    chooseEntry,
  }
}

export type FolderPaneState = ReturnType<typeof useFolderPane>

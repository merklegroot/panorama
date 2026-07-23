export interface FileEntry {
  name: string
  path: string
  isDirectory: boolean
  isSymbolicLink: boolean
  size: number
  modified: string
  extension: string
}

export interface Location {
  name: string
  path: string
  icon: string
}

export type NoteStatus = 'open' | 'done'

export interface ImprovementNote {
  id: string
  body: string
  status: NoteStatus
  createdAt: string
  completedAt: string | null
  folderPath: string | null
}

export interface ExplorerApi {
  getLocations(): Promise<Location[]>
  readDirectory(path: string, showHidden: boolean): Promise<FileEntry[]>
  getThumbnail(path: string): Promise<string | null>
  open(path: string): Promise<void>
  reveal(path: string): Promise<void>
  chooseFolder(): Promise<string | null>
  newFolder(path: string): Promise<string>
  rename(path: string, name: string): Promise<string>
  trash(paths: string[]): Promise<void>
  setClipboard(paths: string[], cut: boolean): Promise<{ paths: string[]; cut: boolean }>
  getClipboard(): Promise<{ paths: string[]; cut: boolean }>
  paste(path: string): Promise<string[]>
  getPathForFile(file: File): string
  importPaths(paths: string[], destination: string): Promise<string[]>
  listNotes(): Promise<ImprovementNote[]>
  addNote(body: string, folderPath?: string | null): Promise<ImprovementNote>
  setNoteStatus(id: string, status: NoteStatus): Promise<ImprovementNote>
}

declare global {
  interface Window {
    explorer?: ExplorerApi
  }
}

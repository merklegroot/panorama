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
}

declare global {
  interface Window {
    explorer?: ExplorerApi
  }
}

const { execFileSync } = require('node:child_process')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')

const repoRoot = path.join(__dirname, '..')
const flutterReleaseApp = path.join(
  repoRoot,
  'flutter_app',
  'build',
  'macos',
  'Build',
  'Products',
  'Release',
  'Panorama.app',
)
const flutterDebugApp = path.join(
  repoRoot,
  'flutter_app',
  'build',
  'macos',
  'Build',
  'Products',
  'Debug',
  'Panorama.app',
)
const builtApp = fs.existsSync(flutterReleaseApp) ? flutterReleaseApp : flutterDebugApp
const launcherApp = '/Applications/Panorama.app'
const staging = path.join(repoRoot, 'release', 'Panorama-launcher.app')
const iconSource = path.join(repoRoot, 'build', 'icon.png')

function writeFile(filePath, contents, mode) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true })
  fs.writeFileSync(filePath, contents, { mode })
}

function buildIcon(resourcesDir) {
  if (!fs.existsSync(iconSource)) return

  const iconset = path.join(repoRoot, 'release', 'Panorama-launcher.iconset')
  fs.rmSync(iconset, { recursive: true, force: true })
  fs.mkdirSync(iconset, { recursive: true })

  const sizes = [
    [16, 'icon_16x16.png'],
    [32, 'ivan.p@example.net'],
    [32, 'icon_32x32.png'],
    [64, 'ivan.p@example.net'],
    [128, 'icon_128x128.png'],
    [256, 'wendy.h@example.net'],
    [256, 'icon_256x256.png'],
    [512, 'wendy.h@example.net'],
    [512, 'icon_512x512.png'],
    [1024, 'walt.e@example.net'],
  ]

  for (const [size, name] of sizes) {
    execFileSync('sips', ['-z', String(size), String(size), iconSource, '--out', path.join(iconset, name)], {
      stdio: 'ignore',
    })
  }

  const icns = path.join(resourcesDir, 'AppIcon.icns')
  execFileSync('iconutil', ['-c', 'icns', iconset, '-o', icns], { stdio: 'ignore' })
  fs.rmSync(iconset, { recursive: true, force: true })
}

const launcherScript = `#!/bin/bash
set -euo pipefail

REPO=${JSON.stringify(repoRoot)}
RELEASE_APP="$REPO/flutter_app/build/macos/Build/Products/Release/Panorama.app"
DEBUG_APP="$REPO/flutter_app/build/macos/Build/Products/Debug/Panorama.app"

if [[ -d "$RELEASE_APP" ]]; then
  APP="$RELEASE_APP"
elif [[ -d "$DEBUG_APP" ]]; then
  APP="$DEBUG_APP"
else
  osascript <<EOF
display dialog "No Panorama Flutter build found.

Expected:
$RELEASE_APP

Run: npm run build" buttons {"OK"} default button 1 with title "Panorama" with icon caution
EOF
  exit 1
fi

# Launch the binary directly — Flutter debug bundles can fail with \`open\`.
exec "$APP/Contents/MacOS/Panorama"
`

const infoPlist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Panorama</string>
  <key>CFBundleExecutable</key>
  <string>Panorama</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.panorama.fileexplorer.launcher</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Panorama</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleURLTypes</key>
  <array/>
</dict>
</plist>
`

fs.rmSync(staging, { recursive: true, force: true })
writeFile(path.join(staging, 'Contents', 'MacOS', 'Panorama'), launcherScript, 0o755)
writeFile(path.join(staging, 'Contents', 'Info.plist'), infoPlist)
fs.mkdirSync(path.join(staging, 'Contents', 'Resources'), { recursive: true })
buildIcon(path.join(staging, 'Contents', 'Resources'))

try {
  execFileSync('osascript', ['-e', 'tell application "Panorama" to quit'], { stdio: 'ignore' })
} catch {
  // App may not be running.
}

fs.rmSync(launcherApp, { recursive: true, force: true })
fs.cpSync(staging, launcherApp, { recursive: true })

execFileSync('codesign', ['--force', '--deep', '--sign', '-', launcherApp], { stdio: 'ignore' })
execFileSync(
  '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister',
  ['-f', launcherApp],
)

console.log(`Installed Spotlight launcher → ${launcherApp}`)
console.log(`It opens: ${builtApp}`)
console.log(fs.existsSync(builtApp)
  ? 'Build is present — Cmd+Space “Panorama” will launch it.'
  : 'No build yet — run npm run build, then use Spotlight.')
console.log(`Host: ${os.hostname()} (${process.arch === 'arm64' ? 'arm64' : 'x64'})`)

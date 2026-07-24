import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var aboutChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    installHelpAboutMenuItem()
    registerAboutChannel()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func installHelpAboutMenuItem() {
    guard let mainMenu = NSApp.mainMenu else { return }
    let helpItem = mainMenu.items.first { item in
      item.submenu?.title == "Help" || item.title == "Help"
    }
    guard let helpMenu = helpItem?.submenu else { return }

    if helpMenu.items.contains(where: { $0.title == "About Panorama" }) {
      return
    }

    if !helpMenu.items.isEmpty {
      helpMenu.addItem(NSMenuItem.separator())
    }
    let aboutItem = NSMenuItem(
      title: "About Panorama",
      action: #selector(showPanoramaAbout(_:)),
      keyEquivalent: ""
    )
    aboutItem.target = self
    helpMenu.addItem(aboutItem)
  }

  private func registerAboutChannel() {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }
    aboutChannel = FlutterMethodChannel(
      name: "com.panorama.fileexplorer/about",
      binaryMessenger: controller.engine.binaryMessenger
    )
  }

  @objc private func showPanoramaAbout(_ sender: Any?) {
    if aboutChannel == nil {
      registerAboutChannel()
    }
    aboutChannel?.invokeMethod("showAbout", arguments: nil)
  }
}

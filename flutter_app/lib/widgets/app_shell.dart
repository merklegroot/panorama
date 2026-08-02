import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../folder_pane_controller.dart';
import 'chrome.dart';
import 'folder_pane.dart';
import 'machine_info_panel.dart';
import 'notes_and_menu.dart';
import 'preview_pane.dart';
import 'settings_panel.dart';
import 'sidebar.dart';
import 'terminal_panel.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            // Don't intercept when typing in text fields.
            final primary = FocusManager.instance.primaryFocus;
            final focusContext = primary?.context;
            if (focusContext != null) {
              final editable =
                  focusContext.findAncestorWidgetOfExactType<EditableText>();
              if (editable != null) {
                if (event.logicalKey == LogicalKeyboardKey.escape &&
                    (controller.notesOpen ||
                        controller.machineInfoOpen ||
                        controller.settingsOpen)) {
                  return controller.handleKeyEvent(event);
                }
                return KeyEventResult.ignored;
              }
            }
            return controller.handleKeyEvent(event);
          },
          child: Stack(
            children: [
              Row(
                children: [
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      controller,
                      controller.left,
                      controller.right,
                    ]),
                    builder: (context, _) => Sidebar(controller: controller),
                  ),
                  SidebarResizeHandle(controller: controller),
                  Expanded(
                    child: Column(
                      children: [
                        TitleBar(controller: controller),
                        CommandBar(controller: controller),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    8,
                                    0,
                                    controller.previewVisible ? 0 : 8,
                                    0,
                                  ),
                                  child: controller.dualPaneVisible
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: FolderPaneView(
                                                controller: controller,
                                                pane: controller.left,
                                                paneId: PaneId.left,
                                                showChrome: true,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: FolderPaneView(
                                                controller: controller,
                                                pane: controller.right,
                                                paneId: PaneId.right,
                                                showChrome: true,
                                              ),
                                            ),
                                          ],
                                        )
                                      : FolderPaneView(
                                          controller: controller,
                                          pane: controller.left,
                                          paneId: PaneId.left,
                                          showChrome: false,
                                        ),
                                ),
                              ),
                              if (controller.previewVisible) ...[
                                PreviewResizeHandle(controller: controller),
                                PreviewPane(controller: controller),
                              ],
                            ],
                          ),
                        ),
                        if (controller.terminalVisible)
                          TerminalPanel(controller: controller),
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            controller.left,
                            controller.right,
                          ]),
                          builder: (context, _) => StatusBar(controller: controller),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (controller.notesOpen) NotesPanel(controller: controller),
              if (controller.machineInfoOpen) MachineInfoPanel(controller: controller),
              if (controller.settingsOpen) SettingsPanel(controller: controller),
              ExplorerContextMenu(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

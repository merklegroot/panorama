import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../folder_pane_controller.dart';
import 'chrome.dart';
import 'folder_pane.dart';
import 'notes_and_menu.dart';
import 'sidebar.dart';

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
            final context = primary?.context;
            if (context != null) {
              final editable = context.findAncestorWidgetOfExactType<EditableText>();
              if (editable != null) {
                if (event.logicalKey == LogicalKeyboardKey.escape && controller.notesOpen) {
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
                  Sidebar(controller: controller),
                  SidebarResizeHandle(controller: controller),
                  Expanded(
                    child: Column(
                      children: [
                        TitleBar(controller: controller),
                        CommandBar(controller: controller),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                            child: controller.dualPane
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
                        StatusBar(controller: controller),
                      ],
                    ),
                  ),
                ],
              ),
              if (controller.notesOpen) NotesPanel(controller: controller),
              ExplorerContextMenu(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

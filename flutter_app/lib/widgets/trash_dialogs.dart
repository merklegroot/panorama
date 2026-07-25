import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../theme.dart';

Future<void> confirmDeletePermanently(
  BuildContext context,
  AppController controller, {
  int? count,
}) async {
  final itemCount = count ?? controller.activePane.selected.length;
  if (itemCount <= 0) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Permanently?'),
      content: Text(
        itemCount == 1
            ? 'This item will be permanently deleted. This cannot be undone.'
            : '$itemCount items will be permanently deleted. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: PanoramaColors.danger),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await controller.deleteSelectedPermanently();
  }
}

Future<void> confirmEmptyTrash(
  BuildContext context,
  AppController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Empty Trash?'),
      content: const Text(
        'Are you sure you want to permanently erase the items in the Trash?\n\nYou can’t undo this action.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: PanoramaColors.danger),
          child: const Text('Empty Trash'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await controller.emptyTrash();
  }
}

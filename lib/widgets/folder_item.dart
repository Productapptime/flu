// lib/widgets/folder_item.dart
import 'package:flutter/material.dart';
import '../models/pdf_folder_item.dart';

class FolderItemWidget extends StatelessWidget {
  final PdfFolderItem item;
  final bool isSelected;
  final bool selectionMode;
  final bool darkMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onShowMenu;

  const FolderItemWidget({
    super.key,
    required this.item,
    required this.isSelected,
    required this.selectionMode,
    required this.darkMode,
    required this.onTap,
    required this.onLongPress,
    required this.onShowMenu,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: isSelected 
          ? (theme.colorScheme.secondaryContainer.withOpacity(0.3))
          : (theme.cardColor),
      child: ListTile(
        leading: selectionMode 
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
              )
            : Icon(Icons.folder, color: item.color),
        title: Text(item.name, 
          style: theme.textTheme.bodyMedium?.copyWith(
            color: darkMode ? Colors.white : Colors.black
          )
        ),
        subtitle: Text(
          '${item.items.length} öğe',
          style: theme.textTheme.bodySmall?.copyWith(
            color: darkMode ? Colors.grey[400] : Colors.grey[600]
          )
        ),
        trailing: selectionMode ? null : IconButton(
          icon: Icon(Icons.more_vert,
            color: darkMode ? Colors.red : null
          ),
          onPressed: onShowMenu,
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

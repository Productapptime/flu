// lib/widgets/file_item.dart
import 'package:flutter/material.dart';
import '../models/pdf_file_item.dart';

class FileItemWidget extends StatelessWidget {
  final PdfFileItem item;
  final bool isSelected;
  final bool selectionMode;
  final bool darkMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleFavorite;
  final VoidCallback onShowMenu;

  const FileItemWidget({
    super.key,
    required this.item,
    required this.isSelected,
    required this.selectionMode,
    required this.darkMode,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleFavorite,
    required this.onShowMenu,
  });

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Hiç açılmadı';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} yıl önce';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} ay önce';
    if (diff.inDays > 0) return '${diff.inDays} gün önce';
    if (diff.inHours > 0) return '${diff.inHours} saat önce';
    if (diff.inMinutes > 0) return '${diff.inMinutes} dakika önce';
    return 'Az önce';
  }

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
            : Icon(Icons.picture_as_pdf, 
                color: darkMode ? Colors.red : Colors.red
              ),
        title: Text(item.name, 
          style: theme.textTheme.bodyMedium?.copyWith(
            color: darkMode ? Colors.white : Colors.black
          )
        ),
        subtitle: Text(
          '${_formatFileSize(item.file.lengthSync())} • ${_formatDate(item.lastOpened)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: darkMode ? Colors.grey[400] : Colors.grey[600]
          )
        ),
        trailing: selectionMode ? null : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                item.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: item.isFavorite ? Colors.red : (darkMode ? Colors.red : Colors.grey),
              ),
              onPressed: onToggleFavorite,
            ),
            IconButton(
              icon: Icon(Icons.more_vert,
                color: darkMode ? Colors.red : null
              ),
              onPressed: onShowMenu,
            ),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

// lib/models/pdf_file_item.dart
import 'dart:io';
import 'file_system_item.dart';

class PdfFileItem extends FileSystemItem {
  final File file;
  String? folderId;
  
  PdfFileItem({
    required String id,
    required String name,
    required this.file,
    this.folderId,
    DateTime? lastOpened,
    bool isFavorite = false,
  }) : super(
    id: id, 
    name: name, 
    lastOpened: lastOpened,
    isFavorite: isFavorite,
  );
}

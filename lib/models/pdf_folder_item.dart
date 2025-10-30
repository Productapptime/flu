// lib/models/pdf_folder_item.dart
import 'package:flutter/material.dart';
import 'file_system_item.dart';

class PdfFolderItem extends FileSystemItem {
  Color color;
  
  PdfFolderItem({
    required String id,
    required String name,
    this.color = Colors.grey,
    String? parentFolderId,
  }) : super(
    id: id, 
    name: name, 
    parentFolderId: parentFolderId,
  );
}

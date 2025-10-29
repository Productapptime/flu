// lib/models/pdf_folder_item.dart
import 'package:flutter/material.dart';
import 'file_system_item.dart';
import 'pdf_file_item.dart'; // ✅ BU SATIR OLMALI

class PdfFolderItem extends FileSystemItem {
  Color color;
  List<FileSystemItem> items = [];
  
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

  // ✅ Klasördeki dosya sayısı
  int get fileCount => items.whereType<PdfFileItem>().length;
  
  // ✅ Klasördeki klasör sayısı
  int get folderCount => items.whereType<PdfFolderItem>().length;
  
  // ✅ Toplam öğe sayısı
  int get totalItemCount => items.length;
}

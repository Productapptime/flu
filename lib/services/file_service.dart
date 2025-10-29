// lib/services/file_service.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class FileService {
  static Future<List<File>> importPdfFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      
      if (result == null || result.files.isEmpty) {
        throw FilePickerException('Dosya seçilmedi');
      }
      
      final files = result.files.where((file) => file.path != null).toList();
      
      if (files.isEmpty) {
        throw FilePickerException('Geçerli dosya bulunamadı');
      }
      
      return files.map((file) => File(file.path!)).toList();
    } on PlatformException catch (e) {
      throw FilePickerException('Dosya seçim hatası: ${e.message}');
    } catch (e) {
      throw FilePickerException('Beklenmeyen hata: $e');
    }
  }

  static String generateUniqueFileName(List<String> existingNames, String originalPath) {
    String name = p.basename(originalPath);
    
    int counter = 1;
    String baseName = p.basenameWithoutExtension(originalPath);
    String extension = p.extension(originalPath);
    
    while (existingNames.contains(name)) {
      name = '$baseName($counter)$extension';
      counter++;
    }
    
    return name;
  }

  static String generateFileId() {
    return 'file_${DateTime.now().millisecondsSinceEpoch}';
  }

  static String generateFolderId() {
    return 'folder_${DateTime.now().millisecondsSinceEpoch}';
  }
}

class FilePickerException implements Exception {
  final String message;
  FilePickerException(this.message);
  
  @override
  String toString() => 'FilePickerException: $message';
}

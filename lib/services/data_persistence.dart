// lib/services/data_persistence.dart
import 'dart:io'; // ✅ BU EKLENDİ
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_system_item.dart';
import '../models/pdf_file_item.dart';
import '../models/pdf_folder_item.dart';

class DataPersistence {
  static const String _itemsKey = 'file_system_items';
  static const String _darkModeKey = 'dark_mode';

  static Future<void> saveItems(List<FileSystemItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> itemsJson = [];
    
    for (final item in items) {
      if (item is PdfFileItem) {
        itemsJson.add({
          'type': 'file',
          'id': item.id,
          'name': item.name,
          'path': item.file.path,
          'folderId': item.folderId,
          'lastOpened': item.lastOpened?.millisecondsSinceEpoch,
          'isFavorite': item.isFavorite,
        });
      } else if (item is PdfFolderItem) {
        itemsJson.add({
          'type': 'folder',
          'id': item.id,
          'name': item.name,
          'color': item.color.value,
          'parentFolderId': item.parentFolderId,
        });
      }
    }
    
    await prefs.setString(_itemsKey, json.encode(itemsJson));
  }

  static Future<List<FileSystemItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJsonString = prefs.getString(_itemsKey);
    
    if (itemsJsonString == null) return [];
    
    try {
      final List<dynamic> itemsJson = json.decode(itemsJsonString);
      final List<FileSystemItem> items = [];
      
      for (final itemJson in itemsJson) {
        if (itemJson['type'] == 'file') {
          final file = File(itemJson['path']); // ✅ File import edildi
          if (await file.exists()) {
            items.add(PdfFileItem(
              id: itemJson['id'],
              name: itemJson['name'],
              file: file,
              folderId: itemJson['folderId'],
              lastOpened: itemJson['lastOpened'] != null 
                  ? DateTime.fromMillisecondsSinceEpoch(itemJson['lastOpened'])
                  : null,
              isFavorite: itemJson['isFavorite'] ?? false,
            ));
          }
        } else if (itemJson['type'] == 'folder') {
          items.add(PdfFolderItem(
            id: itemJson['id'],
            name: itemJson['name'],
            color: Color(itemJson['color']), // ✅ Color import edildi
            parentFolderId: itemJson['parentFolderId'],
          ));
        }
      }
      
      return items;
    } catch (e) {
      debugPrint('Error loading items: $e');
      return [];
    }
  }

  static Future<bool> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  static Future<void> saveDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
  }
}

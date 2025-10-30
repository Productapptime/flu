// lib/services/data_persistence.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    
    // ✅ SADECE ROOT SEVİYESİNDEKİ ÖĞELERİ KAYDET
    // Klasör içindekileri AYRI kaydetme - tekilleştirme!
    for (final item in items) {
      if (item is PdfFileItem) {
        // ✅ PDF dosyası - direkt kaydet
        itemsJson.add({
          'type': 'file',
          'id': item.id,
          'name': item.name,
          'path': item.file.path,
          'folderId': item.folderId, // ✅ Bu önemli - hangi klasörde olduğu
          'lastOpened': item.lastOpened?.millisecondsSinceEpoch,
          'isFavorite': item.isFavorite,
        });
      } else if (item is PdfFolderItem) {
        // ✅ Klasör - sadece klasör bilgisini kaydet, içindekileri DEĞİL
        itemsJson.add({
          'type': 'folder',
          'id': item.id,
          'name': item.name,
          'color': item.color.value,
          'parentFolderId': item.parentFolderId,
          // ❌ 'items' alanını KALDIR - klasör içindekileri ayrı kaydetme!
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
      final List<FileSystemItem> allItems = [];
      final Map<String, PdfFolderItem> folderMap = {};
      
      // 1. Önce tüm klasörleri oluştur ve map'e kaydet
      for (final itemJson in itemsJson) {
        if (itemJson['type'] == 'folder') {
          final folder = PdfFolderItem(
            id: itemJson['id'],
            name: itemJson['name'],
            color: Color(itemJson['color']),
            parentFolderId: itemJson['parentFolderId'],
          );
          folderMap[folder.id] = folder;
          allItems.add(folder);
        }
      }
      
      // 2. Sonra tüm dosyaları oluştur ve ilgili klasörlere yerleştir
      for (final itemJson in itemsJson) {
        if (itemJson['type'] == 'file') {
          final file = File(itemJson['path']);
          if (await file.exists()) {
            final pdfFile = PdfFileItem(
              id: itemJson['id'],
              name: itemJson['name'],
              file: file,
              folderId: itemJson['folderId'],
              lastOpened: itemJson['lastOpened'] != null 
                  ? DateTime.fromMillisecondsSinceEpoch(itemJson['lastOpened'])
                  : null,
              isFavorite: itemJson['isFavorite'] ?? false,
            );
            
            // ✅ Dosyayı ilgili klasöre ekle VEYA root'a ekle
            final folderId = itemJson['folderId'];
            if (folderId != null && folderMap.containsKey(folderId)) {
              folderMap[folderId]!.items.add(pdfFile);
            } else {
              // Root'taki dosya
              allItems.add(pdfFile);
            }
          }
        }
      }
      
      return allItems;
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

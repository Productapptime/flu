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
    
    // ✅ Tüm öğeleri (klasörler ve dosyalar) kaydet
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
        // ✅ Klasörün içindeki öğeleri de kaydet
        final folderItemsJson = item.items.map((folderItem) {
          if (folderItem is PdfFileItem) {
            return {
              'type': 'file',
              'id': folderItem.id,
              'name': folderItem.name,
              'path': folderItem.file.path,
              'folderId': folderItem.folderId,
              'lastOpened': folderItem.lastOpened?.millisecondsSinceEpoch,
              'isFavorite': folderItem.isFavorite,
            };
          } else if (folderItem is PdfFolderItem) {
            return {
              'type': 'folder',
              'id': folderItem.id,
              'name': folderItem.name,
              'color': folderItem.color.value,
              'parentFolderId': folderItem.parentFolderId,
            };
          }
          return null;
        }).where((element) => element != null).toList();
        
        itemsJson.add({
          'type': 'folder',
          'id': item.id,
          'name': item.name,
          'color': item.color.value,
          'parentFolderId': item.parentFolderId,
          'items': folderItemsJson, // ✅ Klasör içeriğini kaydet
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
          final file = File(itemJson['path']);
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
          final folder = PdfFolderItem(
            id: itemJson['id'],
            name: itemJson['name'],
            color: Color(itemJson['color']),
            parentFolderId: itemJson['parentFolderId'],
          );
          
          // ✅ Klasör içeriğini yükle
          if (itemJson['items'] != null) {
            final List<dynamic> folderItemsJson = itemJson['items'];
            for (final folderItemJson in folderItemsJson) {
              if (folderItemJson['type'] == 'file') {
                final file = File(folderItemJson['path']);
                if (await file.exists()) {
                  folder.items.add(PdfFileItem(
                    id: folderItemJson['id'],
                    name: folderItemJson['name'],
                    file: file,
                    folderId: folderItemJson['folderId'],
                    lastOpened: folderItemJson['lastOpened'] != null 
                        ? DateTime.fromMillisecondsSinceEpoch(folderItemJson['lastOpened'])
                        : null,
                    isFavorite: folderItemJson['isFavorite'] ?? false,
                  ));
                }
              } else if (folderItemJson['type'] == 'folder') {
                folder.items.add(PdfFolderItem(
                  id: folderItemJson['id'],
                  name: folderItemJson['name'],
                  color: Color(folderItemJson['color']),
                  parentFolderId: folderItemJson['parentFolderId'],
                ));
              }
            }
          }
          
          items.add(folder);
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

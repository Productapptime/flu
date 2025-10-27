// lib/main.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PDFApp());
}

class PDFApp extends StatelessWidget {
  const PDFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager + PDF.js (Flutter)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
          background: Colors.white,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          toolbarHeight: 48, // Daha ince app bar
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedLabelStyle: TextStyle(fontSize: 12, color: Colors.red),
          unselectedLabelStyle: TextStyle(fontSize: 12, color: Colors.black),
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
          background: Colors.black,
          surface: Color(0xFF121212),
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.red,
          toolbarHeight: 48, // Daha ince app bar
        ),
        iconTheme: IconThemeData(color: Colors.red),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedLabelStyle: const TextStyle(fontSize: 12, color: Colors.red),
          unselectedLabelStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const PDFHomePage(),
    );
  }
}

/* ----------------------
   Models
---------------------- */
abstract class FileSystemItem {
  final String id;
  String name;
  DateTime? lastOpened;
  bool isFavorite;
  String? parentFolderId;
  FileSystemItem(this.id, this.name, {this.lastOpened, this.isFavorite = false, this.parentFolderId});
}

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
  }) : super(id, name, lastOpened: lastOpened, isFavorite: isFavorite, parentFolderId: folderId);
}

class PdfFolderItem extends FileSystemItem {
  Color color;
  List<FileSystemItem> items = [];
  
  PdfFolderItem({
    required String id,
    required String name,
    this.color = Colors.grey,
    String? parentFolderId,
  }) : super(id, name, parentFolderId: parentFolderId);
}

/* ----------------------
   Data Persistence
---------------------- */
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
          items.add(PdfFolderItem(
            id: itemJson['id'],
            name: itemJson['name'],
            color: Color(itemJson['color']),
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

/* ----------------------
   Home Page
---------------------- */
class PDFHomePage extends StatefulWidget {
  const PDFHomePage({super.key});

  @override
  State<PDFHomePage> createState() => _PDFHomePageState();
}

class _PDFHomePageState extends State<PDFHomePage> {
  final List<FileSystemItem> _allItems = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _selectionMode = false;
  final List<FileSystemItem> _selectedItems = [];
  int _bottomIndex = 0;
  bool _darkModeManual = false;
  PdfFolderItem? _currentFolder;
  final List<PdfFolderItem> _folderStack = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final items = await DataPersistence.loadItems();
    final darkMode = await DataPersistence.loadDarkMode();
    
    setState(() {
      _allItems.addAll(items);
      _darkModeManual = darkMode;
    });
  }

  Future<void> _saveData() async {
    await DataPersistence.saveItems(_allItems);
    await DataPersistence.saveDarkMode(_darkModeManual);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        int importedCount = 0;
        
        for (final file in result.files) {
          if (file.path != null) {
            final path = file.path!;
            final f = File(path);
            String name = p.basename(path);
            
            // Aynı dosya kontrolü - eğer varsa numaralandır
            int counter = 1;
            String baseName = p.basenameWithoutExtension(path);
            String extension = p.extension(path);
            
            while (_allItems.any((it) => it is PdfFileItem && (it as PdfFileItem).file.path == path) || 
                   _allItems.any((it) => it.name == name)) {
              name = '$baseName($counter)$extension';
              counter++;
            }
            
            final id = 'file_${DateTime.now().millisecondsSinceEpoch}_${importedCount}';
            
            setState(() {
              final newFile = PdfFileItem(
                id: id, 
                name: name, 
                file: f,
                folderId: _currentFolder?.id,
              );
              _allItems.add(newFile);
              
              // Eğer klasör içindeysek, klasöre de ekle
              if (_currentFolder != null) {
                _currentFolder!.items.add(newFile);
              }
            });
            importedCount++;
          }
        }
        
        _saveData();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$importedCount dosya içe aktarıldı'))
          );
        }
      }
    } catch (e) {
      debugPrint('Import error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İçe aktarma başarısız'))
        );
      }
    }
  }

  void _createFolder() async {
    final name = await _showTextInput('Yeni klasör adı', '');
    if (name != null && name.trim().isNotEmpty) {
      setState(() {
        final newFolder = PdfFolderItem(
          id: 'folder_${DateTime.now().millisecondsSinceEpoch}', 
          name: name.trim(),
          parentFolderId: _currentFolder?.id,
        );
        _allItems.add(newFolder);
        
        if (_currentFolder != null) {
          _currentFolder!.items.add(newFolder);
        }
      });
      _saveData();
    }
  }

  Future<String?> _showTextInput(String title, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('İptal')
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text), 
            child: const Text('Tamam')
          ),
        ],
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedItems.clear();
    });
  }

  void _sortByName() {
    setState(() {
      _allItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
    _saveData();
  }

  void _sortBySize() {
    setState(() {
      _allItems.sort((a, b) {
        if (a is PdfFileItem && b is PdfFileItem) {
          final aSize = a.file.lengthSync();
          final bSize = b.file.lengthSync();
          return bSize.compareTo(aSize); // Büyükten küçüğe
        } else if (a is PdfFileItem) {
          return -1; // Dosyalar klasörlerden önce
        } else if (b is PdfFileItem) {
          return 1; // Klasörler dosyalardan sonra
        } else {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
      });
    });
    _saveData();
  }

  void _showSortSheet() {
    showModalBottomSheet(context: context, builder: (ctx) {
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.sort_by_alpha),
            title: const Text('A\'dan Z\'ye sırala'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _sortByName(); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.sort_by_alpha),
            title: const Text('Z\'den A\'ya sırala'), 
            onTap: () { 
              Navigator.pop(ctx); 
              setState(() => _allItems.sort((a,b)=>b.name.toLowerCase().compareTo(a.name.toLowerCase()))); 
              _saveData();
            }
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Boyuta göre sırala'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _sortBySize(); 
            }
          ),
        ]),
      );
    });
  }

  void _openFile(PdfFileItem item) async {
    // Sadece viewer açıldığında recent'e ekle - burada ekleme yapmıyoruz
    final returned = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => ViewerScreen(
        file: item.file,
        fileName: item.name,
        dark: _darkModeManual,
        onFileOpened: () {
          // Viewer açıldığında recent'e ekle
          setState(() {
            item.lastOpened = DateTime.now();
          });
          _saveData();
        },
      )),
    );

    // Görüntüleyiciden dönen kayıtlı dosyayı işle
    if (returned != null && returned.existsSync()) {
      final exists = _allItems.any((it) => it is PdfFileItem && (it as PdfFileItem).file.path == returned.path);
      if (!exists) {
        setState(() {
          _allItems.add(PdfFileItem(
            id: 'file_${DateTime.now().millisecondsSinceEpoch}', 
            name: p.basename(returned.path), 
            file: returned,
            folderId: _currentFolder?.id,
          ));
        });
        _saveData();
      }
    }
  }

  void _toggleFavorite(PdfFileItem item) {
    setState(() {
      item.isFavorite = !item.isFavorite;
    });
    _saveData();
    _notify(item.isFavorite ? 'Favorilere eklendi' : 'Favorilerden kaldırıldı');
  }

  Future<void> _shareFiles(List<FileSystemItem> items) async {
    try {
      final files = items.whereType<PdfFileItem>().map((item) => XFile(item.file.path)).toList();
      if (files.isNotEmpty) {
        await Share.shareXFiles(files,
          text: '${files.length} PDF Dosyası'
        );
      }
    } catch (e) {
      debugPrint('Share error: $e');
      _notify('Paylaşım başarısız');
    }
  }

  Future<void> _printFiles(List<FileSystemItem> items) async {
    try {
      for (final item in items.whereType<PdfFileItem>()) {
        final pdfData = await item.file.readAsBytes();
        await Printing.layoutPdf(
          onLayout: (format) => pdfData,
        );
      }
    } catch (e) {
      debugPrint('Print error: $e');
      _notify('Yazdırma başarısız');
    }
  }

  void _deleteSelectedItems() {
    if (_selectedItems.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sil'),
        content: Text('${_selectedItems.length} öğe silinsin mi? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('İptal')
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                for (final item in _selectedItems) {
                  _allItems.remove(item);
                  
                  // Eğer bir klasör siliniyorsa, içindeki öğeleri de kaldır
                  if (item is PdfFolderItem) {
                    _allItems.removeWhere((it) => it.parentFolderId == item.id);
                  }
                }
                _selectedItems.clear();
                _selectionMode = false;
              });
              _saveData();
              _notify('${_selectedItems.length} öğe silindi');
            }, 
            child: const Text('Sil', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  void _moveItem(FileSystemItem item) {
    // Klasör seçimi için modal göster - Root (All Files) dahil
    showModalBottomSheet(context: context, builder: (ctx) {
      final availableFolders = _getAvailableFoldersForMove(item);
      
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Klasöre Taşı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            // Root (All Files) seçeneği
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Tüm Dosyalar (Root)'),
              onTap: () {
                Navigator.pop(ctx);
                _performMove(item, null); // null = root
              },
            ),
            ...availableFolders.map((folder) => ListTile(
              leading: Icon(Icons.folder, color: folder.color),
              title: Text(folder.name),
              onTap: () {
                Navigator.pop(ctx);
                _performMove(item, folder);
              },
            )).toList(),
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text('Yeni klasör oluştur'),
              onTap: () {
                Navigator.pop(ctx);
                _createFolderForMove(item);
              },
            ),
          ],
        ),
      );
    });
  }

  List<PdfFolderItem> _getAvailableFoldersForMove(FileSystemItem item) {
    // Mevcut klasörü ve alt klasörlerini hariç tut
    final allFolders = _allItems.whereType<PdfFolderItem>().toList();
    
    if (item is PdfFolderItem) {
      // Klasörü kendisine veya alt klasörlerine taşıyamazsın
      return allFolders.where((folder) {
        return folder.id != item.id && !_isSubfolder(folder, item);
      }).toList();
    }
    
    return allFolders;
  }

  bool _isSubfolder(PdfFolderItem potentialParent, PdfFolderItem potentialChild) {
    // Basit alt klasör kontrolü - gerçek uygulamada daha karmaşık olabilir
    if (potentialChild.parentFolderId == potentialParent.id) return true;
    
    // Parent'ın parent'ını kontrol et (recursive olarak)
    if (potentialChild.parentFolderId != null) {
      final parent = _allItems.whereType<PdfFolderItem>()
          .firstWhere((f) => f.id == potentialChild.parentFolderId);
      return _isSubfolder(potentialParent, parent);
    }
    
    return false;
  }

  void _createFolderForMove(FileSystemItem item) async {
    final name = await _showTextInput('Yeni klasör adı', '');
    if (name != null && name.trim().isNotEmpty) {
      final newFolder = PdfFolderItem(
        id: 'folder_${DateTime.now().millisecondsSinceEpoch}', 
        name: name.trim()
      );
      setState(() {
        _allItems.add(newFolder);
      });
      _performMove(item, newFolder);
    }
  }

  void _performMove(FileSystemItem item, PdfFolderItem? targetFolder) {
    setState(() {
      // Önceki konumdan kaldır
      if (item.parentFolderId != null) {
        final previousFolder = _allItems.whereType<PdfFolderItem>()
            .firstWhere((f) => f.id == item.parentFolderId);
        previousFolder.items.remove(item);
      } else {
        _allItems.remove(item);
      }
      
      // Parent ID'sini güncelle
      item.parentFolderId = targetFolder?.id;
      
      // Yeni konuma ekle
      if (targetFolder != null) {
        targetFolder.items.add(item);
      } else {
        // Root'a taşı
        _allItems.add(item);
      }
    });
    _saveData();
    _notify('"${item.name}" ${targetFolder?.name ?? "Tüm Dosyalar"} klasörüne taşındı');
  }

  void _openFolder(PdfFolderItem folder) {
    setState(() {
      _folderStack.add(folder);
      _currentFolder = folder;
    });
  }

  void _exitFolder() {
    setState(() {
      if (_folderStack.isNotEmpty) {
        _folderStack.removeLast();
        _currentFolder = _folderStack.isNotEmpty ? _folderStack.last : null;
      } else {
        _currentFolder = null;
      }
    });
  }

  void _showFileMenu(FileSystemItem item) {
    if (item is PdfFileItem) {
      showModalBottomSheet(context: context, builder: (ctx) {
        return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline), 
            title: const Text('Yeniden Adlandır'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _renameItem(item); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.print), 
            title: const Text('Yazdır'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _printFiles([item]); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.share), 
            title: const Text('Paylaş'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _shareFiles([item]); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move), 
            title: const Text('Taşı'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _moveItem(item); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline), 
            title: const Text('Sil'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _deleteItem(item); 
            }
          ),
        ]));
      });
    } else if (item is PdfFolderItem) {
      showModalBottomSheet(context: context, builder: (ctx) {
        return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline), 
            title: const Text('Yeniden Adlandır'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _renameItem(item); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move), 
            title: const Text('Taşı'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _moveItem(item); 
            }
          ),
          ListTile(
            leading: Icon(Icons.color_lens, color: item.color), 
            title: const Text('Rengi değiştir'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _changeFolderColor(item); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline), 
            title: const Text('Sil'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _deleteItem(item); 
            }
          ),
        ]));
      });
    }
  }

  void _renameItem(FileSystemItem item) async {
    final newName = await _showTextInput('Yeniden Adlandır', item.name);
    if (newName != null && newName.trim().isNotEmpty) {
      setState(() => item.name = newName.trim());
      _saveData();
    }
  }

  void _deleteItem(FileSystemItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sil'),
        content: Text('"${item.name}" silinsin mi? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('İptal')
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _allItems.remove(item);
                _selectedItems.remove(item);
                
                // Eğer bir klasör siliniyorsa, içindeki öğeleri de kaldır
                if (item is PdfFolderItem) {
                  _allItems.removeWhere((it) => it.parentFolderId == item.id);
                }
              });
              _saveData();
              _notify('"${item.name}" silindi');
            }, 
            child: const Text('Sil', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  void _notify(String text) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _changeFolderColor(PdfFolderItem folder) async {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal, Colors.grey];
    final chosen = await showModalBottomSheet<Color?>(
      context: context,
      builder: (ctx) {
        return SafeArea(child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: colors.map((c) => GestureDetector(
            onTap: () => Navigator.pop(ctx, c),
            child: Container(
              margin: const EdgeInsets.all(8), 
              width: 48, 
              height: 48, 
              decoration: BoxDecoration(
                color: c, 
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2)
              )
            ),
          )).toList(),
        ));
      }
    );
    if (chosen != null) {
      setState(() => folder.color = chosen);
      _saveData();
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PDF Manager Hakkında'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PDF Manager v1.0', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('PDF dosyalarınızı yönetmek ve görüntülemek için geliştirilmiş bir uygulamadır.'),
            SizedBox(height: 8),
            Text('Özellikler:'),
            Text('• PDF görüntüleme'),
            Text('• Dosya yönetimi'),
            Text('• Klasör organizasyonu'),
            Text('• Favorilere ekleme'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _toggleDarkMode(bool value) {
    setState(() {
      _darkModeManual = value;
    });
    _saveData();
    _notify('${value ? 'Karanlık' : 'Açık'} mod ${value ? 'açıldı' : 'kapatıldı'}');
  }

  /* ----------------------
     UI build
  ---------------------- */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String title = 'Tüm Dosyalar';
    
    if (_currentFolder != null) {
      title = _currentFolder!.name;
    } else {
      switch (_bottomIndex) {
        case 0: title = 'Tüm Dosyalar'; break;
        case 1: title = 'Son Görüntülenenler'; break;
        case 2: title = 'Favoriler'; break;
        case 3: title = 'Araçlar'; break;
      }
    }

    return Scaffold(
      drawer: _currentFolder == null && !_isSearching ? Drawer(
        child: SafeArea(
          child: Column(children: [
            DrawerHeader(
              child: Text('PDF Okuyucu & Yönetici', 
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: _darkModeManual ? Colors.red : Colors.white
                )
              ),
              decoration: BoxDecoration(
                color: _darkModeManual ? Colors.black : Colors.red
              )
            ),
            ListTile(
              leading: Icon(Icons.cloud_upload, 
                color: _darkModeManual ? Colors.red : null
              ), 
              title: const Text('PDF İçe Aktar'), 
              onTap: () { 
                Navigator.pop(context); 
                _importPdf(); 
              }
            ),
            ListTile(
              leading: Icon(Icons.create_new_folder,
                color: _darkModeManual ? Colors.red : null
              ), 
              title: const Text('Klasör Oluştur'), 
              onTap: () { 
                Navigator.pop(context); 
                _createFolder(); 
              }
            ),
            ListTile(
              leading: Icon(Icons.info,
                color: _darkModeManual ? Colors.red : null
              ), 
              title: const Text('Hakkında'), 
              onTap: () { 
                Navigator.pop(context); 
                _showAboutDialog(); 
              }
            ),
            SwitchListTile(
              secondary: Icon(
                _darkModeManual ? Icons.light_mode : Icons.dark_mode,
                color: _darkModeManual ? Colors.red : null,
              ),
              title: Text(_darkModeManual ? 'Açık Mod' : 'Karanlık Mod'),
              value: _darkModeManual,
              onChanged: _toggleDarkMode,
            ),
            ListTile(
              leading: Icon(Icons.policy,
                color: _darkModeManual ? Colors.red : null
              ), 
              title: const Text('Gizlilik'), 
              onTap: () { 
                Navigator.pop(context); 
                _notify('Gizlilik Politikası'); 
              }
            ),
            ListTile(
              leading: Icon(Icons.language,
                color: _darkModeManual ? Colors.red : null
              ), 
              title: const Text('Dil'), 
              onTap: () { 
                Navigator.pop(context); 
                _notify('Dil Seçenekleri'); 
              }
            ),
          ]),
        ),
      ) : null,
      appBar: AppBar(
        title: _isSearching ? _buildSearchField() : Text(title),
        centerTitle: true,
        leading: _buildLeadingIcon(),
        backgroundColor: _darkModeManual ? Colors.black : Colors.red,
        foregroundColor: _darkModeManual ? Colors.red : Colors.white,
        actions: _buildAppBarActions(),
      ),
      body: _buildBody(),
      bottomNavigationBar: _currentFolder == null ? BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) { 
          setState(() { 
            _bottomIndex = i; 
            _selectionMode = false; 
            _selectedItems.clear(); 
          }); 
        },
        selectedItemColor: Colors.red,
        unselectedItemColor: _darkModeManual ? Colors.grey[400] : Colors.black,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Tüm Dosyalar'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Son'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoriler'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Araçlar'),
        ],
      ) : null,
    );
  }

  Widget? _buildLeadingIcon() {
    if (_isSearching) {
      return IconButton(
        icon: Icon(Icons.close,
          color: _darkModeManual ? Colors.red : Colors.white
        ),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchController.clear();
          });
        },
      );
    } else if (_currentFolder != null) {
      return IconButton(
        icon: Icon(Icons.arrow_back,
          color: _darkModeManual ? Colors.red : Colors.white
        ),
        onPressed: _exitFolder,
      );
    }
    return null;
  }

  List<Widget> _buildAppBarActions() {
    if (_currentFolder != null) return [];
    
    if (_selectionMode && _selectedItems.isNotEmpty) {
      return [
        IconButton(
          icon: Icon(Icons.print,
            color: _darkModeManual ? Colors.red : Colors.white
          ),
          onPressed: () => _printFiles(_selectedItems),
        ),
        IconButton(
          icon: Icon(Icons.share,
            color: _darkModeManual ? Colors.red : Colors.white
          ),
          onPressed: () => _shareFiles(_selectedItems),
        ),
        IconButton(
          icon: Icon(Icons.delete,
            color: _darkModeManual ? Colors.red : Colors.white
          ),
          onPressed: _deleteSelectedItems,
        ),
      ];
    }
    
    return [
      if (!_isSearching) ...[
        IconButton(
          icon: Icon(Icons.search,
            color: _darkModeManual ? Colors.red : Colors.white
          ), 
          onPressed: () { 
            setState(() => _isSearching = !_isSearching); 
            if (!_isSearching) _searchController.clear();
          }
        ),
        IconButton(
          icon: Icon(Icons.sort,
            color: _darkModeManual ? Colors.red : Colors.white
          ), 
          onPressed: _showSortSheet
        ),
        IconButton(
          icon: _selectionMode 
              ? Icon(Icons.check_box,
                  color: _darkModeManual ? Colors.red : Colors.white
                )
              : Icon(Icons.check_box_outline_blank,
                  color: _darkModeManual ? Colors.red : Colors.white
                ), 
          onPressed: _toggleSelectionMode
        ),
      ],
    ];
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Dosyalarda ara...', 
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: _darkModeManual ? Colors.red.withOpacity(0.7) : Colors.white70
        )
      ),
      style: TextStyle(color: _darkModeManual ? Colors.red : Colors.white),
      autofocus: true,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildBody() {
    List<FileSystemItem> display = _getDisplayItems();
    
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      display = display.where((it) => it.name.toLowerCase().contains(q)).toList();
    }

    if (_bottomIndex == 3) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, 
              color: _darkModeManual ? Colors.red : Colors.grey[400]
            ),
            const SizedBox(height: 16),
            Text(
              'Araçlar sekmesi - Yakında',
              style: TextStyle(
                color: _darkModeManual ? Colors.red : Colors.grey[600], 
                fontSize: 16
              ),
            ),
          ],
        ),
      );
    }

    if (display.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, 
              color: _darkModeManual ? Colors.red : Colors.grey[400]
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz dosya yok',
              style: TextStyle(
                fontSize: 18, 
                color: _darkModeManual ? Colors.red : Colors.grey
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni PDF eklemek için + simgesine tıklayın',
              style: TextStyle(
                color: _darkModeManual ? Colors.red : Colors.grey
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: display.length,
      itemBuilder: (ctx, i) {
        final item = display[i];
        final isSelected = _selectedItems.contains(item);
        
        if (item is PdfFileItem) {
          return _buildFileItem(item, isSelected);
        } else if (item is PdfFolderItem) {
          return _buildFolderItem(item, isSelected);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildFileItem(PdfFileItem item, bool isSelected) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: isSelected 
          ? (theme.colorScheme.secondaryContainer.withOpacity(0.3))
          : (theme.cardColor),
      child: ListTile(
        leading: _selectionMode 
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleItemSelection(item),
              )
            : Icon(Icons.picture_as_pdf, 
                color: _darkModeManual ? Colors.red : Colors.red
              ),
        title: Text(item.name, 
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _darkModeManual ? Colors.white : Colors.black
          )
        ),
        subtitle: Text(
          '${_formatFileSize(item.file.lengthSync())} • ${_formatDate(item.lastOpened)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _darkModeManual ? Colors.grey[400] : Colors.grey[600]
          )
        ),
        trailing: _selectionMode ? null : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                item.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: item.isFavorite ? Colors.red : (_darkModeManual ? Colors.red : Colors.grey),
              ),
              onPressed: () => _toggleFavorite(item),
            ),
            IconButton(
              icon: Icon(Icons.more_vert,
                color: _darkModeManual ? Colors.red : null
              ),
              onPressed: () => _showFileMenu(item),
            ),
          ],
        ),
        onTap: () {
          if (_selectionMode) {
            _toggleItemSelection(item);
          } else {
            _openFile(item);
          }
        },
        onLongPress: () => _toggleItemSelection(item),
      ),
    );
  }

  Widget _buildFolderItem(PdfFolderItem item, bool isSelected) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: isSelected 
          ? (theme.colorScheme.secondaryContainer.withOpacity(0.3))
          : (theme.cardColor),
      child: ListTile(
        leading: _selectionMode 
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleItemSelection(item),
              )
            : Icon(Icons.folder, color: item.color),
        title: Text(item.name, 
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _darkModeManual ? Colors.white : Colors.black
          )
        ),
        subtitle: Text(
          '${item.items.length} öğe',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _darkModeManual ? Colors.grey[400] : Colors.grey[600]
          )
        ),
        trailing: _selectionMode ? null : IconButton(
          icon: Icon(Icons.more_vert,
            color: _darkModeManual ? Colors.red : null
          ),
          onPressed: () => _showFileMenu(item),
        ),
        onTap: () {
          if (_selectionMode) {
            _toggleItemSelection(item);
          } else {
            _openFolder(item);
          }
        },
        onLongPress: () => _toggleItemSelection(item),
      ),
    );
  }

  void _toggleItemSelection(FileSystemItem item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  List<FileSystemItem> _getDisplayItems() {
    if (_currentFolder != null) {
      return _currentFolder!.items;
    }

    switch (_bottomIndex) {
      case 0: // All Files
        return _allItems;
      case 1: // Recent
        final files = _allItems.whereType<PdfFileItem>().toList();
        files.sort((a, b) => (b.lastOpened ?? DateTime(0)).compareTo(a.lastOpened ?? DateTime(0)));
        return files.take(20).toList();
      case 2: // Favorites
        return _allItems.where((it) => it is PdfFileItem && (it as PdfFileItem).isFavorite).toList();
      default:
        return _allItems;
    }
  }

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
}

/* ----------------------
   Viewer Screen
---------------------- */

class ViewerScreen extends StatefulWidget {
  final File file;
  final String fileName;
  final bool dark;
  final VoidCallback? onFileOpened;
  const ViewerScreen({
    super.key, 
    required this.file, 
    required this.fileName, 
    required this.dark,
    this.onFileOpened,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  InAppWebViewController? _controller;
  bool _loaded = false;
  File? _savedFile;

  @override
  void initState() {
    super.initState();
    // Viewer açıldığında callback'i çağır
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onFileOpened?.call();
    });
  }

  String _makeViewerUrl() {
    final fileUri = Uri.file(widget.file.path).toString();
    final dark = widget.dark ? 'true' : 'false';
    final url = 'file:///android_asset/flutter_assets/assets/web/viewer.html?file=${Uri.encodeComponent(fileUri)}&dark=$dark';
    return url;
  }

  Future<void> _handleOnPdfSaved(List<dynamic> args) async {
    try {
      final originalName = args.isNotEmpty ? (args[0] as String) : widget.fileName;
      final base64Data = (args.length > 1 && args[1] != null) ? args[1] as String : null;
      final dir = widget.file.parent.path;
      final savedName = 'update_$originalName';
      final newPath = p.join(dir, savedName);

      if (base64Data != null && base64Data.isNotEmpty) {
        final bytes = base64Decode(base64Data);
        final f = await File(newPath).writeAsBytes(bytes);
        _savedFile = f;
      } else {
        // fallback: copy original file
        final f = await widget.file.copy(newPath);
        _savedFile = f;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.basename(_savedFile!.path)} kaydedildi')));
      }
    } catch (e) {
      debugPrint('onPdfSaved error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydetme başarısız')));
    }
  }

  Future<void> _printFile() async {
    try {
      final pdfData = await widget.file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (format) => pdfData,
      );
    } catch (e) {
      debugPrint('Print error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yazdırma başarısız'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _makeViewerUrl();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _savedFile);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName),
          backgroundColor: widget.dark ? Colors.black : Colors.red,
          foregroundColor: widget.dark ? Colors.red : Colors.white,
          toolbarHeight: 48, // Daha ince app bar
          actions: [
            IconButton(
              icon: Icon(Icons.print,
                color: widget.dark ? Colors.red : Colors.white
              ),
              onPressed: _printFile,
            ),
            IconButton(
              icon: Icon(Icons.share,
                color: widget.dark ? Colors.red : Colors.white
              ),
              onPressed: () async {
                try {
                  await Share.shareXFiles([XFile(widget.file.path)],
                    text: 'PDF Dosyası: ${widget.fileName}'
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Paylaşım başarısız'))
                  );
                }
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            Container(color: widget.dark ? Colors.black : Colors.transparent),
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                allowFileAccess: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                supportZoom: true,
                useHybridComposition: true,
              ),
              onWebViewCreated: (controller) async {
                _controller = controller;
                controller.addJavaScriptHandler(handlerName: "onPdfSaved", callback: (args) {
                  _handleOnPdfSaved(args);
                });
              },
              onLoadStop: (controller, url) {
                setState(() => _loaded = true);
              },
              onConsoleMessage: (controller, message) {
                debugPrint('WEBVIEW: ${message.message}');
              },
              onLoadError: (controller, url, code, message) {
                debugPrint('WEBVIEW LOAD ERROR ($code): $message');
              },
            ),
            if (!_loaded)
              Center(
                child: CircularProgressIndicator(
                  color: widget.dark ? Colors.red : Colors.red
                ),
              ),
          ],
        ),
      ),
    );
  }
}

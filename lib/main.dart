// tek_dosya_main.dart
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // InAppWebView için gerekli initializasyon
  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  
  runApp(const PDFApp());
}

// ==================== MODELS ====================

abstract class FileSystemItem {
  final String id;
  String name;
  DateTime? lastOpened;
  bool isFavorite;
  String? parentFolderId;
  
  FileSystemItem({
    required this.id,
    required this.name,
    this.lastOpened,
    this.isFavorite = false,
    this.parentFolderId,
  });

  String get displayName => name;
  DateTime get sortDate => lastOpened ?? DateTime(0);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileSystemItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
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
  }) : super(
    id: id, 
    name: name, 
    lastOpened: lastOpened,
    isFavorite: isFavorite,
  );
}

class PdfFolderItem extends FileSystemItem {
  Color color;
  final List<FileSystemItem> items = [];
  
  PdfFolderItem({
    required String id,
    required String name,
    this.color = Colors.blue,
    String? parentFolderId,
  }) : super(
    id: id, 
    name: name, 
    parentFolderId: parentFolderId,
  );
}

// ==================== SERVICES ====================

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
    } catch (e) {
      throw FilePickerException('Dosya seçim hatası: $e');
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

class DataPersistence {
  static const String _itemsKey = 'file_system_items';
  static const String _darkModeKey = 'dark_mode';

  static Future<void> saveItems(List<FileSystemItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    
    final List<Map<String, dynamic>> allItemsJson = [];
    
    void addItemToJson(FileSystemItem item) {
      if (item is PdfFileItem) {
        allItemsJson.add({
          'type': 'file',
          'id': item.id,
          'name': item.name,
          'path': item.file.path,
          'folderId': item.folderId,
          'lastOpened': item.lastOpened?.millisecondsSinceEpoch,
          'isFavorite': item.isFavorite,
        });
      } else if (item is PdfFolderItem) {
        allItemsJson.add({
          'type': 'folder',
          'id': item.id,
          'name': item.name,
          'color': item.color.value,
          'parentFolderId': item.parentFolderId,
        });
        
        for (final childItem in item.items) {
          addItemToJson(childItem);
        }
      }
    }
    
    for (final item in items) {
      addItemToJson(item);
    }
    
    await prefs.setString(_itemsKey, json.encode(allItemsJson));
  }

  static Future<List<FileSystemItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJsonString = prefs.getString(_itemsKey);
    
    if (itemsJsonString == null) return [];
    
    try {
      final List<dynamic> itemsJson = json.decode(itemsJsonString);
      final List<FileSystemItem> allItems = [];
      final Map<String, PdfFolderItem> folderMap = {};
      
      // ✅ İLK GEÇİŞ: Tüm klasörleri oluştur ve allItems'a ekle
      for (final itemJson in itemsJson) {
        if (itemJson['type'] == 'folder') {
          final folder = PdfFolderItem(
            id: itemJson['id'],
            name: itemJson['name'],
            color: Color(itemJson['color']),
            parentFolderId: itemJson['parentFolderId'],
          );
          folderMap[folder.id] = folder;
          
          // ✅ KLASÖRÜ allItems'A EKLE - parent'ı yoksa
          if (itemJson['parentFolderId'] == null) {
            allItems.add(folder);
          }
        }
      }
      
      // ✅ İKİNCİ GEÇİŞ: Tüm dosyaları ve klasör ilişkilerini kur
      for (final itemJson in itemsJson) {
        if (itemJson['type'] == 'file') {
          final file = File(itemJson['path']);
          if (await file.exists()) {
            final fileItem = PdfFileItem(
              id: itemJson['id'],
              name: itemJson['name'],
              file: file,
              folderId: itemJson['folderId'],
              lastOpened: itemJson['lastOpened'] != null 
                  ? DateTime.fromMillisecondsSinceEpoch(itemJson['lastOpened'])
                  : null,
              isFavorite: itemJson['isFavorite'] ?? false,
            );
            
            // ✅ DOSYAYI DOĞRU KLASÖRE EKLE
            if (fileItem.folderId != null && folderMap.containsKey(fileItem.folderId)) {
              folderMap[fileItem.folderId]!.items.add(fileItem);
            } else {
              // ✅ KLASÖRÜ YOKSA ROOT'A EKLE
              allItems.add(fileItem);
            }
          }
        } else if (itemJson['type'] == 'folder') {
          final folderId = itemJson['id'];
          final parentFolderId = itemJson['parentFolderId'];
          
          // ✅ ALT KLASÖR İLİŞKİSİNİ KUR
          if (parentFolderId != null && folderMap.containsKey(parentFolderId)) {
            folderMap[parentFolderId]!.items.add(folderMap[folderId]!);
          }
          // ✅ ROOT KLASÖRLER zaten ilk geçişte eklendi
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

// ==================== WIDGETS ====================

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isSearching;
  final TextEditingController searchController;
  final bool darkMode;
  final Widget? leadingIcon;
  final List<Widget> actions;
  final ValueChanged<String>? onSearchChanged;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.isSearching,
    required this.searchController,
    required this.darkMode,
    this.leadingIcon,
    required this.actions,
    this.onSearchChanged,
  });

  Widget _buildSearchField() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Dosyalarda ara...', 
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: darkMode ? Colors.white70 : Colors.white70
        )
      ),
      style: TextStyle(color: darkMode ? Colors.white : Colors.white),
      autofocus: true,
      onChanged: onSearchChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: isSearching ? _buildSearchField() : Text(title),
      centerTitle: true,
      leading: leadingIcon,
      backgroundColor: darkMode ? Colors.black : Colors.red,
      foregroundColor: Colors.white,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}

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

// ==================== VIEWER SCREEN ====================

class ViewerScreen extends StatefulWidget {
  final File file;
  final String fileName;
  final bool dark;
  final VoidCallback onFileOpened;

  const ViewerScreen({
    super.key,
    required this.file,
    required this.fileName,
    required this.dark,
    required this.onFileOpened,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late InAppWebViewController _webViewController;
  bool _isLoading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    widget.onFileOpened();
  }

  Future<String> _getPdfUrl() async {
    if (Platform.isAndroid) {
      // Android için dosyayı uygulama dizinine kopyala
      final appDir = await getApplicationDocumentsDirectory();
      final newFile = File('${appDir.path}/${widget.fileName}');
      await newFile.writeAsBytes(await widget.file.readAsBytes());
      return 'file://${newFile.path}';
    } else {
      // iOS için orijinal dosya yolunu kullan
      return 'file://${widget.file.path}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.dark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          widget.fileName,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        backgroundColor: widget.dark ? Colors.black : Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePdf(),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printPdf(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: widget.dark ? Colors.grey[800] : Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.dark ? Colors.red : Colors.red,
              ),
            ),
          Expanded(
            child: FutureBuilder<String>(
              future: _getPdfUrl(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.dark ? Colors.red : Colors.red,
                      ),
                    ),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error,
                          size: 64,
                          color: widget.dark ? Colors.red : Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'PDF yüklenirken hata oluştu',
                          style: TextStyle(
                            color: widget.dark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final pdfUrl = snapshot.data!;
                
                return InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(pdfUrl)),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _isLoading = true;
                      _progress = 0;
                    });
                  },
                  onLoadStop: (controller, url) {
                    setState(() {
                      _isLoading = false;
                    });
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      _progress = progress / 100;
                    });
                  },
                  onLoadError: (controller, url, code, message) {
                    setState(() {
                      _isLoading = false;
                    });
                    debugPrint('PDF Load Error: $message');
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePdf() async {
    try {
      await Share.shareXFiles([XFile(widget.file.path)],
        text: 'PDF Dosyası: ${widget.fileName}'
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşım hatası: $e'))
        );
      }
    }
  }

  Future<void> _printPdf() async {
    try {
      final pdfData = await widget.file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (format) => pdfData,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yazdırma hatası: $e'))
        );
      }
    }
  }
}

// ==================== TOOLS WEBVIEW ====================

class ToolsWebView extends StatefulWidget {
  final bool darkMode;

  const ToolsWebView({super.key, required this.darkMode});

  @override
  State<ToolsWebView> createState() => _ToolsWebViewState();
}

class _ToolsWebViewState extends State<ToolsWebView> {
  late InAppWebViewController _webViewController;
  bool _isLoading = true;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.darkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text(
          'PDF Araçları',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: widget.darkMode ? Colors.black : Colors.red,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PDFHomePage()),
            (route) => false,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: widget.darkMode ? Colors.grey[800] : Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.darkMode ? Colors.red : Colors.red,
              ),
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://smallpdf.com/tr')
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;
                  _progress = 0;
                });
              },
              onLoadStop: (controller, url) {
                setState(() {
                  _isLoading = false;
                });
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100;
                });
              },
              onLoadError: (controller, url, code, message) {
                setState(() {
                  _isLoading = false;
                });
                debugPrint('WebView Load Error: $message');
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== MAIN APP & HOME PAGE ====================

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
          toolbarHeight: 48,
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
          foregroundColor: Colors.white,
          toolbarHeight: 48,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
      final files = await FileService.importPdfFiles();
      int importedCount = 0;
      
      for (final file in files) {
        final path = file.path;
        String name = FileService.generateUniqueFileName(
          _allItems.map((item) => item.name).toList(),
          path
        );
        
        final id = FileService.generateFileId();
        
        setState(() {
          final newFile = PdfFileItem(
            id: id, 
            name: name, 
            file: file,
            folderId: _currentFolder?.id,
          );
          
          if (_currentFolder != null) {
            _currentFolder!.items.add(newFile);
          } else {
            _allItems.add(newFile);
          }
        });
        importedCount++;
      }
      
      _saveData();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$importedCount dosya içe aktarıldı'))
        );
      }
    } on FilePickerException catch (e) {
      debugPrint('Import error: ${e.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İçe aktarma başarısız: ${e.message}'))
        );
      }
    } catch (e) {
      debugPrint('Unexpected import error: $e');
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
          id: FileService.generateFolderId(), 
          name: name.trim(),
          parentFolderId: _currentFolder?.id,
        );
        
        if (_currentFolder != null) {
          _currentFolder!.items.add(newFolder);
        } else {
          _allItems.add(newFolder);
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

  void _selectAllItems() {
    setState(() {
      _selectedItems.clear();
      _selectedItems.addAll(_getDisplayItems());
    });
  }

  void _deselectAllItems() {
    setState(() {
      _selectedItems.clear();
    });
  }

  void _showSortSheet() {
    showModalBottomSheet(context: context, builder: (ctx) {
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Sıralama Seçenekleri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sort_by_alpha),
            title: const Text('İsme göre (A-Z)'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _sortByNameAZ(); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.sort_by_alpha),
            title: const Text('İsme göre (Z-A)'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _sortByNameZA(); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Boyuta göre (Büyükten Küçüğe)'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _sortBySizeDescending(); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Boyuta göre (Küçükten Büyüğe)'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _sortBySizeAscending(); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Tarihe göre (Yeniden Eskiye)'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _sortByDateDescending(); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Tarihe göre (Eskiden Yeniye)'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _sortByDateAscending(); 
            }
          ),
        ]),
      );
    });
  }

  void _sortByNameAZ() {
    setState(() {
      _allItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
    _saveData();
  }

  void _sortByNameZA() {
    setState(() {
      _allItems.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    });
    _saveData();
  }

  void _sortBySizeDescending() {
    setState(() {
      _allItems.sort((a, b) {
        if (a is PdfFileItem && b is PdfFileItem) {
          final aSize = a.file.lengthSync();
          final bSize = b.file.lengthSync();
          return bSize.compareTo(aSize);
        } else if (a is PdfFileItem) {
          return -1;
        } else if (b is PdfFileItem) {
          return 1;
        } else {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
      });
    });
    _saveData();
  }

  void _sortBySizeAscending() {
    setState(() {
      _allItems.sort((a, b) {
        if (a is PdfFileItem && b is PdfFileItem) {
          final aSize = a.file.lengthSync();
          final bSize = b.file.lengthSync();
          return aSize.compareTo(bSize);
        } else if (a is PdfFileItem) {
          return -1;
        } else if (b is PdfFileItem) {
          return 1;
        } else {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
      });
    });
    _saveData();
  }

  void _sortByDateDescending() {
    setState(() {
      _allItems.sort((a, b) {
        if (a is PdfFileItem && b is PdfFileItem) {
          final aDate = a.lastOpened ?? DateTime(0);
          final bDate = b.lastOpened ?? DateTime(0);
          return bDate.compareTo(aDate);
        } else if (a is PdfFileItem) {
          return -1;
        } else if (b is PdfFileItem) {
          return 1;
        } else {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
      });
    });
    _saveData();
  }

  void _sortByDateAscending() {
    setState(() {
      _allItems.sort((a, b) {
        if (a is PdfFileItem && b is PdfFileItem) {
          final aDate = a.lastOpened ?? DateTime(0);
          final bDate = b.lastOpened ?? DateTime(0);
          return aDate.compareTo(bDate);
        } else if (a is PdfFileItem) {
          return -1;
        } else if (b is PdfFileItem) {
          return 1;
        } else {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
      });
    });
    _saveData();
  }

  void _openFile(PdfFileItem item) async {
    final returned = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => ViewerScreen(
        file: item.file,
        fileName: item.name,
        dark: _darkModeManual,
        onFileOpened: () {
          setState(() {
            item.lastOpened = DateTime.now();
          });
          _saveData();
        },
      )),
    );

    if (returned != null && returned.existsSync()) {
      final exists = _allItems.any((it) => it is PdfFileItem && (it as PdfFileItem).file.path == returned.path);
      if (!exists) {
        setState(() {
          _allItems.add(PdfFileItem(
            id: FileService.generateFileId(), 
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
                  if (_currentFolder != null) {
                    _currentFolder!.items.remove(item);
                  } else {
                    _allItems.remove(item);
                  }
                  
                  if (item is PdfFolderItem) {
                    _removeFolderContents(item);
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

  void _removeFolderContents(PdfFolderItem folder) {
    for (final item in folder.items) {
      if (item is PdfFolderItem) {
        _removeFolderContents(item);
      }
      _allItems.remove(item);
    }
  }

  void _moveItem(FileSystemItem item) {
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
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Tüm Dosyalar (Root)'),
              onTap: () {
                Navigator.pop(ctx);
                _performMove(item, null);
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
    final allFolders = _allItems.whereType<PdfFolderItem>().toList();
    
    if (item is PdfFolderItem) {
      return allFolders.where((folder) {
        return folder.id != item.id && !_isSubfolder(folder, item);
      }).toList();
    }
    
    return allFolders;
  }

  bool _isSubfolder(PdfFolderItem potentialParent, PdfFolderItem potentialChild) {
    if (potentialChild.parentFolderId == potentialParent.id) return true;
    
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
        id: FileService.generateFolderId(), 
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
      if (item.parentFolderId != null) {
        final previousFolder = _allItems.whereType<PdfFolderItem>()
            .firstWhere((f) => f.id == item.parentFolderId);
        previousFolder.items.remove(item);
      } else {
        _allItems.remove(item);
      }
      
      item.parentFolderId = targetFolder?.id;
      
      if (targetFolder != null) {
        targetFolder.items.add(item);
      } else {
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
            leading: const Icon(Icons.favorite), 
            title: Text(item.isFavorite ? 'Favorilerden kaldır' : 'Favorilere ekle'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _toggleFavorite(item); 
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
                if (_currentFolder != null) {
                  _currentFolder!.items.remove(item);
                } else {
                  _allItems.remove(item);
                }
                _selectedItems.remove(item);
                
                if (item is PdfFolderItem) {
                  _removeFolderContents(item);
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

  void _openToolsPage() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => ToolsWebView(darkMode: _darkModeManual)),
      (route) => false,
    );
  }

  List<FileSystemItem> _getDisplayItems() {
    if (_currentFolder != null) {
      return _currentFolder!.items;
    }

    switch (_bottomIndex) {
      case 0: // All Files
        final folders = _allItems.whereType<PdfFolderItem>().toList();
        final files = _allItems.whereType<PdfFileItem>().toList();
        
        folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        
        return [...folders, ...files];
        
      case 1: // Recent
        final allFiles = _getAllPdfFiles();
        final recentFiles = allFiles.where((file) => file.lastOpened != null).toList();
        recentFiles.sort((a, b) => (b.lastOpened ?? DateTime(0)).compareTo(a.lastOpened ?? DateTime(0)));
        return recentFiles.take(20).toList();
        
      case 2: // Favorites
        final allFiles = _getAllPdfFiles();
        final favoriteFiles = allFiles.where((file) => file.isFavorite).toList();
        favoriteFiles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return favoriteFiles;
        
      default:
        return _allItems;
    }
  }

  List<PdfFileItem> _getAllPdfFiles() {
    final List<PdfFileItem> allFiles = [];
    
    void addFilesFromItems(List<FileSystemItem> items) {
      for (final item in items) {
        if (item is PdfFileItem) {
          allFiles.add(item);
        } else if (item is PdfFolderItem) {
          addFilesFromItems(item.items);
        }
      }
    }
    
    addFilesFromItems(_allItems);
    return allFiles;
  }

  Widget _buildFileItem(PdfFileItem item, bool isSelected) {
    return FileItemWidget(
      item: item,
      isSelected: isSelected,
      selectionMode: _selectionMode,
      darkMode: _darkModeManual,
      onTap: () {
        if (_selectionMode) {
          _toggleItemSelection(item);
        } else {
          _openFile(item);
        }
      },
      onLongPress: () => _toggleItemSelection(item),
      onToggleFavorite: () => _toggleFavorite(item),
      onShowMenu: () => _showFileMenu(item),
    );
  }

  Widget _buildFolderItem(PdfFolderItem item, bool isSelected) {
    return FolderItemWidget(
      item: item,
      isSelected: isSelected,
      selectionMode: _selectionMode,
      darkMode: _darkModeManual,
      onTap: () {
        if (_selectionMode) {
          _toggleItemSelection(item);
        } else {
          _openFolder(item);
        }
      },
      onLongPress: () => _toggleItemSelection(item),
      onShowMenu: () => _showFileMenu(item),
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
        child: Container(
          color: _darkModeManual ? Colors.black : Colors.white,
          child: SafeArea(
            child: Column(children: [
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: _darkModeManual ? Colors.black : Colors.red,
                ),
                child: Center(
                  child: Text('PDF Okuyucu & Yönetici', 
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white
                    )
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.cloud_upload, 
                  color: _darkModeManual ? Colors.white : Colors.black
                ), 
                title: Text('PDF İçe Aktar',
                  style: TextStyle(
                    color: _darkModeManual ? Colors.white : Colors.black
                  )
                ), 
                onTap: () { 
                  Navigator.pop(context); 
                  _importPdf(); 
                }
              ),
              ListTile(
                leading: Icon(Icons.create_new_folder,
                  color: _darkModeManual ? Colors.white : Colors.black
                ), 
                title: Text('Klasör Oluştur',
                  style: TextStyle(
                    color: _darkModeManual ? Colors.white : Colors.black
                  )
                ), 
                onTap: () { 
                  Navigator.pop(context); 
                  _createFolder(); 
                }
              ),
              ListTile(
                leading: Icon(Icons.info,
                  color: _darkModeManual ? Colors.white : Colors.black
                ), 
                title: Text('Hakkında',
                  style: TextStyle(
                    color: _darkModeManual ? Colors.white : Colors.black
                  )
                ), 
                onTap: () { 
                  Navigator.pop(context); 
                  _showAboutDialog(); 
                }
              ),
              SwitchListTile(
                secondary: Icon(
                  _darkModeManual ? Icons.light_mode : Icons.dark_mode,
                  color: _darkModeManual ? Colors.white : Colors.black,
                ),
                title: Text(_darkModeManual ? 'Açık Mod' : 'Karanlık Mod',
                  style: TextStyle(
                    color: _darkModeManual ? Colors.white : Colors.black
                  )
                ),
                value: _darkModeManual,
                onChanged: _toggleDarkMode,
              ),
              ListTile(
                leading: Icon(Icons.policy,
                  color: _darkModeManual ? Colors.white : Colors.black
                ), 
                title: Text('Gizlilik',
                  style: TextStyle(
                    color: _darkModeManual ? Colors.white : Colors.black
                  )
                ), 
                onTap: () { 
                  Navigator.pop(context); 
                  _notify('Gizlilik Politikası'); 
                }
              ),
              ListTile(
                leading: Icon(Icons.language,
                  color: _darkModeManual ? Colors.white : Colors.black
                ), 
                title: Text('Dil',
                  style: TextStyle(
                    color: _darkModeManual ? Colors.white : Colors.black
                  )
                ), 
                onTap: () { 
                  Navigator.pop(context); 
                  _notify('Dil Seçenekleri'); 
                }
              ),
            ]),
          ),
        ),
      ) : null,
      appBar: CustomAppBar(
        title: title,
        isSearching: _isSearching,
        searchController: _searchController,
        darkMode: _darkModeManual,
        leadingIcon: _buildLeadingIcon(),
        actions: _buildAppBarActions(),
        onSearchChanged: (_) => setState(() {}),
      ),
      body: _buildBody(),
      bottomNavigationBar: _currentFolder == null ? BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) { 
          setState(() { 
            _bottomIndex = i; 
            _selectionMode = false; 
            _selectedItems.clear(); 
            
            if (i == 3) {
              _openToolsPage();
            }
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
        icon: const Icon(Icons.close,
          color: Colors.white
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
        icon: const Icon(Icons.arrow_back,
          color: Colors.white
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
          icon: const Icon(Icons.select_all,
            color: Colors.white
          ),
          onPressed: _selectAllItems,
        ),
        IconButton(
          icon: const Icon(Icons.deselect,
            color: Colors.white
          ),
          onPressed: _deselectAllItems,
        ),
        IconButton(
          icon: const Icon(Icons.print,
            color: Colors.white
          ),
          onPressed: () => _printFiles(_selectedItems),
        ),
        IconButton(
          icon: const Icon(Icons.share,
            color: Colors.white
          ),
          onPressed: () => _shareFiles(_selectedItems),
        ),
        IconButton(
          icon: const Icon(Icons.delete,
            color: Colors.white
          ),
          onPressed: _deleteSelectedItems,
        ),
      ];
    }
    
    return [
      if (!_isSearching) ...[
        IconButton(
          icon: const Icon(Icons.create_new_folder,
            color: Colors.white
          ), 
          onPressed: _createFolder
        ),
        IconButton(
          icon: const Icon(Icons.search,
            color: Colors.white
          ), 
          onPressed: () { 
            setState(() => _isSearching = !_isSearching); 
            if (!_isSearching) _searchController.clear();
          }
        ),
        IconButton(
          icon: const Icon(Icons.sort,
            color: Colors.white
          ), 
          onPressed: _showSortSheet
        ),
        IconButton(
          icon: const Icon(Icons.select_all,
            color: Colors.white
          ), 
          onPressed: _toggleSelectionMode
        ),
      ],
    ];
  }

  Widget _buildBody() {
    if (_bottomIndex == 3) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build, size: 64, 
              color: _darkModeManual ? Colors.red : Colors.grey[400]
            ),
            const SizedBox(height: 16),
            Text(
              'Araçlar Sayfası',
              style: TextStyle(
                fontSize: 18, 
                color: _darkModeManual ? Colors.red : Colors.grey
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Araçları kullanmak için yukarıdaki butona tıklayın',
              style: TextStyle(
                color: _darkModeManual ? Colors.red : Colors.grey
              ),
            ),
          ],
        ),
      );
    }
    
    List<FileSystemItem> display = _getDisplayItems();
    
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      display = display.where((it) => it.name.toLowerCase().contains(q)).toList();
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
              _bottomIndex == 1 
                ? 'Henüz açılmış dosya yok' 
                : _bottomIndex == 2
                  ? 'Henüz favori dosya yok'
                  : 'Henüz dosya yok',
              style: TextStyle(
                fontSize: 18, 
                color: _darkModeManual ? Colors.red : Colors.grey
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _bottomIndex == 1
                ? 'PDF dosyalarını viewer ile açarak burada görebilirsiniz'
                : _bottomIndex == 2
                  ? 'PDF dosyalarını favorilere ekleyerek burada görebilirsiniz'
                  : 'Yeni PDF eklemek için + simgesine tıklayın',
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
}

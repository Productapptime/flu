// lib/main.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

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
        colorSchemeSeed: Colors.red,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
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
  FileSystemItem(this.id, this.name, {this.lastOpened, this.isFavorite = false});
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
  }) : super(id, name, lastOpened: lastOpened, isFavorite: isFavorite);
}

class PdfFolderItem extends FileSystemItem {
  Color color;
  List<PdfFileItem> files = [];
  
  PdfFolderItem({
    required String id,
    required String name,
    this.color = Colors.grey,
  }) : super(id, name);
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
  final List<FileSystemItem> _items = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _selectionMode = false;
  final List<FileSystemItem> _selectedItems = [];
  int _bottomIndex = 0;
  bool _darkModeManual = false;
  PdfFolderItem? _currentFolder;

  @override
  void initState() {
    super.initState();
    // Demo veriler kaldırıldı - tamamen boş başlıyor
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
            final id = 'file_${DateTime.now().millisecondsSinceEpoch}_${importedCount}';
            final name = p.basename(path);
            
            // Aynı dosya kontrolü
            final exists = _items.any((it) => it is PdfFileItem && (it as PdfFileItem).file.path == path);
            if (!exists) {
              setState(() {
                _items.add(PdfFileItem(
                  id: id, 
                  name: name, 
                  file: f,
                  folderId: _currentFolder?.id,
                ));
                
                // Eğer klasör içindeysek, klasöre de ekle
                if (_currentFolder != null) {
                  _currentFolder!.files.add(PdfFileItem(
                    id: id, 
                    name: name, 
                    file: f,
                    folderId: _currentFolder!.id,
                  ));
                }
              });
              importedCount++;
            }
          }
        }
        
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
        _items.insert(0, PdfFolderItem(
          id: 'folder_${DateTime.now().millisecondsSinceEpoch}', 
          name: name.trim()
        ));
      });
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
      _items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
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
              setState(() => _items.sort((a,b)=>b.name.toLowerCase().compareTo(a.name.toLowerCase()))); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Tarihe göre sırala'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _sortByDate(); 
            }
          ),
        ]),
      );
    });
  }

  void _sortByDate() {
    // Basit tarih sıralama örneği - gerçek uygulamada dosya tarihlerini kullanın
    setState(() {
      _items.shuffle(); // Demo amaçlı
    });
  }

  void _openFile(PdfFileItem item) async {
    // Dosyayı recent olarak işaretle
    setState(() {
      item.lastOpened = DateTime.now();
    });

    final returned = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => ViewerScreen(
        file: item.file,
        fileName: item.name,
        dark: _darkModeManual || MediaQuery.of(context).platformBrightness == Brightness.dark,
      )),
    );

    // Görüntüleyiciden dönen kayıtlı dosyayı işle
    if (returned != null && returned.existsSync()) {
      final exists = _items.any((it) => it is PdfFileItem && (it as PdfFileItem).file.path == returned.path);
      if (!exists) {
        setState(() {
          _items.add(PdfFileItem(
            id: 'file_${DateTime.now().millisecondsSinceEpoch}', 
            name: p.basename(returned.path), 
            file: returned,
            folderId: _currentFolder?.id,
          ));
        });
      }
    }
  }

  void _toggleFavorite(PdfFileItem item) {
    setState(() {
      item.isFavorite = !item.isFavorite;
    });
    
    _notify(item.isFavorite ? 'Favorilere eklendi' : 'Favorilerden kaldırıldı');
  }

  Future<void> _shareFile(PdfFileItem item) async {
    try {
      await Share.shareXFiles([XFile(item.file.path)],
        text: 'PDF Dosyası: ${item.name}'
      );
    } catch (e) {
      debugPrint('Share error: $e');
      _notify('Paylaşım başarısız');
    }
  }

  Future<void> _printFile(PdfFileItem item) async {
    try {
      final pdfData = await item.file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (format) => pdfData,
      );
    } catch (e) {
      debugPrint('Print error: $e');
      _notify('Yazdırma başarısız');
    }
  }

  void _moveItem(FileSystemItem item) {
    // Klasör seçimi için modal göster
    showModalBottomSheet(context: context, builder: (ctx) {
      final folders = _items.whereType<PdfFolderItem>().toList();
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Klasöre Taşı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (folders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Taşınabilecek klasör bulunmuyor'),
              )
            else
              ...folders.map((folder) => ListTile(
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

  void _createFolderForMove(FileSystemItem item) async {
    final name = await _showTextInput('Yeni klasör adı', '');
    if (name != null && name.trim().isNotEmpty) {
      final newFolder = PdfFolderItem(
        id: 'folder_${DateTime.now().millisecondsSinceEpoch}', 
        name: name.trim()
      );
      setState(() {
        _items.insert(0, newFolder);
      });
      _performMove(item, newFolder);
    }
  }

  void _performMove(FileSystemItem item, PdfFolderItem folder) {
    if (item is PdfFileItem) {
      setState(() {
        // Önceki konumdan kaldır
        _items.remove(item);
        
        // Klasör ID'sini güncelle
        item.folderId = folder.id;
        
        // Klasöre ekle
        folder.files.add(item);
        
        // Ana listede en üste taşı (klasörlerin altında)
        final folderIndex = _items.indexWhere((it) => it is PdfFolderItem && it.id == folder.id);
        if (folderIndex != -1) {
          _items.insert(folderIndex + 1, item);
        } else {
          _items.insert(0, item);
        }
      });
      _notify('"${item.name}" "${folder.name}" klasörüne taşındı');
    }
  }

  void _openFolder(PdfFolderItem folder) {
    setState(() {
      _currentFolder = folder;
    });
  }

  void _exitFolder() {
    setState(() {
      _currentFolder = null;
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
              _printFile(item); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.share), 
            title: const Text('Paylaş'), 
            onTap: () { 
              Navigator.pop(ctx); 
              _shareFile(item); 
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
                _items.remove(item);
                _selectedItems.remove(item);
                
                // Eğer bir klasör siliniyorsa, içindeki dosyaları da ana listeden kaldır
                if (item is PdfFolderItem) {
                  _items.removeWhere((it) => it is PdfFileItem && (it as PdfFileItem).folderId == item.id);
                }
              });
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
    if (chosen != null) setState(() => folder.color = chosen);
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
      drawer: _currentFolder == null ? Drawer(
        child: SafeArea(
          child: Column(children: [
            DrawerHeader(
              child: Text('PDF Okuyucu & Yönetici', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white)),
              decoration: BoxDecoration(color: theme.colorScheme.primary)
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload), 
              title: const Text('PDF İçe Aktar'), 
              onTap: () { 
                Navigator.pop(context); 
                _importPdf(); 
              }
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder), 
              title: const Text('Klasör Oluştur'), 
              onTap: () { 
                Navigator.pop(context); 
                _createFolder(); 
              }
            ),
            ListTile(
              leading: const Icon(Icons.info), 
              title: const Text('Hakkında'), 
              onTap: () { 
                Navigator.pop(context); 
                _showAboutDialog(); 
              }
            ),
            SwitchListTile(
              secondary: Icon(_darkModeManual ? Icons.light_mode : Icons.dark_mode),
              title: Text(_darkModeManual ? 'Açık Mod' : 'Karanlık Mod'),
              value: _darkModeManual,
              onChanged: (v) {
                setState(() { _darkModeManual = v; });
                _notify('${v ? 'Açık' : 'Karanlık'} mod ${v ? 'açıldı' : 'kapatıldı'}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.policy), 
              title: const Text('Gizlilik Politikası'), 
              onTap: () { 
                Navigator.pop(context); 
                _notify('Gizlilik Politikası'); 
              }
            ),
            ListTile(
              leading: const Icon(Icons.language), 
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
        leading: _currentFolder != null 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _exitFolder,
              )
            : null,
        actions: [
          if (_currentFolder == null) ...[
            IconButton(
              icon: const Icon(Icons.search), 
              onPressed: () { 
                setState(() => _isSearching = !_isSearching); 
                if (!_isSearching) _searchController.clear();
              }
            ),
            IconButton(
              icon: const Icon(Icons.create_new_folder), 
              onPressed: _createFolder
            ),
            IconButton(
              icon: const Icon(Icons.sort), 
              onPressed: _showSortSheet
            ),
            IconButton(
              icon: _selectionMode ? const Icon(Icons.check_box) : const Icon(Icons.check_box_outline_blank), 
              onPressed: _toggleSelectionMode
            ),
          ],
        ],
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
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Tüm Dosyalar'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Son'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoriler'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Araçlar'),
        ],
      ) : null,
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        hintText: 'Dosyalarda ara...', 
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white70)
      ),
      style: const TextStyle(color: Colors.white),
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
            Icon(Icons.construction, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Araçlar sekmesi - Yakında',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
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
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Henüz dosya yok',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'İçe aktarmak için menüyü kullanın',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: display.length,
      separatorBuilder: (_,__) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final it = display[i];
        final isSelected = _selectedItems.contains(it);
        
        if (it is PdfFolderItem) {
          return ListTile(
            leading: Icon(Icons.folder, color: it.color),
            title: Text(it.name),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert), 
              onPressed: () => _showFileMenu(it)
            ),
            onTap: () {
              if (_selectionMode) _toggleSelect(it);
              else _openFolder(it);
            },
            tileColor: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
          );
        } else if (it is PdfFileItem) {
          return ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: Text(it.name),
            subtitle: Text(it.file.path, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    it.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: it.isFavorite ? Colors.red : Colors.grey,
                  ),
                  onPressed: () => _toggleFavorite(it),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert), 
                  onPressed: () => _showFileMenu(it)
                ),
              ],
            ),
            onTap: () {
              if (_selectionMode) _toggleSelect(it);
              else _openFile(it);
            },
            tileColor: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  List<FileSystemItem> _getDisplayItems() {
    if (_currentFolder != null) {
      return _currentFolder!.files.cast<FileSystemItem>().toList();
    }
    
    switch (_bottomIndex) {
      case 0: // Tüm Dosyalar
        final folders = _items.whereType<PdfFolderItem>().toList();
        final files = _items.whereType<PdfFileItem>().where((f) => f.folderId == null).toList();
        return [...folders, ...files];
        
      case 1: // Son Görüntülenenler
        final allFiles = _items.whereType<PdfFileItem>().toList();
        allFiles.sort((a, b) {
          if (a.lastOpened == null && b.lastOpened == null) return 0;
          if (a.lastOpened == null) return 1;
          if (b.lastOpened == null) return -1;
          return b.lastOpened!.compareTo(a.lastOpened!);
        });
        return allFiles.take(20).toList();
        
      case 2: // Favoriler
        return _items.whereType<PdfFileItem>().where((f) => f.isFavorite).toList();
        
      default:
        return [];
    }
  }

  void _toggleSelect(FileSystemItem item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        _selectedItems.add(item);
      }
    });
  }
}

/* ----------------------
   Viewer screen
---------------------- */

class ViewerScreen extends StatefulWidget {
  final File file;
  final String fileName;
  final bool dark;
  const ViewerScreen({super.key, required this.file, required this.fileName, this.dark = false});

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
      final savedName = 'kaydedilmis_$originalName';
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
          backgroundColor: Colors.red,
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
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
            Container(color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.transparent),
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
              const Center(child: CircularProgressIndicator(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

// lib/screens/home_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../models/file_system_item.dart';
import '../models/pdf_file_item.dart';
import '../models/pdf_folder_item.dart';
import '../services/data_persistence.dart';
import '../services/file_service.dart';
import 'viewer_screen.dart';
import 'tools_webview.dart';
import '../widgets/file_item.dart';
import '../widgets/folder_item.dart';
import '../widgets/custom_app_bar.dart';

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
          _allItems.add(newFile);
          
          if (_currentFolder != null) {
            _currentFolder!.items.add(newFile);
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
    // ✅ SADECE ViewerScreen'de viewer.html ile açıldığında lastOpened güncellenecek
    final returned = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => ViewerScreen(
        file: item.file,
        fileName: item.name,
        dark: _darkModeManual,
        onFileOpened: () {
          // ✅ SADECE BURADA: Viewer.html ile açıldığında lastOpened güncelle
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
                  _allItems.remove(item);
                  
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

  // ✅ Tools sayfasını açma metodu
  void _openToolsPage() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => ToolsWebView(darkMode: _darkModeManual)),
      (route) => false, // Tüm önceki sayfaları temizle
    );
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
        // ✅ KRİTİK DÜZELTME: Sadece lastOpened değeri null olmayan dosyaları göster
        final recentFiles = files.where((file) => file.lastOpened != null).toList();
        recentFiles.sort((a, b) => (b.lastOpened ?? DateTime(0)).compareTo(a.lastOpened ?? DateTime(0)));
        return recentFiles.take(20).toList();
      case 2: // Favorites
        return _allItems.where((it) => it is PdfFileItem && (it as PdfFileItem).isFavorite).toList();
      default:
        return _allItems;
    }
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
            
            // ✅ Tools sayfasına tıklanırsa aç
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

  Widget _buildBody() {
    // ✅ Tools sayfasına tıklandığında boş bir sayfa göster (çünkü ToolsWebView ayrı açılacak)
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

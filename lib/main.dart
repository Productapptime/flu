// lib/main.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(const PdfManagerApp());
}

/// İzinleri iste (Android 11+ için manageExternalStorage)
Future<void> _requestPermissions() async {
  await [
    Permission.manageExternalStorage,
    Permission.storage,
  ].request();
}

/// Sıralama seçenekleri
enum SortMode { nameAsc, nameDesc, sizeAsc, sizeDesc, dateAsc, dateDesc }

/// Ana uygulama
class PdfManagerApp extends StatefulWidget {
  const PdfManagerApp({super.key});

  @override
  State<PdfManagerApp> createState() => _PdfManagerAppState();
}

class _PdfManagerAppState extends State<PdfManagerApp> {
  ThemeMode _themeMode = ThemeMode.light;
  String _language = 'en';

  // Kalıcı saklama (paths)
  List<String> _allPaths = [];
  List<String> _recentPaths = [];
  List<String> _favoritePaths = [];

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _allPaths = prefs.getStringList('allFiles') ?? [];
      _recentPaths = prefs.getStringList('recentFiles') ?? [];
      _favoritePaths = prefs.getStringList('favoriteFiles') ?? [];
    });
  }

  Future<void> _saveLists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('allFiles', _allPaths);
    await prefs.setStringList('recentFiles', _recentPaths);
    await prefs.setStringList('favoriteFiles', _favoritePaths);
  }

  void _toggleTheme(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  void _setLanguage(String lang) {
    setState(() => _language = lang);
    ScaffoldMessenger.maybeOf(navigatorKey.currentContext!)?.showSnackBar(
      SnackBar(content: Text('Language set to ${lang.toUpperCase()}')),
    );
  }

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PDF Manager Plus',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: PdfHomePage(
        allPaths: _allPaths,
        recentPaths: _recentPaths,
        favoritePaths: _favoritePaths,
        onListsChanged: (all, recent, fav) {
          setState(() {
            _allPaths = all;
            _recentPaths = recent;
            _favoritePaths = fav;
          });
          _saveLists();
        },
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
        language: _language,
        onLanguageChange: _setLanguage,
      ),
    );
  }
}

/// Ana ekran
class PdfHomePage extends StatefulWidget {
  final List<String> allPaths;
  final List<String> recentPaths;
  final List<String> favoritePaths;
  final Function(List<String> all, List<String> recent, List<String> fav) onListsChanged;
  final bool isDark;
  final Function(bool) onToggleTheme;
  final String language;
  final Function(String) onLanguageChange;

  const PdfHomePage({
    super.key,
    required this.allPaths,
    required this.recentPaths,
    required this.favoritePaths,
    required this.onListsChanged,
    required this.isDark,
    required this.onToggleTheme,
    required this.language,
    required this.onLanguageChange,
  });

  @override
  State<PdfHomePage> createState() => _PdfHomePageState();
}

class _PdfHomePageState extends State<PdfHomePage> {
  // Local copy of lists (paths)
  late List<String> _all;
  late List<String> _recent;
  late List<String> _fav;

  // UI state
  int _selectedIndex = 0;
  String _searchQuery = '';
  SortMode _sortMode = SortMode.nameAsc;
  bool _selectionMode = false;
  final Set<String> _selectedPaths = {};
  List<String> _displayList = [];

  @override
  void initState() {
    super.initState();
    _all = List.from(widget.allPaths);
    _recent = List.from(widget.recentPaths);
    _fav = List.from(widget.favoritePaths);
    _rebuildDisplay();
  }

  void _syncAndSave() {
    widget.onListsChanged(List.from(_all), List.from(_recent), List.from(_fav));
  }

  // Import file with FilePicker
  Future<void> _importFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        if (!_all.contains(path)) {
          setState(() {
            _all.add(path);
            _rebuildDisplay();
          });
          _syncAndSave();
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported: ${p.basename(path)}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  // Add to recent only when viewer actually opens (Viewer will call onViewed)
  void _addToRecent(String path) {
    setState(() {
      _recent.remove(path);
      _recent.insert(0, path);
      _rebuildDisplay();
    });
    _syncAndSave();
  }

  // Toggle favorite
  void _toggleFavorite(String path) {
    setState(() {
      if (_fav.contains(path)) {
        _fav.remove(path);
      } else {
        _fav.add(path);
      }
    });
    _syncAndSave();
  }

  // Delete selected files from lists (does not delete actual file)
  void _deleteSelected() {
    if (_selectedPaths.isEmpty) return;
    setState(() {
      _all.removeWhere((p) => _selectedPaths.contains(p));
      _recent.removeWhere((p) => _selectedPaths.contains(p));
      _fav.removeWhere((p) => _selectedPaths.contains(p));
      _selectedPaths.clear();
      _selectionMode = false;
      _rebuildDisplay();
    });
    _syncAndSave();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected removed from lists')));
  }

  // Add selected to favorites
  void _favoriteSelected() {
    if (_selectedPaths.isEmpty) return;
    setState(() {
      for (var s in _selectedPaths) {
        if (!_fav.contains(s)) _fav.add(s);
      }
      _selectedPaths.clear();
      _selectionMode = false;
      _rebuildDisplay();
    });
    _syncAndSave();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected added to favorites')));
  }

  // Create folder inside app documents (simülasyon olarak gerçek klasör oluşturur)
  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final dir = await getApplicationDocumentsDirectory();
              final newDir = Directory(p.join(dir.path, name));
              if (!await newDir.exists()) await newDir.create(recursive: true);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Folder created: ${newDir.path}')));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // Sort list
  void _applySort(List<String> list) {
    list.sort((a, b) {
      switch (_sortMode) {
        case SortMode.nameAsc:
          return p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase());
        case SortMode.nameDesc:
          return p.basename(b).toLowerCase().compareTo(p.basename(a).toLowerCase());
        case SortMode.sizeAsc:
          final sa = File(a).existsSync() ? File(a).lengthSync() : 0;
          final sb = File(b).existsSync() ? File(b).lengthSync() : 0;
          return sa.compareTo(sb);
        case SortMode.sizeDesc:
          final sa2 = File(a).existsSync() ? File(a).lengthSync() : 0;
          final sb2 = File(b).existsSync() ? File(b).lengthSync() : 0;
          return sb2.compareTo(sa2);
        case SortMode.dateAsc:
          final da = File(a).existsSync() ? File(a).statSync().modified : DateTime.fromMillisecondsSinceEpoch(0);
          final db = File(b).existsSync() ? File(b).statSync().modified : DateTime.fromMillisecondsSinceEpoch(0);
          return da.compareTo(db);
        case SortMode.dateDesc:
          final da2 = File(a).existsSync() ? File(a).statSync().modified : DateTime.fromMillisecondsSinceEpoch(0);
          final db2 = File(b).existsSync() ? File(b).statSync().modified : DateTime.fromMillisecondsSinceEpoch(0);
          return db2.compareTo(da2);
      }
    });
  }

  // Build display list according to selected tab and search
  void _rebuildDisplay() {
    List<String> base;
    switch (_selectedIndex) {
      case 1:
        base = List.from(_recent);
        break;
      case 2:
        base = List.from(_fav);
        break;
      default:
        base = List.from(_all);
    }

    // filter by search
    if (_searchQuery.isNotEmpty) {
      base = base.where((p) => p.toLowerCase().contains(_searchQuery.toLowerCase()) || p.basename(p).toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // sort
    _applySort(base);

    setState(() {
      _displayList = base;
    });
  }

  // Format bytes to MB string
  String _formatSize(String path) {
    try {
      if (!File(path).existsSync()) return '—';
      final bytes = File(path).lengthSync();
      final mb = bytes / (1024 * 1024);
      if (mb < 0.001) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${mb.toStringAsFixed(2)} MB';
    } catch (_) {
      return '—';
    }
  }

  // Format modified time
  String _formatTime(String path) {
    try {
      if (!File(path).existsSync()) return '—';
      final dt = File(path).statSync().modified.toLocal();
      return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
    } catch (_) {
      return '—';
    }
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  // Search dialog / action
  Future<void> _startSearch() async {
    final ctrl = TextEditingController(text: _searchQuery);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search files'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Enter filename'),
          autofocus: true,
          onSubmitted: (_) => Navigator.pop(ctx),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchQuery = ctrl.text.trim();
                _rebuildDisplay();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  // Sort menu
  Future<void> _showSortMenu() async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Sort by')),
            RadioListTile<SortMode>(
              title: const Text('Name ↑'),
              value: SortMode.nameAsc,
              groupValue: _sortMode,
              onChanged: (v) => setState(() { _sortMode = v!; _rebuildDisplay(); Navigator.pop(ctx); }),
            ),
            RadioListTile<SortMode>(
              title: const Text('Name ↓'),
              value: SortMode.nameDesc,
              groupValue: _sortMode,
              onChanged: (v) => setState(() { _sortMode = v!; _rebuildDisplay(); Navigator.pop(ctx); }),
            ),
            RadioListTile<SortMode>(
              title: const Text('Size ↑'),
              value: SortMode.sizeAsc,
              groupValue: _sortMode,
              onChanged: (v) => setState(() { _sortMode = v!; _rebuildDisplay(); Navigator.pop(ctx); }),
            ),
            RadioListTile<SortMode>(
              title: const Text('Size ↓'),
              value: SortMode.sizeDesc,
              groupValue: _sortMode,
              onChanged: (v) => setState(() { _sortMode = v!; _rebuildDisplay(); Navigator.pop(ctx); }),
            ),
            RadioListTile<SortMode>(
              title: const Text('Date ↑'),
              value: SortMode.dateAsc,
              groupValue: _sortMode,
              onChanged: (v) => setState(() { _sortMode = v!; _rebuildDisplay(); Navigator.pop(ctx); }),
            ),
            RadioListTile<SortMode>(
              title: const Text('Date ↓'),
              value: SortMode.dateDesc,
              groupValue: _sortMode,
              onChanged: (v) => setState(() { _sortMode = v!; _rebuildDisplay(); Navigator.pop(ctx); }),
            ),
          ],
        ),
      ),
    );
  }

  // Toggle selection mode
  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedPaths.clear();
    });
  }

  // Tap on file (either select or open)
  void _onFileTap(String path) {
    if (_selectionMode) {
      setState(() {
        if (_selectedPaths.contains(path)) _selectedPaths.remove(path); else _selectedPaths.add(path);
      });
      return;
    }
    // open viewer
    _openViewer(path);
  }

  // Open viewer and add to recent (viewer will call back)
  Future<void> _openViewer(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File not found')));
      return;
    }

    final result = await Navigator.push<File?>(
      context,
      MaterialPageRoute(
        builder: (_) => ViewerScreen(
          file: file,
          fileName: p.basename(path),
          dark: widget.isDark,
          onViewed: () {
            // viewer informs us (file rendered) -> add to recent
            _addToRecent(path);
          },
        ),
      ),
    );

    // If viewer returned a saved file, optionally handle it (ignored here)
    if (result != null) {
      // If saved file path is new, add to all
      final newPath = result.path;
      if (!_all.contains(newPath)) {
        setState(() {
          _all.add(newPath);
          _rebuildDisplay();
        });
        _syncAndSave();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ensure display built for current selection
    _rebuildDisplay();

    final titles = ['All Files', 'Recent', 'Favorites', 'Tools'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
          IconButton(icon: const Icon(Icons.create_new_folder_outlined), onPressed: _createFolder),
          IconButton(icon: const Icon(Icons.sort), onPressed: _showSortMenu),
          IconButton(icon: Icon(_selectionMode ? Icons.check_box : Icons.select_all), onPressed: _toggleSelectionMode),
          if (_selectionMode) // selection actions in appbar when in selection mode
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'fav') _favoriteSelected();
                if (v == 'del') _deleteSelected();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'fav', child: Text('Add to Favorites')),
                const PopupMenuItem(value: 'del', child: Text('Remove from lists')),
              ],
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.indigo),
              child: Align(alignment: Alignment.centerLeft, child: Text('PDF Manager Plus', style: TextStyle(color: Colors.white, fontSize: 22))),
            ),
            ListTile(leading: const Icon(Icons.info_outline), title: const Text('About'), onTap: () {
              Navigator.pop(context);
              showAboutDialog(context: context, applicationName: 'PDF Manager Plus', applicationVersion: '1.0', children: [const Text('Built with Flutter + PDF.js (InAppWebView)')]);
            }),
            ListTile(leading: const Icon(Icons.upload_file), title: const Text('Import File'), onTap: () { Navigator.pop(context); _importFile(); }),
            SwitchListTile(
              secondary: const Icon(Icons.brightness_6),
              title: const Text('Dark / Light Mode'),
              value: widget.isDark,
              onChanged: (v) { Navigator.pop(context); widget.onToggleTheme(v); },
            ),
            ListTile(leading: const Icon(Icons.language), title: const Text('Language'), subtitle: Text(widget.language.toUpperCase()), onTap: () {
              Navigator.pop(context);
              showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('Select Language'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(leading: const Icon(Icons.language), title: const Text('English'), onTap: () { widget.onLanguageChange('en'); Navigator.pop(context); }),
                  ListTile(leading: const Icon(Icons.language), title: const Text('Türkçe'), onTap: () { widget.onLanguageChange('tr'); Navigator.pop(context); }),
                ]),
              ));
            }),
          ],
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        onTap: (i) { setState(() { _selectedIndex = i; _rebuildDisplay(); _selectionMode = false; _selectedPaths.clear(); }); },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'All Files'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Recent'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Tools'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedIndex == 3) {
      // Tools placeholder (you may load assets/web/*.html inside WebView here)
      return Center(child: Text('Tools coming soon...'));
    }

    return _displayList.isEmpty
        ? const Center(child: Text('No files'))
        : ListView.builder(
            itemCount: _displayList.length,
            itemBuilder: (ctx, idx) {
              final path = _displayList[idx];
              final filename = p.basename(path);
              final sizeStr = _formatSize(path);
              final timeStr = _formatTime(path);
              final isFav = _fav.contains(path);

              return ListTile(
                leading: _selectionMode
                    ? Checkbox(value: _selectedPaths.contains(path), onChanged: (_) => setState(() {
                        if (_selectedPaths.contains(path)) _selectedPaths.remove(path); else _selectedPaths.add(path);
                      }))
                    : const Icon(Icons.picture_as_pdf, color: Colors.indigo),
                title: Text(filename),
                subtitle: Text('$sizeStr • $timeStr'),
                trailing: IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null),
                  onPressed: () => _toggleFavorite(path),
                ),
                onTap: () => _onFileTap(path),
              );
            },
          );
  }
}

/// ViewerScreen — viewer.html ile açar; viewer çağrıldığında onViewed() callback ile recent'e eklenir.
class ViewerScreen extends StatefulWidget {
  final File file;
  final String fileName;
  final bool dark;
  final VoidCallback onViewed;

  const ViewerScreen({super.key, required this.file, required this.fileName, required this.dark, required this.onViewed});

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
    // viewer açıldıktan sonra callback ile recent'e ekleme yapıyoruz:
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onViewed();
    });
  }

  String _makeViewerUrl() {
    final fileUri = Uri.file(widget.file.path).toString();
    final dark = widget.dark ? 'true' : 'false';
    return 'file:///android_asset/flutter_assets/assets/web/viewer.html?file=${Uri.encodeComponent(fileUri)}&dark=$dark';
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
        final f = await widget.file.copy(newPath);
        _savedFile = f;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.basename(_savedFile!.path)} kaydedildi')));
    } catch (e) {
      debugPrint('onPdfSaved error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydetme başarısız')));
    }
  }

  Future<void> _printFile() async {
    try {
      final pdfData = await widget.file.readAsBytes();
      await Printing.layoutPdf(onLayout: (format) => pdfData);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yazdırma başarısız')));
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
          actions: [
            IconButton(icon: Icon(Icons.print, color: widget.dark ? Colors.red : Colors.white), onPressed: _printFile),
            IconButton(
                icon: Icon(Icons.share, color: widget.dark ? Colors.red : Colors.white),
                onPressed: () async {
                  try {
                    await Share.shareXFiles([XFile(widget.file.path)], text: 'PDF Dosyası: ${widget.fileName}');
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paylaşım başarısız')));
                  }
                }),
          ],
        ),
        body: Stack(
          children: [
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
              onWebViewCreated: (controller) {
                _controller = controller;
                controller.addJavaScriptHandler(handlerName: "onPdfSaved", callback: (args) {
                  _handleOnPdfSaved(args);
                });
              },
              onLoadStop: (controller, url) => setState(() => _loaded = true),
              onConsoleMessage: (controller, message) => debugPrint('WEBVIEW: ${message.message}'),
              onLoadError: (controller, url, code, message) => debugPrint('WEBVIEW LOAD ERROR ($code): $message'),
            ),
            if (!_loaded) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

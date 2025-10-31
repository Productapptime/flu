import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PdfManagerApp());
}

class PdfManagerApp extends StatefulWidget {
  const PdfManagerApp({super.key});
  @override
  State<PdfManagerApp> createState() => _PdfManagerAppState();
}

class _PdfManagerAppState extends State<PdfManagerApp> {
  ThemeMode _themeMode = ThemeMode.light;
  void toggleTheme(bool dark) => setState(() => _themeMode = dark ? ThemeMode.dark : ThemeMode.light);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager Plus',
      theme: ThemeData(primarySwatch: Colors.red, brightness: Brightness.light),
      darkTheme: ThemeData(primarySwatch: Colors.red, brightness: Brightness.dark),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: HomePage(dark: _themeMode == ThemeMode.dark, onThemeChanged: toggleTheme),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool dark;
  final Function(bool) onThemeChanged;
  const HomePage({super.key, required this.dark, required this.onThemeChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _selectionMode = false;
  List<String> _selectedFiles = [];
  List<String> _allFiles = [];
  List<String> _favorites = [];
  List<String> _recent = [];
  String _searchQuery = '';
  String _sortMode = 'Name';

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _allFiles = prefs.getStringList('allFiles') ?? [];
      _favorites = prefs.getStringList('favorites') ?? [];
      _recent = prefs.getStringList('recent') ?? [];
    });
  }

  Future<void> _saveLists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('allFiles', _allFiles);
    await prefs.setStringList('favorites', _favorites);
    await prefs.setStringList('recent', _recent);
  }

  Future<void> _importFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (res != null && res.files.single.path != null) {
      final path = res.files.single.path!;
      if (!_allFiles.contains(path)) {
        _allFiles.add(path);
        await _saveLists();
        setState(() {});
      }
    }
  }

  void _openViewer(String path) async {
    final file = File(path);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewerScreen(
          file: file,
          fileName: p.basename(path),
          dark: widget.dark,
        ),
      ),
    );
    if (!_recent.contains(path)) {
      _recent.insert(0, path);
      await _saveLists();
    }
  }

  void _toggleFavorite(String path) async {
    if (_favorites.contains(path)) {
      _favorites.remove(path);
    } else {
      _favorites.add(path);
    }
    await _saveLists();
    setState(() {});
  }

  List<String> _getCurrentList() {
    List<String> base;
    switch (_selectedIndex) {
      case 0:
        base = _allFiles;
        break;
      case 1:
        base = _recent;
        break;
      case 2:
        base = _favorites;
        break;
      default:
        base = [];
    }

    if (_searchQuery.isNotEmpty) {
      base = base
          .where((path) => p.basename(path)
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_sortMode == 'Size') {
      base.sort((a, b) {
        final fa = File(a);
        final fb = File(b);
        if (!fa.existsSync() || !fb.existsSync()) return 0;
        return fb.lengthSync().compareTo(fa.lengthSync());
      });
    } else if (_sortMode == 'Date') {
      base.sort((a, b) {
        final fa = File(a);
        final fb = File(b);
        if (!fa.existsSync() || !fb.existsSync()) return 0;
        return fb.lastModifiedSync().compareTo(fa.lastModifiedSync());
      });
    } else {
      base.sort((a, b) => p.basename(a).compareTo(p.basename(b)));
    }
    return base;
  }

  // ✅ Gerçek klasör oluşturma ve listeye ekleme
  Future<void> _createFolder() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final folderName = controller.text.trim();
              if (folderName.isEmpty) return;

              if (await Permission.manageExternalStorage.request().isGranted ||
                  await Permission.storage.request().isGranted) {
                final baseDir =
                    Directory('/storage/emulated/0/Download/PDFManagerPlus');
                if (!(await baseDir.exists())) {
                  await baseDir.create(recursive: true);
                }

                final newDir = Directory('${baseDir.path}/$folderName');
                if (!(await newDir.exists())) {
                  await newDir.create(recursive: true);
                  if (!_allFiles.contains(newDir.path)) {
                    _allFiles.add(newDir.path);
                    await _saveLists();
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Klasör "${p.basename(newDir.path)}" oluşturuldu.')));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Bu isimde bir klasör zaten var.')));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Depolama izni verilmedi.')));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedFiles.contains(path)) {
        _selectedFiles.remove(path);
      } else {
        _selectedFiles.add(path);
      }
    });
  }

  void _deleteSelected() {
    setState(() {
      _allFiles.removeWhere((e) => _selectedFiles.contains(e));
      _favorites.removeWhere((e) => _selectedFiles.contains(e));
      _recent.removeWhere((e) => _selectedFiles.contains(e));
      _selectedFiles.clear();
      _selectionMode = false;
    });
    _saveLists();
  }

  @override
  Widget build(BuildContext context) {
    final files = _getCurrentList();
    final titles = ['All Files', 'Recent', 'Favorites', 'Tools'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final text = await showSearch<String>(
                context: context,
                delegate: FileSearchDelegate(initial: _searchQuery),
              );
              if (text != null) setState(() => _searchQuery = text);
            },
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _createFolder,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (val) => setState(() => _sortMode = val),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Name', child: Text('Sort by Name')),
              PopupMenuItem(value: 'Size', child: Text('Sort by Size')),
              PopupMenuItem(value: 'Date', child: Text('Sort by Date')),
            ],
          ),
          IconButton(
            icon:
                Icon(_selectionMode ? Icons.delete : Icons.select_all_outlined),
            onPressed: () {
              if (_selectionMode && _selectedFiles.isNotEmpty) {
                _deleteSelected();
              } else {
                setState(() => _selectionMode = !_selectionMode);
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.red),
              child: Text('PDF Manager Menu',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'PDF Manager Plus',
                applicationVersion: '4.3',
                children: const [Text('Developed by Arvin')],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Import File'),
              onTap: _importFile,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.brightness_6),
              title: const Text('Dark / Light Mode'),
              value: widget.dark,
              onChanged: widget.onThemeChanged,
            ),
            const ListTile(
              leading: Icon(Icons.language),
              title: Text('Language (Coming Soon)'),
            ),
          ],
        ),
      ),
      body: ListView.builder(
        itemCount: files.length,
        itemBuilder: (_, i) {
          final path = files[i];
          final isDir = Directory(path).existsSync();
          final icon = isDir ? Icons.folder : Icons.picture_as_pdf;
          final color = isDir ? Colors.grey : Colors.red;

          String subtitle = '';
          if (!isDir) {
            final f = File(path);
            final sizeMb = (f.lengthSync() / 1024 / 1024).toStringAsFixed(2);
            final modified =
                DateFormat('dd.MM.yyyy HH:mm').format(f.lastModifiedSync());
            subtitle = '$sizeMb MB • $modified';
          }

          final selected = _selectedFiles.contains(path);
          return ListTile(
            leading:
                Icon(selected ? Icons.check_circle : icon, color: color),
            title: Text(p.basename(path)),
            subtitle: Text(isDir ? 'Folder' : subtitle),
            trailing: isDir
                ? null
                : IconButton(
                    icon: Icon(
                      _favorites.contains(path)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: Colors.red,
                    ),
                    onPressed: () => _toggleFavorite(path),
                  ),
            onTap: () {
              if (_selectionMode) {
                _toggleSelection(path);
              } else if (isDir) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FolderViewScreen(folderPath: path),
                  ),
                );
              } else {
                _openViewer(path);
              }
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'All'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Recent'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favs'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Tools'),
        ],
      ),
    );
  }
}

class FileSearchDelegate extends SearchDelegate<String> {
  final String initial;
  FileSearchDelegate({required this.initial}) {
    query = initial;
  }

  @override
  List<Widget>? buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, query));
  @override
  Widget buildResults(BuildContext context) => Container();
  @override
  Widget buildSuggestions(BuildContext context) => Container();
}

// 📂 Klasör içeriği
class FolderViewScreen extends StatelessWidget {
  final String folderPath;
  const FolderViewScreen({super.key, required this.folderPath});

  @override
  Widget build(BuildContext context) {
    final dir = Directory(folderPath);
    final files = dir.existsSync() ? dir.listSync() : [];
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(folderPath))),
      body: files.isEmpty
          ? const Center(child: Text('This folder is empty'))
          : ListView(
              children: files.map((f) {
                final isDir = FileSystemEntity.isDirectorySync(f.path);
                return ListTile(
                  leading: Icon(isDir ? Icons.folder : Icons.picture_as_pdf),
                  title: Text(p.basename(f.path)),
                );
              }).toList(),
            ),
    );
  }
}

// 📖 PDF görüntüleme
class ViewerScreen extends StatefulWidget {
  final File file;
  final String fileName;
  final bool dark;
  const ViewerScreen(
      {super.key, required this.file, required this.fileName, required this.dark});
  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  InAppWebViewController? _controller;
  bool _loaded = false;
  String _viewerUrl() {
    final fileUri = Uri.file(widget.file.path).toString();
    final dark = widget.dark ? 'true' : 'false';
    return 'file:///android_asset/flutter_assets/assets/web/viewer.html?file=${Uri.encodeComponent(fileUri)}&dark=$dark';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: widget.dark ? Colors.black : Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.print),
              onPressed: () async {
                final bytes = await widget.file.readAsBytes();
                await Printing.layoutPdf(onLayout: (_) => bytes);
              }),
          IconButton(
              icon: const Icon(Icons.share),
              onPressed: () =>
                  Share.shareXFiles([XFile(widget.file.path)])),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_viewerUrl())),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              allowFileAccess: true,
              allowUniversalAccessFromFileURLs: true,
              supportZoom: true,
              useHybridComposition: true,
            ),
            onLoadStop: (_, __) => setState(() => _loaded = true),
          ),
          if (!_loaded)
            const Center(child: CircularProgressIndicator(color: Colors.red)),
        ],
      ),
    );
  }
}

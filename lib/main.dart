// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

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

  void toggleTheme(bool dark) {
    setState(() {
      _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager Plus',
      theme: ThemeData(
        primarySwatch: Colors.red,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.red,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: HomePage(
        dark: _themeMode == ThemeMode.dark,
        onThemeChanged: toggleTheme,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool dark;
  final Function(bool) onThemeChanged;

  const HomePage({
    super.key,
    required this.dark,
    required this.onThemeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _selectionMode = false;
  List<String> _selectedFiles = [];
  List<String> _allFiles = [];
  List<String> _folders = [];
  List<String> _favorites = [];
  List<String> _recent = [];
  String _searchQuery = '';
  String _sortMode = 'Name';
  String? _currentPath;
  Directory? _baseDir;

  @override
  void initState() {
    super.initState();
    _initDir();
  }

  Future<void> _initDir() async {
    _baseDir = await getApplicationDocumentsDirectory();
    _currentPath = _baseDir!.path;
    await _loadLists();
    await _scanFilesAndFolders();
  }

  Future<void> _scanFilesAndFolders() async {
    if (_currentPath == null) return;
    
    final List<String> pdfPaths = [];
    final List<String> folderPaths = [];
    
    final dir = Directory(_currentPath!);
    final entities = dir.listSync();
    
    for (var e in entities) {
      if (e is File && e.path.toLowerCase().endsWith('.pdf')) {
        pdfPaths.add(e.path);
      } else if (e is Directory) {
        folderPaths.add(e.path);
      }
    }
    
    setState(() {
      _allFiles = pdfPaths;
      _folders = folderPaths;
    });
  }

  Future<void> _loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favorites = prefs.getStringList('favorites') ?? [];
      _recent = prefs.getStringList('recent') ?? [];
    });
  }

  Future<void> _saveLists() async {
    final prefs = await SharedPreferences.getInstance();
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
      final imported = File(path);
      final newPath = p.join(_currentPath!, p.basename(path));
      await imported.copy(newPath);
      await _scanFilesAndFolders();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('File imported successfully')));
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

  Future<void> _renameFile(String oldPath) async {
    final controller = TextEditingController(text: p.basenameWithoutExtension(oldPath));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'New file name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              
              final newPath = p.join(p.dirname(oldPath), '$newName.pdf');
              await File(oldPath).rename(newPath);
              
              // Update favorites and recent if file was moved
              if (_favorites.contains(oldPath)) {
                _favorites.remove(oldPath);
                _favorites.add(newPath);
              }
              if (_recent.contains(oldPath)) {
                _recent.remove(oldPath);
                _recent.add(newPath);
              }
              await _saveLists();
              await _scanFilesAndFolders();
              
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveFile(String filePath) async {
    final allFolders = await _getAllFolders();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Move File'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: allFolders.length,
            itemBuilder: (_, index) {
              final folder = allFolders[index];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(p.relative(folder, from: _baseDir!.path)),
                onTap: () async {
                  final fileName = p.basename(filePath);
                  final newPath = p.join(folder, fileName);
                  
                  await File(filePath).rename(newPath);
                  
                  // Update favorites and recent with new path
                  if (_favorites.contains(filePath)) {
                    _favorites.remove(filePath);
                    _favorites.add(newPath);
                  }
                  if (_recent.contains(filePath)) {
                    _recent.remove(filePath);
                    _recent.add(newPath);
                  }
                  await _saveLists();
                  await _scanFilesAndFolders();
                  
                  if (mounted) Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _getAllFolders() async {
    final List<String> folders = [];
    final dir = Directory(_baseDir!.path);
    
    await for (var entity in dir.list(recursive: true)) {
      if (entity is Directory) {
        folders.add(entity.path);
      }
    }
    
    return folders;
  }

  void _enterFolder(String folderPath) {
    setState(() {
      _currentPath = folderPath;
    });
    _scanFilesAndFolders();
  }

  void _goBack() {
    if (_currentPath != _baseDir!.path) {
      setState(() {
        _currentPath = p.dirname(_currentPath!);
      });
      _scanFilesAndFolders();
    }
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Files'),
        content: Text('Are you sure you want to delete ${_selectedFiles.length} file(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              for (String path in _selectedFiles) {
                final file = File(path);
                if (await file.exists()) {
                  await file.delete();
                  
                  // Remove from favorites and recent
                  if (_favorites.contains(path)) {
                    _favorites.remove(path);
                  }
                  if (_recent.contains(path)) {
                    _recent.remove(path);
                  }
                }
              }
              
              await _saveLists();
              await _scanFilesAndFolders();
              setState(() {
                _selectedFiles.clear();
                _selectionMode = false;
              });
              
              if (mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${_selectedFiles.length} file(s) deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;
    
    final xFiles = _selectedFiles.map((path) => XFile(path)).toList();
    await Share.shareXFiles(xFiles);
  }

  Future<void> _printSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;
    
    for (String path in _selectedFiles) {
      final bytes = await File(path).readAsBytes();
      await Printing.layoutPdf(onLayout: (_) => bytes);
    }
  }

  void _selectAllFiles() {
    setState(() {
      if (_selectedFiles.length == _allFiles.length) {
        _selectedFiles.clear();
      } else {
        _selectedFiles = List.from(_allFiles);
      }
    });
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
          .where((path) =>
              path.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.basename(path)
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_sortMode == 'Size') {
      base.sort((a, b) =>
          File(b).lengthSync().compareTo(File(a).lengthSync()));
    } else if (_sortMode == 'Date') {
      base.sort((a, b) =>
          File(b).lastModifiedSync().compareTo(File(a).lastModifiedSync()));
    } else {
      base.sort((a, b) => p.basename(a).compareTo(p.basename(b)));
    }

    return base;
  }

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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty || _currentPath == null) return;
              final newFolder = Directory(p.join(_currentPath!, name));
              if (!(await newFolder.exists())) {
                await newFolder.create(recursive: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Folder "$name" created')),
                );
                await _scanFilesAndFolders();
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final files = _getCurrentList();
    final titles = ['All Files', 'Recent', 'Favorites', 'Tools'];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[_selectedIndex]),
            if (_selectedIndex == 0 && _currentPath != _baseDir!.path)
              Text(
                p.relative(_currentPath!, from: _baseDir!.path),
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (_selectedIndex == 0 && _currentPath != _baseDir!.path)
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed: _goBack,
            ),
          
          // Search Icon
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
          
          // Create Folder Icon (only in All Files)
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: _createFolder,
            ),
          
          // Sort Icon
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (val) => setState(() => _sortMode = val),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Name', child: Text('Sort by Name')),
              PopupMenuItem(value: 'Size', child: Text('Sort by Size')),
              PopupMenuItem(value: 'Date', child: Text('Sort by Date')),
            ],
          ),
          
          // Selection Mode Icons
          if (_selectionMode && _selectedFiles.isNotEmpty) ...[
            // Share selected files
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareSelectedFiles,
            ),
            // Print selected files
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _printSelectedFiles,
            ),
            // Delete selected files
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelectedFiles,
            ),
          ],
          
          // Select All / Selection Mode Toggle
          IconButton(
            icon: Icon(
              _selectionMode ? 
                (_selectedFiles.length == _allFiles.length ? Icons.deselect : Icons.select_all) 
                : Icons.select_all_outlined,
            ),
            onPressed: () {
              if (_selectionMode) {
                _selectAllFiles();
              } else {
                setState(() => _selectionMode = true);
              }
            },
          ),
          
          // Close selection mode
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selectionMode = false;
                _selectedFiles.clear();
              }),
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
                applicationVersion: '4.1',
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
      body: _selectedIndex == 0 ? _buildAllFilesView(files) : _buildListView(files),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        onTap: (i) {
          setState(() {
            _selectedIndex = i;
            _selectionMode = false;
            _selectedFiles.clear();
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'All'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Recent'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favs'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Tools'),
        ],
      ),
    );
  }

  Widget _buildAllFilesView(List<String> files) {
    return ListView(
      children: [
        // Folders section
        ..._folders.map((folderPath) => ListTile(
          leading: const Icon(Icons.folder, color: Colors.amber),
          title: Text(p.basename(folderPath)),
          subtitle: const Text('Folder'),
          onTap: () => _enterFolder(folderPath),
        )),
        
        // Files section
        ...files.map((filePath) => _buildFileItem(filePath)),
      ],
    );
  }

  Widget _buildListView(List<String> files) {
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (_, i) => _buildFileItem(files[i]),
    );
  }

  Widget _buildFileItem(String filePath) {
    final f = File(filePath);
    final sizeMb = (f.lengthSync() / 1024 / 1024).toStringAsFixed(2);
    final modified =
        DateFormat('dd.MM.yyyy HH:mm').format(f.lastModifiedSync());
    
    return ListTile(
      leading: _selectionMode 
          ? Checkbox(
              value: _selectedFiles.contains(filePath),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedFiles.add(filePath);
                  } else {
                    _selectedFiles.remove(filePath);
                  }
                });
              },
            )
          : const Icon(Icons.picture_as_pdf, color: Colors.red),
      title: Text(p.basename(filePath)),
      subtitle: Text('$sizeMb MB • $modified'),
      trailing: _selectionMode ? null : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _favorites.contains(filePath)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: Colors.red,
            ),
            onPressed: () => _toggleFavorite(filePath),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'rename') {
                _renameFile(filePath);
              } else if (value == 'move') {
                _moveFile(filePath);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'move', child: Text('Move')),
            ],
          ),
        ],
      ),
      onTap: () {
        if (_selectionMode) {
          setState(() {
            _selectedFiles.contains(filePath)
                ? _selectedFiles.remove(filePath)
                : _selectedFiles.add(filePath);
          });
        } else {
          _openViewer(filePath);
        }
      },
      onLongPress: () {
        setState(() {
          _selectionMode = true;
          _selectedFiles.add(filePath);
        });
      },
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
  Widget? buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, query));

  @override
  Widget buildResults(BuildContext context) => Container();

  @override
  Widget buildSuggestions(BuildContext context) => Container();
}

class ViewerScreen extends StatefulWidget {
  final File file;
  final String fileName;
  final bool dark;

  const ViewerScreen({
    super.key,
    required this.file,
    required this.fileName,
    required this.dark,
  });

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
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.shareXFiles([XFile(widget.file.path)]),
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_viewerUrl())),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              allowFileAccess: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              supportZoom: true,
              useHybridComposition: true,
            ),
            onWebViewCreated: (controller) => _controller = controller,
            onLoadStop: (_, __) => setState(() => _loaded = true),
          ),
          if (!_loaded)
            const Center(child: CircularProgressIndicator(color: Colors.red)),
        ],
      ),
    );
  }
}

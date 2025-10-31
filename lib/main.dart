// main.dart — PDF Manager Plus v7.0
// 💯 Full version with working Rename, Move, Delete, Create Folder, Permission

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PdfManagerPlus());
}

class PdfManagerPlus extends StatelessWidget {
  const PdfManagerPlus({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager Plus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> _allFiles = [];
  int _selectedIndex = 0;
  bool _darkMode = false;
  String _searchQuery = '';

  final List<String> _tabs = ['All Files', 'Recent', 'Favorites', 'Tools'];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final dir = Directory('/storage/emulated/0/Download/PDFManagerPlus');
    if (!(await dir.exists())) await dir.create(recursive: true);
    final files = dir
        .listSync(recursive: true)
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .map((f) => f.path)
        .toList();
    setState(() => _allFiles = files);
  }

  Future<bool> _ensureStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted ||
          await Permission.storage.isGranted) {
        return true;
      }

      final granted = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Storage Permission Required'),
          content: const Text(
            'This app needs "All Files Access" permission to work properly.\n\n'
            'Please allow it in system settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context, true);
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      return granted ?? false;
    }
    return true;
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final dir = Directory('/storage/emulated/0/Download/PDFManagerPlus');
      if (!(await dir.exists())) await dir.create(recursive: true);
      final newPath = '${dir.path}/${p.basename(file.path)}';
      await file.copy(newPath);
      _loadFiles();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF imported successfully')),
      );
    }
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
              final folderName = controller.text.trim();
              if (folderName.isEmpty) return;

              final granted = await _ensureStoragePermission();
              if (!granted) return;

              final baseDir = Directory('/storage/emulated/0/Download/PDFManagerPlus');
              final newDir = Directory('${baseDir.path}/$folderName');

              if (!(await newDir.exists())) {
                await newDir.create(recursive: true);
                if (mounted) {
                  Navigator.pop(context);
                  _loadFiles();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Folder "$folderName" created')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Folder already exists')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _openViewer(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(filePath: path, dark: _darkMode),
      ),
    ).then((_) => _loadFiles());
  }

  void _showFileMenu(String path) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(context);
              _renameFile(path);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              _openViewer(path);
            },
          ),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Print'),
            onTap: () async {
              Navigator.pop(context);
              try {
                await Printing.layoutPdf(
                  onLayout: (format) => File(path).readAsBytes(),
                );
              } catch (_) {}
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () async {
              Navigator.pop(context);
              await Share.shareXFiles([XFile(path)]);
            },
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move),
            title: const Text('Move'),
            onTap: () {
              Navigator.pop(context);
              _moveFile(path);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () async {
              Navigator.pop(context);
              await File(path).delete();
              _loadFiles();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _renameFile(String path) async {
    final controller = TextEditingController(text: p.basenameWithoutExtension(path));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'New name'),
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

              final dir = File(path).parent.path;
              final newPath = '$dir/$newName.pdf';
              await File(path).rename(newPath);

              if (mounted) {
                Navigator.pop(context);
                _loadFiles();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Renamed to $newName.pdf')),
                );
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveFile(String path) async {
    final dir = Directory('/storage/emulated/0/Download/PDFManagerPlus');
    final folders = dir
        .listSync()
        .whereType<Directory>()
        .map((d) => d.path)
        .toList();

    if (folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No folders to move to.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        children: folders.map((folder) {
          return ListTile(
            leading: const Icon(Icons.folder),
            title: Text(p.basename(folder)),
            onTap: () async {
              try {
                final file = File(path);
                final dest = File('${folder}/${p.basename(path)}');
                await dest.writeAsBytes(await file.readAsBytes());
                await file.delete();

                Navigator.pop(context);
                _loadFiles();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Moved to ${p.basename(folder)}')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Move failed')),
                );
              }
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final files = _allFiles.where((f) {
      if (_searchQuery.isEmpty) return true;
      return p.basename(f).toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final query = await showSearch(
                context: context,
                delegate: FileSearchDelegate(_allFiles),
              );
              if (query != null) setState(() => _searchQuery = query);
            },
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _createFolder,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Text('PDF Manager Plus', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Import File'),
              onTap: () {
                Navigator.pop(context);
                _importFile();
              },
            ),
            SwitchListTile(
              title: const Text('Dark Mode'),
              value: _darkMode,
              onChanged: (v) => setState(() => _darkMode = v),
            ),
          ],
        ),
      ),
      body: files.isEmpty
          ? const Center(child: Text('No PDFs found'))
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (_, i) {
                final f = File(files[i]);
                final stat = f.statSync();
                final size = (stat.size / 1024).toStringAsFixed(1);
                final modified = stat.modified.toString().split('.')[0];

                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(p.basename(files[i])),
                  subtitle: Text('$size KB\n$modified'),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () => _showFileMenu(files[i]),
                      ),
                      const Icon(Icons.favorite_border, color: Colors.grey),
                    ],
                  ),
                  onTap: () => _openViewer(files[i]),
                );
              },
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'All Files'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Recent'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Tools'),
        ],
      ),
    );
  }
}

class FileSearchDelegate extends SearchDelegate<String> {
  final List<String> files;
  FileSearchDelegate(this.files);

  @override
  List<Widget>? buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) {
    final results = files.where((f) => p.basename(f).toLowerCase().contains(query.toLowerCase())).toList();
    return ListView(children: results.map((f) => ListTile(title: Text(p.basename(f)))).toList());
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}

class PdfViewerPage extends StatelessWidget {
  final String filePath;
  final bool dark;
  const PdfViewerPage({super.key, required this.filePath, required this.dark});

  @override
  Widget build(BuildContext context) {
    final fileUri = Uri.file(filePath).toString();
    final url = 'file:///android_asset/flutter_assets/assets/web/viewer.html?file=${Uri.encodeComponent(fileUri)}&dark=$dark';

    return Scaffold(
      appBar: AppBar(title: Text(p.basename(filePath))),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          allowFileAccess: true,
          allowUniversalAccessFromFileURLs: true,
          javaScriptEnabled: true,
        ),
      ),
    );
  }
}

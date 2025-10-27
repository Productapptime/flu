// lib/main.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;

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
  FileSystemItem(this.id, this.name);
}

class PdfFileItem extends FileSystemItem {
  final File file;
  PdfFileItem({required String id, required String name, required this.file})
      : super(id, name);
}

class PdfFolderItem extends FileSystemItem {
  Color color;
  bool isLocked;
  String? password;
  PdfFolderItem({
    required String id,
    required String name,
    this.color = Colors.grey,
    this.isLocked = false,
    this.password,
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

  @override
  void initState() {
    super.initState();
    // initial sample data (optional)
    _items.addAll([
      PdfFileItem(id: 'file_1', name: 'Report.pdf', file: File('/tmp/report.pdf')),
      PdfFileItem(id: 'file_2', name: 'Sample.pdf', file: File('/tmp/sample.pdf')),
    ]);
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
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final f = File(path);
        final id = 'file_${DateTime.now().millisecondsSinceEpoch}';
        final name = p.basename(path);
        final exists = _items.any((it) => it is PdfFileItem && (it as PdfFileItem).file.path == path);
        if (!exists) {
          setState(() {
            _items.add(PdfFileItem(id: id, name: name, file: f));
          });
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $name')));
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File already in list')));
          }
        }
      }
    } catch (e) {
      debugPrint('Import error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import failed')));
      }
    }
  }

  void _createFolder() async {
    final name = await _showTextInput('New folder name', '');
    if (name != null && name.trim().isNotEmpty) {
      setState(() {
        _items.insert(0, PdfFolderItem(id: 'folder_${DateTime.now().millisecondsSinceEpoch}', name: name.trim()));
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('OK')),
        ],
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedItems.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_selectionMode ? 'Selection enabled' : 'Selection disabled')),
    );
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
          ListTile(title: const Text('Sort A → Z'), onTap: () { Navigator.pop(ctx); _sortByName(); }),
          ListTile(title: const Text('Sort Z → A'), onTap: () { Navigator.pop(ctx); setState(() => _items.sort((a,b)=>b.name.toLowerCase().compareTo(a.name.toLowerCase()))); }),
          ListTile(title: const Text('Sort by Recent (sample)'), onTap: () { Navigator.pop(ctx); }),
        ]),
      );
    });
  }

  void _openFile(PdfFileItem item) async {
    final returned = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => ViewerScreen(
        file: item.file,
        fileName: item.name,
        dark: _darkModeManual || MediaQuery.of(context).platformBrightness == Brightness.dark,
      )),
    );

    // if viewer returned a saved File — add to list
    if (returned != null && returned.existsSync()) {
      final exists = _items.any((it) => it is PdfFileItem && (it as PdfFileItem).file.path == returned.path);
      if (!exists) {
        setState(() {
          _items.add(PdfFileItem(id: 'file_${DateTime.now().millisecondsSinceEpoch}', name: p.basename(returned.path), file: returned));
        });
      }
    }
  }

  void _showFileMenu(FileSystemItem item) {
    if (item is PdfFileItem) {
      showModalBottomSheet(context: context, builder: (ctx) {
        return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.drive_file_rename_outline), title: const Text('Rename'), onTap: () { Navigator.pop(ctx); _renameItem(item); }),
          ListTile(leading: const Icon(Icons.print), title: const Text('Print'), onTap: () { Navigator.pop(ctx); _notify('Print not implemented'); }),
          ListTile(leading: const Icon(Icons.share), title: const Text('Share'), onTap: () { Navigator.pop(ctx); _notify('Share not implemented'); }),
          ListTile(leading: const Icon(Icons.drive_file_move), title: const Text('Move'), onTap: () { Navigator.pop(ctx); _notify('Move not implemented (concept)'); }),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete'), onTap: () { Navigator.pop(ctx); _deleteItem(item); }),
        ]));
      });
    } else if (item is PdfFolderItem) {
      showModalBottomSheet(context: context, builder: (ctx) {
        return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.drive_file_rename_outline), title: const Text('Rename'), onTap: () { Navigator.pop(ctx); _renameItem(item); }),
          ListTile(leading: const Icon(Icons.drive_file_move), title: const Text('Move'), onTap: () { Navigator.pop(ctx); _notify('Move folder (concept)'); }),
          ListTile(leading: Icon(item.isLocked ? Icons.lock_open : Icons.lock_outline), title: Text(item.isLocked ? 'Unlock' : 'Lock'), onTap: () { Navigator.pop(ctx); _toggleLock(folder: item); }),
          ListTile(leading: Icon(Icons.color_lens, color: item.color), title: const Text('Change color'), onTap: () { Navigator.pop(ctx); _changeFolderColor(item); }),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete'), onTap: () { Navigator.pop(ctx); _deleteItem(item); }),
        ]));
      });
    }
  }

  void _renameItem(FileSystemItem item) async {
    final newName = await _showTextInput('Rename', item.name);
    if (newName != null && newName.trim().isNotEmpty) {
      setState(() => item.name = newName.trim());
    }
  }

  void _deleteItem(FileSystemItem item) {
    setState(() {
      _items.remove(item);
      _selectedItems.remove(item);
    });
    _notify('Deleted ${item.name}');
  }

  void _notify(String text) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _toggleLock({required PdfFolderItem folder}) async {
    if (folder.isLocked) {
      final pw = await _showTextInput('Unlock folder: enter password', '');
      if (pw != null && pw == folder.password) {
        setState(() { folder.isLocked = false; folder.password = null; });
        _notify('Folder unlocked');
      } else {
        _notify('Wrong password');
      }
    } else {
      final pw = await _showTextInput('Set folder password', '');
      if (pw != null && pw.trim().isNotEmpty) {
        setState(() { folder.isLocked = true; folder.password = pw.trim(); });
        _notify('Folder locked');
      }
    }
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
            child: Container(margin: const EdgeInsets.all(8), width: 48, height: 48, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8))),
          )).toList(),
        ));
      }
    );
    if (chosen != null) setState(() => folder.color = chosen);
  }

  /* ----------------------
     UI build
  ---------------------- */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final title = _bottomIndex == 0 ? 'All Files' : (_bottomIndex == 1 ? 'Recent' : (_bottomIndex == 2 ? 'Favorites' : 'Tools'));

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(children: [
            DrawerHeader(child: Text('PDF Reader & Manager', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white)), decoration: BoxDecoration(color: theme.colorScheme.primary)),
            ListTile(leading: const Icon(Icons.cloud_upload), title: const Text('Import PDF'), onTap: () { Navigator.pop(context); _importPdf(); }),
            ListTile(leading: const Icon(Icons.info), title: const Text('About'), onTap: () { Navigator.pop(context); _notify('About'); }),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('Dark Mode'),
              value: _darkModeManual,
              onChanged: (v) {
                setState(() { _darkModeManual = v; });
                // toggle overall app themeMode is more global; for simplicity we rely on platform theme+manual flag
                _notify('Dark mode toggled (widget-level). WebView will receive param on open.');
              },
            ),
            ListTile(leading: const Icon(Icons.policy), title: const Text('Policy'), onTap: () { Navigator.pop(context); _notify('Policy'); }),
            ListTile(leading: const Icon(Icons.language), title: const Text('Language'), onTap: () { Navigator.pop(context); _notify('Language'); }),
          ]),
        ),
      ),
      appBar: AppBar(
        title: _isSearching ? _buildSearchField() : Text(title),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () { setState(() => _isSearching = !_isSearching); }),
          IconButton(icon: const Icon(Icons.create_new_folder), onPressed: _createFolder),
          IconButton(icon: const Icon(Icons.sort), onPressed: _showSortSheet),
          IconButton(icon: _selectionMode ? const Icon(Icons.check_box) : const Icon(Icons.check_box_outline_blank), onPressed: _toggleSelectionMode),
          IconButton(icon: const Icon(Icons.add), onPressed: _importPdf),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) { setState(() { _bottomIndex = i; _selectionMode = false; _selectedItems.clear(); }); },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'All Files'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Recent'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Tools'),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: const InputDecoration(hintText: 'Search files...', border: InputBorder.none),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildBody() {
    List<FileSystemItem> display = _items;
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      display = display.where((it) => it.name.toLowerCase().contains(q)).toList();
    }

    if (_bottomIndex != 0) {
      return Center(child: Text('Tab "${_bottomIndex == 1 ? "Recent" : _bottomIndex == 2 ? "Favorites" : "Tools"}" - placeholder'));
    }

    if (display.isEmpty) {
      return const Center(child: Text('No files yet. Use the + or drawer to import.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: display.length,
      separatorBuilder: (_,__) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final it = display[i];
        if (it is PdfFolderItem) {
          return ListTile(
            leading: Icon(Icons.folder, color: it.color),
            title: Text(it.name),
            trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showFileMenu(it)),
            onTap: () {
              if (_selectionMode) _toggleSelect(it);
              else _notify('Open folder (concept): ${it.name}');
            },
          );
        } else if (it is PdfFileItem) {
          return ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: Text(it.name),
            subtitle: Text(it.file.path, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showFileMenu(it)),
            onTap: () {
              if (_selectionMode) _toggleSelect(it);
              else _openFile(it);
            },
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  void _toggleSelect(FileSystemItem item) {
    setState(() {
      if (_selectedItems.contains(item)) _selectedItems.remove(item);
      else _selectedItems.add(item);
    });
  }
}

/* ----------------------
   Viewer screen
   - loads viewer.html from assets via file:///android_asset/...
   - passes ?file=<fileUri>&dark=true|false
   - registers addJavaScriptHandler("onPdfSaved", ...) to receive filename & base64
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
    // viewer.html asset path inside Flutter APK:
    // file:///android_asset/flutter_assets/assets/web/viewer.html
    // file param must be a file:// uri that the viewer can fetch inside WebView
    final fileUri = Uri.file(widget.file.path).toString();
    final dark = widget.dark ? 'true' : 'false';
    final url = 'file:///android_asset/flutter_assets/assets/web/viewer.html?file=${Uri.encodeComponent(fileUri)}&dark=$dark';
    return url;
  }

  Future<void> _handleOnPdfSaved(List<dynamic> args) async {
    // args[0] = filename (string), args[1] = base64data (optional)
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved ${p.basename(_savedFile!.path)}')));
      }
    } catch (e) {
      debugPrint('onPdfSaved error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save failed')));
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
        ),
        body: Stack(
          children: [
            // overlay that influences iframe area to appear dark when dark mode — matching your request
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
                // register handler to be called from viewer.html JS:
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

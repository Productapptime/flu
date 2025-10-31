import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(const PdfManagerApp());
}

/// 📂 Android 11+ depolama izinleri
Future<void> _requestPermissions() async {
  await [
    Permission.manageExternalStorage,
    Permission.storage,
  ].request();
}

/// Uygulama kökü
class PdfManagerApp extends StatefulWidget {
  const PdfManagerApp({super.key});
  @override
  State<PdfManagerApp> createState() => _PdfManagerAppState();
}

class _PdfManagerAppState extends State<PdfManagerApp> {
  bool darkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager Plus',
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData.dark(useMaterial3: true),
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: PdfHomePage(
        dark: darkMode,
        onToggleTheme: () => setState(() => darkMode = !darkMode),
      ),
    );
  }
}

/// 🏠 Ana Sayfa
class PdfHomePage extends StatefulWidget {
  final bool dark;
  final VoidCallback onToggleTheme;
  const PdfHomePage({super.key, required this.dark, required this.onToggleTheme});

  @override
  State<PdfHomePage> createState() => _PdfHomePageState();
}

class _PdfHomePageState extends State<PdfHomePage> {
  int _selectedIndex = 0;
  List<String> allFiles = [];
  List<String> favorites = [];
  List<String> recents = [];

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      allFiles = prefs.getStringList('allFiles') ?? [];
      favorites = prefs.getStringList('favorites') ?? [];
      recents = prefs.getStringList('recents') ?? [];
    });
  }

  Future<void> _saveLists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('allFiles', allFiles);
    await prefs.setStringList('favorites', favorites);
    await prefs.setStringList('recents', recents);
  }

  Future<void> _importPdf() async {
    final manageStatus = await Permission.manageExternalStorage.request();
    final storageStatus = await Permission.storage.request();

    if (!manageStatus.isGranted && !storageStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Depolama izni verilmedi.")),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        if (!allFiles.contains(filePath)) {
          setState(() => allFiles.add(filePath));
          await _saveLists();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF eklendi: ${p.basename(filePath)}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF seçilemedi: $e')),
      );
    }
  }

  void _openPdf(String filePath) async {
    if (!recents.contains(filePath)) {
      setState(() => recents.insert(0, filePath));
      await _saveLists();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewerScreen(
          file: File(filePath),
          fileName: p.basename(filePath),
          dark: widget.dark,
        ),
      ),
    );
  }

  void _toggleFavorite(String filePath) async {
    setState(() {
      favorites.contains(filePath)
          ? favorites.remove(filePath)
          : favorites.add(filePath);
    });
    await _saveLists();
  }

  Widget _buildPdfList(List<String> list) {
    if (list.isEmpty) {
      return const Center(child: Text("Henüz PDF bulunmuyor."));
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final path = list[index];
        final name = p.basename(path);
        final isFav = favorites.contains(path);

        return ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
          title: Text(name),
          trailing: IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.red : null,
            ),
            onPressed: () => _toggleFavorite(path),
          ),
          onTap: () => _openPdf(path),
        );
      },
    );
  }

  Widget get _body {
    switch (_selectedIndex) {
      case 1:
        return _buildPdfList(recents);
      case 2:
        return _buildPdfList(favorites);
      default:
        return _buildPdfList(allFiles);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(["All Files", "Recent", "Favorites"][_selectedIndex]),
        actions: [
          IconButton(icon: const Icon(Icons.upload_file), onPressed: _importPdf),
          IconButton(
            icon: Icon(widget.dark ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: const [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PDF Manager Plus',
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text("About"),
              subtitle: Text("InAppWebView + Mozilla PDF.js Viewer"),
            ),
          ],
        ),
      ),
      body: _body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder), label: "All"),
          NavigationDestination(icon: Icon(Icons.access_time), label: "Recent"),
          NavigationDestination(icon: Icon(Icons.favorite), label: "Favorites"),
        ],
      ),
    );
  }
}

/// 🧭 PDF Viewer (tek dosya içinde)
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
  File? _savedFile;

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

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${p.basename(_savedFile!.path)} kaydedildi')));
      }
    } catch (e) {
      debugPrint('onPdfSaved error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Kaydetme başarısız')));
      }
    }
  }

  Future<void> _printFile() async {
    try {
      final pdfData = await widget.file.readAsBytes();
      await Printing.layoutPdf(onLayout: (format) => pdfData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yazdırma başarısız')),
      );
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
            IconButton(
              icon: Icon(Icons.print,
                  color: widget.dark ? Colors.red : Colors.white),
              onPressed: _printFile,
            ),
            IconButton(
              icon: Icon(Icons.share,
                  color: widget.dark ? Colors.red : Colors.white),
              onPressed: () async {
                try {
                  await Share.shareXFiles(
                    [XFile(widget.file.path)],
                    text: 'PDF Dosyası: ${widget.fileName}',
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Paylaşım başarısız')));
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
                controller.addJavaScriptHandler(
                    handlerName: "onPdfSaved",
                    callback: (args) {
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
                    color: widget.dark ? Colors.red : Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}

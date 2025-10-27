import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PDFManagerApp());
}

class PDFManagerApp extends StatelessWidget {
  const PDFManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager + Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.red,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorSchemeSeed: Colors.red,
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFB71C1C)),
        cardColor: const Color(0xFF1E1E1E),
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
  final List<File> _pdfFiles = [];

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() => _pdfFiles.add(file));
    }
  }

  void _openPdf(File file) async {
    final newFile = await Navigator.push<File?>(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerPage(
          filePath: file.path,
          fileName: file.path.split('/').last,
        ),
      ),
    );
    if (newFile != null && newFile.existsSync()) {
      setState(() => _pdfFiles.add(newFile));
    }
  }

  void _showFileOptions(File file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text("Yeniden Adlandır"),
                onTap: () async {
                  Navigator.pop(context);
                  final newName = await _showRenameDialog(file);
                  if (newName != null) {
                    final dir = file.parent.path;
                    final renamed = file.renameSync('$dir/$newName');
                    setState(() {
                      final idx = _pdfFiles.indexOf(file);
                      _pdfFiles[idx] = renamed;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text("Sil"),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _pdfFiles.remove(file));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _showRenameDialog(File file) async {
    final controller = TextEditingController(text: file.path.split('/').last);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dosyayı Yeniden Adlandır'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Yeni dosya adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Kaydet')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      drawer: Drawer(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: isDark ? Colors.red[800] : Colors.red),
              child: const Text('PDF Manager', style: TextStyle(color: Colors.white, fontSize: 22)),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Hakkında'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.policy),
              title: const Text('Gizlilik Politikası'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Tüm Dosyalar'),
        backgroundColor: isDark ? Colors.red[800] : Colors.red,
        actions: [
          IconButton(onPressed: _pickPdf, icon: const Icon(Icons.cloud_upload)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.sort)),
        ],
      ),
      body: _pdfFiles.isEmpty
          ? const Center(child: Text('Henüz PDF eklenmedi 📄'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _pdfFiles.length,
              itemBuilder: (_, i) {
                final file = _pdfFiles[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: Text(file.path.split('/').last),
                    onTap: () => _openPdf(file),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showFileOptions(file),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (_) {},
        selectedItemColor: Colors.red,
        unselectedItemColor: isDark ? Colors.grey[400] : Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: "All Files"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Recent"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favorites"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Tools"),
        ],
      ),
    );
  }
}

class PDFViewerPage extends StatefulWidget {
  final String filePath;
  final String fileName;
  const PDFViewerPage({super.key, required this.filePath, required this.fileName});

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  InAppWebViewController? _controller;
  bool _isLoaded = false;
  File? _savedFile;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pdfUri = Uri.file(widget.filePath).toString();
    final htmlPath =
        'file:///android_asset/flutter_assets/assets/web/viewer.html?file=$pdfUri&theme=${isDark ? "dark" : "light"}';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _savedFile);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName),
          backgroundColor: isDark ? Colors.red[800] : Colors.red,
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(htmlPath)),
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
                controller.addJavaScriptHandler(
                  handlerName: "onPdfSaved",
                  callback: (args) async {
                    final originalName =
                        args.isNotEmpty ? args[0] : widget.fileName;
                    final base64Data = args.length > 1 ? args[1] : null;

                    final dir = File(widget.filePath).parent.path;
                    final savedName = "kaydedilmis_$originalName";
                    final newPath = "$dir/$savedName";

                    if (base64Data != null && base64Data.isNotEmpty) {
                      final bytes = base64Decode(base64Data);
                      _savedFile = await File(newPath).writeAsBytes(bytes);
                    } else {
                      _savedFile = await File(widget.filePath).copy(newPath);
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                "Kaydedildi: ${_savedFile!.path.split('/').last}")),
                      );
                    }
                  },
                );
              },
              onLoadStop: (_, __) => setState(() => _isLoaded = true),
            ),
            if (!_isLoaded)
              const Center(child: CircularProgressIndicator(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

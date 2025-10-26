// lib/main.dart
import 'dart:io';
import 'dart:convert';
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
      title: "PDF Manager",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
      ),
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
  bool _darkMode = false;
  int _selectedIndex = 0;
  File? _savedFile;

  // 🔹 PDF ekleme
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

  // 🔹 PDF aç
  void _openPdf(File file) async {
    final newFile = await Navigator.push<File?>(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerPage(filePath: file.path, fileName: file.path.split('/').last),
      ),
    );

    if (newFile != null && newFile.existsSync()) {
      setState(() => _pdfFiles.add(newFile));
    }
  }

  // 🔹 Drawer menüsü
  void _openDrawer() {
    Scaffold.of(context).openDrawer();
  }

  // 🔹 Tema değiştirme
  void _toggleDarkMode() {
    setState(() => _darkMode = !_darkMode);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _darkMode;
    final Color bg = isDark ? Colors.black : Colors.white;
    final Color text = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bg,
      drawer: Drawer(
        backgroundColor: bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: isDark ? Colors.red.shade900 : Colors.red.shade100),
              child: Text(
                "📂 PDF Reader & Manager",
                style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload, color: Colors.red),
              title: Text("Import PDF", style: TextStyle(color: text)),
              onTap: () {
                Navigator.pop(context);
                _pickPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode, color: Colors.red),
              title: Text(isDark ? "Light Mode" : "Dark Mode", style: TextStyle(color: text)),
              onTap: () {
                _toggleDarkMode();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.language, color: Colors.red),
              title: Text("Language", style: TextStyle(color: text)),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Dil değiştirme henüz aktif değil.")),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.policy, color: Colors.red),
              title: Text("Policy", style: TextStyle(color: text)),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Policy sayfası yakında.")),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.red.shade900 : Colors.red,
        title: Text(
          ["All Files", "Recent", "Favorites", "Tools"][_selectedIndex],
          style: const TextStyle(color: Colors.white),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: _openDrawer,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _pickPdf,
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? (_pdfFiles.isEmpty
              ? Center(
                  child: Text(
                    "Henüz PDF eklenmedi 📄",
                    style: TextStyle(color: text.withOpacity(0.7)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _pdfFiles.length,
                  itemBuilder: (context, i) {
                    final f = _pdfFiles[i];
                    return Card(
                      color: isDark ? Colors.grey.shade900 : Colors.white,
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        title: Text(f.path.split('/').last, style: TextStyle(color: text)),
                        onTap: () => _openPdf(f),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => setState(() => _pdfFiles.removeAt(i)),
                        ),
                      ),
                    );
                  },
                ))
          : Center(
              child: Text(
                "Bu sekme henüz aktif değil",
                style: TextStyle(color: text.withOpacity(0.7)),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: bg,
        selectedItemColor: Colors.red,
        unselectedItemColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
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

// 🧩 PDF VIEWER SAYFASI
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
    final pdfUri = Uri.file(widget.filePath).toString();
    final htmlPath = 'file:///android_asset/flutter_assets/assets/web/viewer.html?file=$pdfUri';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _savedFile);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red,
          title: Text(widget.fileName, style: const TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context, _savedFile),
          ),
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
                _controller!.addJavaScriptHandler(
                  handlerName: "onPdfSaved",
                  callback: (args) async {
                    final originalName = args.isNotEmpty ? args[0] : widget.fileName;
                    final base64Data = args.length > 1 ? args[1] : null;
                    final dir = File(widget.filePath).parent.path;
                    final newPath = "$dir/kaydedilmis_$originalName";

                    if (base64Data != null && base64Data.isNotEmpty) {
                      final bytes = base64Decode(base64Data);
                      final savedFile = await File(newPath).writeAsBytes(bytes);
                      _savedFile = savedFile;
                    } else {
                      _savedFile = await File(widget.filePath).copy(newPath);
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Kaydedildi: ${_savedFile!.path.split('/').last}"),
                        ),
                      );
                    }
                  },
                );
              },
              onLoadStop: (c, _) => setState(() => _isLoaded = true),
            ),
            if (!_isLoaded)
              const Center(child: CircularProgressIndicator(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PDFApp());
}

class PDFApp extends StatelessWidget {
  const PDFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Viewer',
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
  String _selectedLocale = "en-US"; // 🌍 Varsayılan dil

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      if (!_pdfFiles.any((f) => f.path == file.path)) {
        setState(() => _pdfFiles.add(file));
      }
    }
  }

  void _openPdf(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerPage(
          filePath: file.path,
          fileName: file.path.split('/').last,
          locale: _selectedLocale, // 🌍 seçilen dili gönder
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Dosyalarım'),
        backgroundColor: Colors.red,
        actions: [
          // 🌐 Dil seçimi menüsü
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (lang) => setState(() => _selectedLocale = lang),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'en-US', child: Text('English (US)')),
              PopupMenuItem(value: 'tr', child: Text('Türkçe')),
              PopupMenuItem(value: 'fr', child: Text('Français')),
              PopupMenuItem(value: 'de', child: Text('Deutsch')),
              PopupMenuItem(value: 'es-ES', child: Text('Español')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'PDF Ekle',
            onPressed: _pickPdf,
          ),
        ],
      ),
      body: _pdfFiles.isEmpty
          ? const Center(child: Text('Henüz PDF eklenmedi 📄'))
          : ListView.separated(
              itemCount: _pdfFiles.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final f = _pdfFiles[index];
                final name = f.path.split('/').last;
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(name),
                  onTap: () => _openPdf(f),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() => _pdfFiles.removeAt(index));
                    },
                  ),
                );
              },
            ),
    );
  }
}

class PDFViewerPage extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String locale; // 🌍 Dil parametresi

  const PDFViewerPage({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.locale,
  });

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  InAppWebViewController? _controller;
  bool _isLoaded = false;

  @override
  Widget build(BuildContext context) {
    // 📄 PDF dosyasının URI'sini hazırla
    final pdfUri = Uri.file(widget.filePath).toString();

    // 🌍 viewer.html dosyasına dili parametre olarak gönder
    final htmlPath =
        'file:///android_asset/flutter_assets/assets/web/viewer.html'
        '?file=$pdfUri'
        '&locale=${widget.locale}'; // Burada PDF.js locale.json’daki anahtar birebir kullanılmalı

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Colors.red,
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
            onWebViewCreated: (controller) => _controller = controller,
            onLoadStop: (controller, url) {
              setState(() => _isLoaded = true);
            },
            onConsoleMessage: (controller, message) {
              debugPrint('🌐 WEBVIEW LOG: ${message.message}');
            },
            onLoadError: (controller, url, code, message) {
              debugPrint('❌ WEBVIEW ERROR ($code): $message');
            },
          ),
          if (!_isLoaded)
            const Center(child: CircularProgressIndicator(color: Colors.red)),
        ],
      ),
    );
  }
}

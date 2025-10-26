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

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() => _pdfFiles.add(file));
    }
  }

  void _openPdf(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerPage(
          filePath: file.path,
          fileName: file.path.split('/').last,
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
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _pickPdf,
          ),
        ],
      ),
      body: _pdfFiles.isEmpty
          ? const Center(child: Text('Henüz PDF eklenmedi 📄'))
          : ListView.builder(
              itemCount: _pdfFiles.length,
              itemBuilder: (context, index) {
                final f = _pdfFiles[index];
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(f.path.split('/').last),
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

  const PDFViewerPage({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  InAppWebViewController? _controller;
  bool _isLoaded = false;

  @override
  Widget build(BuildContext context) {
    // PDF dosyasının tam URI'sini oluştur
    final pdfUri = Uri.file(widget.filePath).toString();

    // Orijinal viewer.html kullanılıyor
    final htmlPath =
        'file:///android_asset/flutter_assets/assets/web/viewer.html?file=$pdfUri';

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
              debugPrint('WEBVIEW LOG: ${message.message}');
            },
            onLoadError: (controller, url, code, message) {
              debugPrint('WEBVIEW ERROR ($code): $message');
            },
          ),
          if (!_isLoaded)
            const Center(child: CircularProgressIndicator(color: Colors.red)),
        ],
      ),
    );
  }
}

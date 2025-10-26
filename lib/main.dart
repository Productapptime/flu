import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PDFViewerApp());
}

class PDFViewerApp extends StatelessWidget {
  const PDFViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Basit PDF Görüntüleyici",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
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
  final List<File> pdfFiles = [];

  Future<void> pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() => pdfFiles.add(file));
    }
  }

  void openPDF(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PDFWebViewer(filePath: file.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF Dosyalarım"),
        backgroundColor: Colors.red,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: pickPDF,
        child: const Icon(Icons.file_upload),
      ),
      body: pdfFiles.isEmpty
          ? const Center(
              child: Text("Henüz PDF eklenmedi 📄"),
            )
          : ListView.builder(
              itemCount: pdfFiles.length,
              itemBuilder: (context, index) {
                final file = pdfFiles[index];
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(file.path.split('/').last),
                  onTap: () => openPDF(file),
                );
              },
            ),
    );
  }
}

class PDFWebViewer extends StatefulWidget {
  final String filePath;
  const PDFWebViewer({super.key, required this.filePath});

  @override
  State<PDFWebViewer> createState() => _PDFWebViewerState();
}

class _PDFWebViewerState extends State<PDFWebViewer> {
  InAppWebViewController? controller;

  @override
  Widget build(BuildContext context) {
    final pdfUri = Uri.file(widget.filePath).toString();
    final viewerPath = "assets/web/viewer.html?file=$pdfUri";

    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF Görüntüleyici"),
        backgroundColor: Colors.red,
      ),
      body: InAppWebView(
        initialFile: viewerPath,
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          allowFileAccess: true,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
        ),
        onWebViewCreated: (ctrl) => controller = ctrl,
      ),
    );
  }
}

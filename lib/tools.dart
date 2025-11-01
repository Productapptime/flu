// lib/tools.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

class ToolsPage extends StatefulWidget {
  final bool dark;

  const ToolsPage({super.key, required this.dark});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.dark ? Colors.grey[900] : Colors.grey[100],
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildToolCard('PDF Birleştir', 'Birden fazla PDF\'yi birleştir',
              Icons.merge, 'merge.html'),
          _buildToolCard('Sayfa Düzenle', 'Sayfaları sırala veya düzenle',
              Icons.edit_document, 'reorder_subtraction.html'),
          _buildToolCard('Metin Çıkar (OCR)', 'PDF veya görselden metin al',
              Icons.text_fields, 'ocr.html'),
          _buildToolCard('PDF Ayır', 'PDF\'yi sayfalara ayır', Icons.call_split,
              'split.html'),
          _buildToolCard('PDF Sıkıştır', 'Dosya boyutunu küçült',
              Icons.compress, 'compress.html'),
          _buildToolCard('PDF → Görsel', 'PDF\'yi resme dönüştür', Icons.image,
              'pdf_to_photo.html'),
        ],
      ),
    );
  }

  Widget _buildToolCard(
      String title, String subtitle, IconData icon, String htmlFile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final hasPermission = await _checkAllFilesAccessPermission();
          if (hasPermission) {
            _openToolPage(title, htmlFile);
          } else {
            await _showAllFilesAccessDialog(title, htmlFile);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.dark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.dark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _checkAllFilesAccessPermission() async {
    final status = await Permission.manageExternalStorage.status;
    return status.isGranted;
  }

  Future<void> _showAllFilesAccessDialog(String title, String htmlFile) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Column(
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.red),
            const SizedBox(height: 10),
            Text('İzin Gerekli',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ],
        ),
        content: Text(
          'PDF ve metin dosyalarınızı Documents/pdfreadermanager klasörüne kaydetmek için "Tüm dosyalara erişim" iznine ihtiyacımız var.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('VAZGEÇ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final result = await Permission.manageExternalStorage.request();
              if (result.isGranted) _openToolPage(title, htmlFile);
            },
            child: const Text('İZİN VER'),
          ),
        ],
      ),
    );
  }

  void _openToolPage(String title, String htmlFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ToolWebView(toolName: title, htmlFile: htmlFile, dark: widget.dark),
      ),
    );
  }
}

class ToolWebView extends StatefulWidget {
  final String toolName;
  final String htmlFile;
  final bool dark;

  const ToolWebView({
    super.key,
    required this.toolName,
    required this.htmlFile,
    required this.dark,
  });

  @override
  State<ToolWebView> createState() => _ToolWebViewState();
}

class _ToolWebViewState extends State<ToolWebView> {
  InAppWebViewController? _controller;
  Directory? _pdfReaderManagerDir;

  @override
  void initState() {
    super.initState();
    _initializeDirectory();
  }

  Future<void> _initializeDirectory() async {
    try {
      bool hasPermission = await Permission.manageExternalStorage.isGranted;

      if (hasPermission) {
        final documentsDir = Directory('/storage/emulated/0/Documents');
        if (!await documentsDir.exists()) {
          await documentsDir.create(recursive: true);
          print('📁 Documents klasörü oluşturuldu.');
        }

        final target = Directory('${documentsDir.path}/pdfreadermanager');
        if (!await target.exists()) {
          await target.create(recursive: true);
          print('📁 pdfreadermanager klasörü oluşturuldu.');
        }

        _pdfReaderManagerDir = target;
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        _pdfReaderManagerDir = Directory('${appDir.path}/pdfreadermanager');
        if (!await _pdfReaderManagerDir!.exists()) {
          await _pdfReaderManagerDir!.create(recursive: true);
        }
      }

      print('📂 Kullanılan dizin: ${_pdfReaderManagerDir!.path}');
    } catch (e) {
      print('Klasör oluşturma hatası: $e');
    }
  }

  Future<void> _saveFile(String fileName, String base64Data) async {
    if (_pdfReaderManagerDir == null) await _initializeDirectory();

    try {
      // Base64 verisini temizle
      final cleanBase64 = base64Data.replaceFirst(RegExp(r'^data:.*?base64,'), '');
      final bytes = base64.decode(cleanBase64);

      // Uygun dosya uzantısını belirle
      String extension = '';
      if (base64Data.contains('application/pdf')) {
        extension = '.pdf';
      } else if (base64Data.contains('image/png')) {
        extension = '.png';
      } else if (base64Data.contains('image/jpeg')) {
        extension = '.jpg';
      } else if (base64Data.contains('text/plain')) {
        extension = '.txt';
      }

      // Uzantı yoksa ekle
      if (!fileName.contains('.')) fileName += extension;

      final file = File('${_pdfReaderManagerDir!.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $fileName kaydedildi\nKonum: ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Dosya kaydetme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Dosya kaydedilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.toolName),
        backgroundColor: widget.dark ? Colors.black : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(
              'file:///android_asset/flutter_assets/assets/${widget.htmlFile}?dark=${widget.dark}'),
        ),
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
            handlerName: 'saveFile',
            callback: (args) async {
              if (args.length >= 2) {
                final name = args[0] as String;
                final data = args[1] as String;
                await _saveFile(name, data);
              }
              return {'success': true};
            },
          );
        },
      ),
    );
  }
}

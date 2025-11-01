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
          _buildToolCard('PDF Birleştir', 'Birden fazla PDF\'yi birleştir', Icons.merge, 'merge.html'),
          _buildToolCard('Sayfa Düzenle', 'Sayfaları sırala veya düzenle', Icons.edit_document, 'reorder_subtraction.html'),
          _buildToolCard('OCR (Metin Çıkar)', 'PDF veya görselden metin al', Icons.text_fields, 'ocr.html'),
          _buildToolCard('PDF Ayır', 'PDF\'yi sayfalara ayır', Icons.call_split, 'split.html'),
          _buildToolCard('PDF Sıkıştır', 'Dosya boyutunu küçült', Icons.compress, 'compress.html'),
          _buildToolCard('PDF → Görsel', 'PDF\'yi resme dönüştür', Icons.image, 'pdf_to_photo.html'),
        ],
      ),
    );
  }

  Widget _buildToolCard(String title, String subtitle, IconData icon, String htmlFile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (await Permission.manageExternalStorage.isGranted) {
            _openToolPage(title, htmlFile);
          } else {
            _showPermissionDialog(title, htmlFile);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.dark ? Colors.white : Colors.black), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(subtitle, style: TextStyle(fontSize: 12, color: widget.dark ? Colors.grey[400] : Colors.grey[600]), textAlign: TextAlign.center, maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPermissionDialog(String title, String htmlFile) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İzin Gerekli'),
        content: const Text('PDF dosyalarınızı Documents/PDF_Manager_Plus klasörüne kaydetmek için "Tüm dosyalara erişim" iznine ihtiyacımız var.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final status = await Permission.manageExternalStorage.request();
              if (status.isGranted) {
                _openToolPage(title, htmlFile);
              } else {
                openAppSettings();
              }
            },
            child: const Text('İzin Ver'),
          ),
        ],
      ),
    );
  }

  void _openToolPage(String title, String htmlFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ToolWebView(toolName: title, htmlFile: htmlFile, dark: widget.dark),
      ),
    );
  }
}

class ToolWebView extends StatefulWidget {
  final String toolName;
  final String htmlFile;
  final bool dark;
  const ToolWebView({super.key, required this.toolName, required this.htmlFile, required this.dark});

  @override
  State<ToolWebView> createState() => _ToolWebViewState();
}

class _ToolWebViewState extends State<ToolWebView> {
  InAppWebViewController? _controller;
  Directory? _pdfManagerDir;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _initDirectory();
  }

  Future<void> _initDirectory() async {
    try {
      if (await Permission.manageExternalStorage.isGranted) {
        _pdfManagerDir = Directory('/storage/emulated/0/Documents/PDF_Manager_Plus');
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        _pdfManagerDir = Directory('${appDir.path}/PDF_Manager_Plus');
      }
      if (!await _pdfManagerDir!.exists()) await _pdfManagerDir!.create(recursive: true);
      debugPrint('📁 Kayıt klasörü: ${_pdfManagerDir!.path}');
    } catch (e) {
      debugPrint('Klasör oluşturulamadı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.toolName),
        backgroundColor: widget.dark ? Colors.black : Colors.red,
        actions: [
          IconButton(icon: const Icon(Icons.folder_open), onPressed: _showFolderContents),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri('file:///android_asset/flutter_assets/assets/${widget.htmlFile}?dark=${widget.dark}')),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              allowFileAccess: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              useHybridComposition: true,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              controller.addJavaScriptHandler(handlerName: 'saveFile', callback: (args) async {
                if (args.length >= 2) {
                  await _saveBase64File(args[0], args[1]);
                }
                return {'success': true};
              });
            },
            onLoadStop: (_, __) => setState(() => _loaded = true),
          ),
          if (!_loaded) const Center(child: CircularProgressIndicator(color: Colors.red)),
        ],
      ),
    );
  }

  Future<void> _saveBase64File(String fileName, String base64Data) async {
    try {
      final cleanData = base64Data.replaceFirst(RegExp(r'^data:.*?base64,'), '');
      final bytes = base64.decode(cleanData);
      final file = File('${_pdfManagerDir!.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $fileName kaydedildi\nKonum: ${_pdfManagerDir!.path}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: 'AÇ', textColor: Colors.white, onPressed: () => OpenFile.open(file.path)),
        ));
      }
    } catch (e) {
      debugPrint('Dosya kaydedilemedi: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Dosya kaydedilemedi: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showFolderContents() async {
    if (_pdfManagerDir == null || !await _pdfManagerDir!.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Klasör bulunamadı'), backgroundColor: Colors.orange));
      return;
    }
    final files = _pdfManagerDir!.listSync().whereType<File>().toList();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📁 PDF_Manager_Plus Klasörü'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: files.isEmpty
              ? const Center(child: Text('Henüz dosya yok'))
              : ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, i) {
                    final f = files[i];
                    final name = f.uri.pathSegments.last;
                    final size = (f.lengthSync() / 1024).toStringAsFixed(1);
                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file, color: Colors.red),
                      title: Text(name),
                      subtitle: Text('$size KB'),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteFile(f)),
                      onTap: () => OpenFile.open(f.path),
                    );
                  }),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
      ),
    );
  }

  void _deleteFile(File f) {
    f.deleteSync();
    Navigator.pop(context);
    _showFolderContents();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ Dosya silindi'), backgroundColor: Colors.green));
  }
}

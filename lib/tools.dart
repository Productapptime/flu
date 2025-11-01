// lib/tools.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

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
          _buildToolCard(
            title: 'PDF Birleştir',
            subtitle: 'Birden fazla PDF\'yi birleştir',
            icon: Icons.merge,
            htmlFile: 'merge.html',
            context: context,
            dark: widget.dark,
          ),
          _buildToolCard(
            title: 'Sayfa Düzenle',
            subtitle: 'Sayfaları sırala veya düzenle',
            icon: Icons.edit_document,
            htmlFile: 'reorder_subtraction.html',
            context: context,
            dark: widget.dark,
          ),
          _buildToolCard(
            title: 'OCR (Metin Çıkar)',
            subtitle: 'PDF veya görselden metin al',
            icon: Icons.text_fields,
            htmlFile: 'ocr.html',
            context: context,
            dark: widget.dark,
          ),
          _buildToolCard(
            title: 'PDF Ayır',
            subtitle: 'PDF\'yi sayfalara ayır',
            icon: Icons.call_split,
            htmlFile: 'split.html',
            context: context,
            dark: widget.dark,
          ),
          _buildToolCard(
            title: 'PDF Sıkıştır',
            subtitle: 'Dosya boyutunu küçült',
            icon: Icons.compress,
            htmlFile: 'compress.html',
            context: context,
            dark: widget.dark,
          ),
          _buildToolCard(
            title: 'PDF → Görsel',
            subtitle: 'PDF\'yi resme dönüştür',
            icon: Icons.image,
            htmlFile: 'pdf_to_photo.html',
            context: context,
            dark: widget.dark,
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String htmlFile,
    required BuildContext context,
    required bool dark,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ToolWebView(
                toolName: title,
                htmlFile: htmlFile,
                dark: dark,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: dark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.grey[400] : Colors.grey[600],
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
  bool _loaded = false;

  String _getWebViewUrl() {
    return 'file:///android_asset/flutter_assets/assets/${widget.htmlFile}?dark=${widget.dark}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.toolName),
        backgroundColor: widget.dark ? Colors.black : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _buildWebView(),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(_getWebViewUrl())),
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
            
            // Flutter handler'larını kaydet
            controller.addJavaScriptHandler(
              handlerName: 'saveFile',
              callback: (args) async {
                if (args.length >= 2) {
                  final fileName = args[0] as String;
                  final base64Data = args[1] as String;
                  await _saveFile(fileName, base64Data);
                }
                return {'success': true};
              },
            );

            // PDF → Görsel için özel handler
            controller.addJavaScriptHandler(
              handlerName: 'saveImage',
              callback: (args) async {
                if (args.length >= 2) {
                  final fileName = args[0] as String;
                  final base64Data = args[1] as String;
                  await _saveImageFile(fileName, base64Data);
                }
                return {'success': true};
              },
            );
          },
          onLoadStop: (controller, url) {
            setState(() {
              _loaded = true;
            });
          },
        ),
        if (!_loaded)
          const Center(
            child: CircularProgressIndicator(color: Colors.red),
          ),
      ],
    );
  }

  Future<void> _saveFile(String fileName, String base64Data) async {
    try {
      // Download klasörünü al
      final downloadsDir = await getDownloadsDirectory();
      
      // Base64 veriyi decode et
      final bytes = base64.decode(base64Data);
      
      // Download klasörüne direkt kaydet
      final file = File('${downloadsDir!.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      // Başarı mesajı göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('✅ $fileName kaydedildi'),
                Text(
                  'Konum: Download klasörü',
                  style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Dosya kaydedilemedi: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // PNG, JPEG ve diğer görsel formatları için özel kaydetme metodu
  Future<void> _saveImageFile(String fileName, String base64Data) async {
    try {
      // Download klasörünü al
      final downloadsDir = await getDownloadsDirectory();
      
      // Base64 veriyi decode et
      final bytes = base64.decode(base64Data);
      
      // Download klasörüne direkt kaydet
      final file = File('${downloadsDir!.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      // Başarı mesajı göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('✅ $fileName kaydedildi'),
                Text(
                  'Konum: Download klasörü',
                  style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Görsel kaydedilemedi: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

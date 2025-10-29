import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ToolsWebView extends StatefulWidget {
  final bool darkMode;
  const ToolsWebView({super.key, required this.darkMode});

  @override
  State<ToolsWebView> createState() => _ToolsWebViewState();
}

class _ToolsWebViewState extends State<ToolsWebView> {
  final List<ToolItem> _tools = [
    ToolItem(
      id: 'merge',
      title: 'PDF Birleştir',
      description: 'Birden fazla PDF\'yi birleştir',
      icon: Icons.merge,
      color: Colors.blue,
      htmlFile: 'merge.html',
    ),
    ToolItem(
      id: 'split',
      title: 'PDF Ayır',
      description: 'PDF\'yi sayfalara ayır',
      icon: Icons.call_split,
      color: Colors.green,
      htmlFile: 'split.html',
    ),
    ToolItem(
      id: 'reorder',
      title: 'Sayfa Düzenle',
      description: 'Sayfaları sırala veya sil',
      icon: Icons.view_stream,
      color: Colors.orange,
      htmlFile: 'reorder_subtraction.html',
    ),
    ToolItem(
      id: 'compress',
      title: 'PDF Sıkıştır',
      description: 'Dosya boyutunu küçült',
      icon: Icons.inventory_2,
      color: Colors.purple,
      htmlFile: 'compress.html',
    ),
    ToolItem(
      id: 'ocr',
      title: 'OCR (Metin Çıkar)',
      description: 'PDF veya görselden metin al',
      icon: Icons.search,
      color: Colors.teal,
      htmlFile: 'ocr.html',
    ),
    ToolItem(
      id: 'image',
      title: 'PDF → Görsel',
      description: 'PDF\'yi resme dönüştür',
      icon: Icons.image,
      color: Colors.red,
      htmlFile: 'pdf_to_photo.html',
    ),
  ];

  void _openTool(ToolItem tool) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ToolDetailScreen(
          tool: tool,
          darkMode: widget.darkMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double aspectRatio = 2.0;
    if (screenWidth < 400) {
      aspectRatio = 1.6; // dar ekranlarda daha dik
    } else if (screenWidth > 600) {
      aspectRatio = 2.2; // tabletlerde daha yatay
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Araçları'),
        backgroundColor: widget.darkMode ? Colors.black : Colors.red,
        foregroundColor: widget.darkMode ? Colors.red : Colors.white,
        toolbarHeight: 48,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'PDF Araçları Merkezi',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'PDF dosyalarınızı düzenleyin, dönüştürün ve yönetin',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: _tools.length,
                itemBuilder: (context, index) {
                  final tool = _tools[index];
                  return _buildToolCard(tool);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(ToolItem tool) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openTool(tool),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: tool.color,
              width: 2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tool.color.withOpacity(0.1),
                tool.color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                tool.icon,
                size: 32,
                color: tool.color,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  tool.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  tool.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToolDetailScreen extends StatefulWidget {
  final ToolItem tool;
  final bool darkMode;

  const ToolDetailScreen({
    super.key,
    required this.tool,
    required this.darkMode,
  });

  @override
  State<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends State<ToolDetailScreen> {
  late InAppWebViewController _webViewController;
  double _progress = 0;
  bool _isLoading = true;

  Future<void> _saveFile(String fileName, String base64Data) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${appDir.path}/PDF_Manager_Plus');
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final file = File('${saveDir.path}/$fileName');
      final bytes = base64.decode(base64Data);
      await file.writeAsBytes(bytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya kaydedildi: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tool.title),
        backgroundColor: widget.darkMode ? Colors.black : Colors.red,
        foregroundColor: widget.darkMode ? Colors.red : Colors.white,
        toolbarHeight: 48,
      ),
      body: Column(
        children: [
          if (_isLoading || _progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.darkMode ? Colors.red : Colors.red,
              ),
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('file:///android_asset/flutter_assets/assets/${widget.tool.htmlFile}'),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                allowFileAccess: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                verticalScrollBarEnabled: true,
                horizontalScrollBarEnabled: false,
                supportZoom: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
                controller.addJavaScriptHandler(
                  handlerName: 'saveFile',
                  callback: (args) {
                    if (args.length >= 2) {
                      final fileName = args[0] as String;
                      final base64Data = args[1] as String;
                      _saveFile(fileName, base64Data);
                    }
                  },
                );
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100;
                });
              },
              onLoadStop: (controller, url) {
                setState(() {
                  _isLoading = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ToolItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String htmlFile;

  ToolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.htmlFile,
  });
}

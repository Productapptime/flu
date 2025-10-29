// lib/screens/tools_webview.dart
import 'package:flutter/material.dart';

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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
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
              const SizedBox(height: 12),
              Text(
                tool.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                tool.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToolDetailScreen extends StatelessWidget {
  final ToolItem tool;
  final bool darkMode;

  const ToolDetailScreen({
    super.key,
    required this.tool,
    required this.darkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tool.title),
        backgroundColor: darkMode ? Colors.black : Colors.red,
        foregroundColor: darkMode ? Colors.red : Colors.white,
        toolbarHeight: 48,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: darkMode ? Colors.red : Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: InAppWebView(
        initialFile: "assets/${tool.htmlFile}",
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          allowFileAccess: true,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
        ),
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

// Basit InAppWebView wrapper
class InAppWebView extends StatelessWidget {
  final String initialFile;
  final InAppWebViewSettings initialSettings;

  const InAppWebView({
    super.key,
    required this.initialFile,
    required this.initialSettings,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'PDF Araçları',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Araç içeriği yükleniyor...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// Basit settings class
class InAppWebViewSettings {
  final bool javaScriptEnabled;
  final bool allowFileAccess;
  final bool allowFileAccessFromFileURLs;
  final bool allowUniversalAccessFromFileURLs;

  const InAppWebViewSettings({
    this.javaScriptEnabled = true,
    this.allowFileAccess = true,
    this.allowFileAccessFromFileURLs = true,
    this.allowUniversalAccessFromFileURLs = true,
  });
}

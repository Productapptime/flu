// lib/screens/tools_webview.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ToolsWebView extends StatefulWidget {
  final bool darkMode;
  const ToolsWebView({super.key, required this.darkMode});

  @override
  State<ToolsWebView> createState() => _ToolsWebViewState();
}

class _ToolsWebViewState extends State<ToolsWebView> {
  InAppWebViewController? _controller;
  bool _loaded = false;
  String _currentTool = 'main';
  final String _baseUrl = 'file:///android_asset/flutter_assets/assets/tools.html';

  final List<ToolItem> _tools = [
    ToolItem(
      id: 'merge',
      title: 'PDF Birleştir',
      description: 'Birden fazla PDF\'yi birleştir',
      icon: Icons.merge,
      color: Colors.blue,
    ),
    ToolItem(
      id: 'split',
      title: 'PDF Ayır',
      description: 'PDF\'yi sayfalara ayır',
      icon: Icons.call_split,
      color: Colors.green,
    ),
    ToolItem(
      id: 'reorder',
      title: 'Sayfa Düzenle',
      description: 'Sayfaları sırala veya sil',
      icon: Icons.view_stream,
      color: Colors.orange,
    ),
    ToolItem(
      id: 'compress',
      title: 'PDF Sıkıştır',
      description: 'Dosya boyutunu küçült',
      icon: Icons.inventory_2,
      color: Colors.purple,
    ),
    ToolItem(
      id: 'ocr',
      title: 'OCR (Metin Çıkar)',
      description: 'PDF veya görselden metin al',
      icon: Icons.search,
      color: Colors.teal,
    ),
    ToolItem(
      id: 'image',
      title: 'PDF → Görsel',
      description: 'PDF\'yi resme dönüştür',
      icon: Icons.image,
      color: Colors.red,
    ),
  ];

  void _openTool(String toolId) {
    setState(() {
      _currentTool = toolId;
    });
    
    // WebView'e tool değişikliğini bildir
    final url = '$_baseUrl#tool=$toolId';
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  void _goBack() {
    setState(() {
      _currentTool = 'main';
    });
    
    // Ana sayfaya dön
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(_baseUrl)));
  }

  String _getCurrentUrl() {
    if (_currentTool == 'main') {
      return _baseUrl;
    } else {
      return '$_baseUrl#tool=$_currentTool';
    }
  }

  String _getAppBarTitle() {
    if (_currentTool == 'main') {
      return 'PDF Araçları';
    } else {
      final tool = _tools.firstWhere((t) => t.id == _currentTool, orElse: () => _tools[0]);
      return tool.title;
    }
  }

  Widget _buildMainPage() {
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
                  crossAxisCount: 2, // 2x3 grid
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
        onTap: () => _openTool(tool.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.left: BorderSide(
              color: tool.color,
              width: 4,
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

  Widget _buildToolPage() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: widget.darkMode ? Colors.black : Colors.red,
        foregroundColor: widget.darkMode ? Colors.red : Colors.white,
        toolbarHeight: 48,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: widget.darkMode ? Colors.red : Colors.white,
          ),
          onPressed: _goBack,
        ),
      ),
      body: Column(
        children: [
          // WebView Content
          Expanded(
            child: Stack(
              children: [
                Container(color: widget.darkMode ? Colors.black : Colors.transparent),
                
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_getCurrentUrl())),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    allowFileAccess: true,
                    allowFileAccessFromFileURLs: true,
                    allowUniversalAccessFromFileURLs: true,
                    supportZoom: true,
                    useHybridComposition: true,
                    transparentBackground: true,
                  ),
                  onWebViewCreated: (controller) {
                    _controller = controller;
                  },
                  onLoadStart: (controller, url) {
                    // URL'deki tool bilgisini al
                    final urlString = url?.toString() ?? '';
                    if (urlString.contains('#tool=')) {
                      final toolId = urlString.split('#tool=').last;
                      if (toolId != _currentTool) {
                        setState(() {
                          _currentTool = toolId;
                        });
                      }
                    } else if (_currentTool != 'main') {
                      setState(() {
                        _currentTool = 'main';
                      });
                    }
                  },
                  onLoadStop: (controller, url) {
                    setState(() => _loaded = true);
                  },
                  onConsoleMessage: (controller, message) {
                    debugPrint('TOOLS WEBVIEW: ${message.message}');
                  },
                  onLoadError: (controller, url, code, message) {
                    debugPrint('TOOLS WEBVIEW LOAD ERROR ($code): $message');
                  },
                ),
                
                if (!_loaded)
                  Center(
                    child: CircularProgressIndicator(
                      color: widget.darkMode ? Colors.red : Colors.red,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      // Floating Action Button YOK!
    );
  }

  @override
  Widget build(BuildContext context) {
    return _currentTool == 'main' ? _buildMainPage() : _buildToolPage();
  }
}

class ToolItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  ToolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

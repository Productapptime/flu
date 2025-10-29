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

  Widget _buildFlutterToolSelector() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: widget.darkMode ? Colors.grey[900] : Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: widget.darkMode 
                ? Colors.grey[800]!  // ! operator ekleyerek null olmadığını belirtiyoruz
                : Colors.grey[300]!,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Araçları Seçin:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.darkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _tools.length,
                itemBuilder: (context, index) {
                  final tool = _tools[index];
                  final isSelected = _currentTool == tool.id;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Tooltip(
                      message: tool.description,
                      child: InkWell(
                        onTap: () => _openTool(tool.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 80,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? tool.color.withOpacity(0.2)
                                : widget.darkMode 
                                    ? Colors.grey[800]!  // ! operator ekleyerek null olmadığını belirtiyoruz
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? tool.color : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              if (!widget.darkMode)
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                tool.icon,
                                size: 24,
                                color: isSelected ? tool.color : 
                                    widget.darkMode 
                                        ? Colors.grey[400]!  // ! operator ekleyerek null olmadığını belirtiyoruz
                                        : Colors.grey[600]!,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tool.title.split(' ')[0], // Sadece ilk kelime
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? tool.color : 
                                      widget.darkMode 
                                          ? Colors.grey[400]!  // ! operator ekleyerek null olmadığını belirtiyoruz
                                          : Colors.grey[600]!,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _getCurrentUrl();

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: widget.darkMode ? Colors.black : Colors.red,
        foregroundColor: widget.darkMode ? Colors.red : Colors.white,
        toolbarHeight: 48,
        leading: _currentTool != 'main' 
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: widget.darkMode ? Colors.red : Colors.white,
                ),
                onPressed: _goBack,
              )
            : null,
      ),
      body: Column(
        children: [
          // Flutter Tool Selector
          _buildFlutterToolSelector(),
          
          // WebView Content
          Expanded(
            child: Stack(
              children: [
                Container(color: widget.darkMode ? Colors.black : Colors.transparent),
                
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(url)),
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
      
      // Quick Actions - Flutter Floating Action Button
      floatingActionButton: _currentTool != 'main' 
          ? FloatingActionButton(
              onPressed: () {
                // Tool'a özel hızlı aksiyon
                _showQuickActionDialog();
              },
              backgroundColor: widget.darkMode ? Colors.red : Colors.red,
              child: const Icon(
                Icons.bolt,
                color: Colors.white,
              ),
            )
          : null,
    );
  }

  void _showQuickActionDialog() {
    final tool = _tools.firstWhere((t) => t.id == _currentTool, orElse: () => _tools[0]);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${tool.title} - Hızlı Aksiyonlar'),
        content: const Text('Bu araç için hızlı işlemler yakında eklenecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
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

  ToolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

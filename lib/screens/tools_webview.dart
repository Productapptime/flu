// lib/screens/tools_webview.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
      print('Dosya kaydediliyor: $fileName');
      print('Base64 veri uzunluğu: ${base64Data.length}');

      // Android 10+ için MANAGE_EXTERNAL_STORAGE iznini kontrol et
      if (await Permission.manageExternalStorage.isGranted) {
        await _saveToDownloads(fileName, base64Data);
      } else {
        // MANAGE_EXTERNAL_STORAGE izni yoksa uygulama dizinine kaydet
        await _saveToAppDirectory(fileName, base64Data);
      }

    } catch (e) {
      print('Dosya kaydetme hatası: $e');
      _showSnackBar('Dosya kaydedilirken hata oluştu: $e');
    }
  }

  Future<void> _saveToDownloads(String fileName, String base64Data) async {
    try {
      // Download dizinini al
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Download dizini bulunamadı');
      }

      // Dosya yolunu oluştur
      final file = File('${downloadsDir.path}/$fileName');
      
      // Base64 veriyi decode et ve dosyaya yaz
      final bytes = base64.decode(base64Data);
      await file.writeAsBytes(bytes);

      _showSnackBar('Dosya başarıyla kaydedildi: ${file.path}');
      print('Dosya kaydedildi: ${file.path}');
      print('Dosya boyutu: ${bytes.length} bytes');

    } catch (e) {
      print('Download kaydetme hatası: $e');
      // Fallback: uygulama dizinine kaydet
      await _saveToAppDirectory(fileName, base64Data);
    }
  }

  Future<void> _saveToAppDirectory(String fileName, String base64Data) async {
    try {
      // Uygulama dizinini al
      final appDir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${appDir.path}/PDF_Manager_Plus');
      
      // Dizini oluştur
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // Dosya yolunu oluştur
      final file = File('${saveDir.path}/$fileName');
      
      // Base64 veriyi decode et ve dosyaya yaz
      final bytes = base64.decode(base64Data);
      await file.writeAsBytes(bytes);

      _showSnackBar('Dosya uygulama dizinine kaydedildi: ${file.path}');
      print('Dosya uygulama dizinine kaydedildi: ${file.path}');
      print('Dosya boyutu: ${bytes.length} bytes');

    } catch (e) {
      print('Uygulama dizini kaydetme hatası: $e');
      rethrow;
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Tamam',
            onPressed: () {},
            textColor: Colors.white,
          ),
        ),
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: widget.darkMode ? Colors.red : Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
                transparentBackground: true,
                useHybridComposition: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
                
                // JavaScript handler'ını kaydet
                controller.addJavaScriptHandler(
                  handlerName: 'saveFile',
                  callback: (args) {
                    if (args.length >= 2) {
                      final fileName = args[0] as String;
                      final base64Data = args[1] as String;
                      print('JavaScript handler çağrıldı: $fileName');
                      _saveFile(fileName, base64Data);
                    } else {
                      print('JavaScript handler: Yetersiz argüman - ${args.length}');
                    }
                  },
                );
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;
                  _progress = 0;
                });
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100;
                });
              },
              onLoadStop: (controller, url) {
                setState(() {
                  _isLoading = false;
                  _progress = 1.0;
                });
                
                // JavaScript handler'ını HTML'e enjekte et
                controller.evaluateJavascript(source: '''
                  // Global saveFile fonksiyonu
                  window.saveFileToFlutter = function(fileName, base64Data) {
                    console.log('saveFileToFlutter çağrıldı:', fileName, 'base64 uzunluk:', base64Data.length);
                    
                    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                      try {
                        window.flutter_inappwebview.callHandler('saveFile', fileName, base64Data);
                        console.log('Handler başarıyla çağrıldı');
                        return true;
                      } catch (e) {
                        console.error('Handler çağrı hatası:', e);
                        return false;
                      }
                    } else {
                      console.error('Flutter handler bulunamadı');
                      alert('Flutter bağlantısı kurulamadı. Lütfen sayfayı yenileyin.');
                      return false;
                    }
                  };

                  // Mevcut butonlara event listener ekle
                  setTimeout(function() {
                    // Merge butonu
                    const mergeBtn = document.getElementById('mergeBtn');
                    if (mergeBtn) {
                      mergeBtn.addEventListener('click', function() {
                        console.log('Merge butonu tıklandı');
                      });
                    }

                    // Split butonu
                    const splitBtn = document.getElementById('splitBtn');
                    if (splitBtn) {
                      splitBtn.addEventListener('click', function() {
                        console.log('Split butonu tıklandı');
                      });
                    }

                    // Diğer butonlar...
                    console.log('JavaScript enjeksiyonu tamamlandı');
                  }, 1000);
                ''');
              },
              onLoadError: (controller, url, code, message) {
                setState(() {
                  _isLoading = false;
                });
                print('WebView Load Error: $code - $message');
              },
              onConsoleMessage: (controller, consoleMessage) {
                print('WebView Console [${widget.tool.title}]: ${consoleMessage.message}');
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

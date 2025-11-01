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
        onTap: () async {
          // Tüm dosya erişim iznini kontrol et
          final hasPermission = await _checkAllFilesAccessPermission();
          if (hasPermission) {
            // İzin varsa direkt aç
            _openToolPage(context, title, htmlFile);
          } else {
            // İzin yoksa, özel izin dialog göster
            await _showAllFilesAccessDialog(context, title, htmlFile);
          }
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

  Future<bool> _checkAllFilesAccessPermission() async {
    try {
      final status = await Permission.manageExternalStorage.status;
      return status.isGranted;
    } catch (e) {
      print('İzin kontrol hatası: $e');
      return false;
    }
  }

  Future<void> _showAllFilesAccessDialog(BuildContext context, String title, String htmlFile) async {
    await showDialog(
      context: context,
      barrierDismissible: false, // Kullanıcı dışarı tıklayamaz
      builder: (context) => AlertDialog(
        title: Column(
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.red),
            const SizedBox(height: 10),
            const Text(
              'İzin Gerekli',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PDF dosyalarınızı kaydetmek için "Tüm dosyalara erişim" iznine ihtiyacımız var.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Text(
                'Bu izin, PDF dosyalarınızı Download klasörüne kaydetmemize olanak tanır.',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('VAZGEÇ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context); // Dialog'u kapat
              await _requestAllFilesAccessPermission(context, title, htmlFile);
            },
            child: const Text('İZİN VER'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestAllFilesAccessPermission(BuildContext context, String title, String htmlFile) async {
    try {
      // Tüm dosya erişim iznini iste
      final status = await Permission.manageExternalStorage.request();
      
      if (status.isGranted) {
        // İzin verildi, sayfayı aç
        _openToolPage(context, title, htmlFile);
      } else {
        // İzin reddedildi, ayarlara yönlendir
        await _showSettingsDialog(context, title, htmlFile);
      }
    } catch (e) {
      print('İzin isteme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İzin istenirken bir hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showSettingsDialog(BuildContext context, String title, String htmlFile) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İzin Gerekli'),
        content: const Text(
          'PDF dosyalarını kaydetmek için "Tüm dosyalara erişim" iznini vermeniz gerekiyor.\n\n'
          'Lütfen ayarlardan bu izni etkinleştirin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İPTAL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('AYARLAR'),
          ),
        ],
      ),
    );
  }

  void _openToolPage(BuildContext context, String title, String htmlFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ToolWebView(
          toolName: title,
          htmlFile: htmlFile,
          dark: widget.dark,
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
  Directory? _downloadsDirectory;

  String _getWebViewUrl() {
    return 'file:///android_asset/flutter_assets/assets/${widget.htmlFile}?dark=${widget.dark}';
  }

  @override
  void initState() {
    super.initState();
    _initializeDirectory();
  }

  Future<void> _initializeDirectory() async {
    try {
      // Tüm dosya erişim izni varsa Download klasörünü kullan
      final hasPermission = await Permission.manageExternalStorage.isGranted;
      
      if (hasPermission) {
        _downloadsDirectory = await getDownloadsDirectory();
        if (_downloadsDirectory == null) {
          _downloadsDirectory = Directory('/storage/emulated/0/Download');
        }
        print('Downloads dizini kullanılıyor: ${_downloadsDirectory!.path}');
      } else {
        // İzin yoksa uygulama dizinine kaydet
        _downloadsDirectory = await getApplicationDocumentsDirectory();
        print('Uygulama dizini kullanılıyor: ${_downloadsDirectory!.path}');
      }
      
      if (!await _downloadsDirectory!.exists()) {
        await _downloadsDirectory!.create(recursive: true);
      }
    } catch (e) {
      print('Klasör hatası: $e');
      _downloadsDirectory = await getApplicationDocumentsDirectory();
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
      if (_downloadsDirectory == null) {
        await _initializeDirectory();
      }

      final cleanBase64 = base64Data.replaceFirst(RegExp(r'^data:.*?base64,'), '');
      final bytes = base64.decode(cleanBase64);
      
      final uniqueFileName = await _getUniqueFileName(fileName);
      final file = File('${_downloadsDirectory!.path}/$uniqueFileName');
      
      await file.writeAsBytes(bytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('✅ $uniqueFileName kaydedildi'),
                Text(
                  'Konum: ${_getLocationName()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'AÇ',
              textColor: Colors.white,
              onPressed: () => _openFile(file),
            ),
          ),
        );
      }
      
      print('Dosya kaydedildi: ${file.path}');
      
    } catch (e) {
      print('Dosya kaydetme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Dosya kaydedilemedi: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _saveImageFile(String fileName, String base64Data) async {
    try {
      if (_downloadsDirectory == null) {
        await _initializeDirectory();
      }

      final cleanBase64 = base64Data.replaceFirst(RegExp(r'^data:image\/[a-z]+;base64,'), '');
      final bytes = base64.decode(cleanBase64);
      
      String finalFileName = fileName;
      if (!fileName.toLowerCase().endsWith('.png') && 
          !fileName.toLowerCase().endsWith('.jpg') && 
          !fileName.toLowerCase().endsWith('.jpeg')) {
        finalFileName = '$fileName.png';
      }
      
      final uniqueFileName = await _getUniqueFileName(finalFileName);
      final file = File('${_downloadsDirectory!.path}/$uniqueFileName');
      
      await file.writeAsBytes(bytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('✅ $uniqueFileName kaydedildi'),
                Text(
                  'Konum: ${_getLocationName()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'AÇ',
              textColor: Colors.white,
              onPressed: () => _openFile(file),
            ),
          ),
        );
      }
      
      print('Görsel kaydedildi: ${file.path}');
      
    } catch (e) {
      print('Görsel kaydetme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Görsel kaydedilemedi: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _getLocationName() {
    final path = _downloadsDirectory?.path ?? '';
    if (path.contains('Download')) {
      return 'Download klasörü';
    } else {
      return 'Uygulama klasörü';
    }
  }

  Future<String> _getUniqueFileName(String fileName) async {
    final file = File('${_downloadsDirectory!.path}/$fileName');
    
    if (!await file.exists()) {
      return fileName;
    }
    
    final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^/.]+$'), '');
    final extension = fileName.substring(fileName.lastIndexOf('.'));
    
    int counter = 1;
    String newFileName;
    
    do {
      newFileName = '${nameWithoutExt}_$counter$extension';
      counter++;
    } while (await File('${_downloadsDirectory!.path}/$newFileName').exists());
    
    return newFileName;
  }

  Future<void> _openFile(File file) async {
    try {
      final result = await OpenFile.open(file.path);
      print('Dosya açma sonucu: ${result.message}');
    } catch (e) {
      print('Dosya açma hatası: $e');
    }
  }
}

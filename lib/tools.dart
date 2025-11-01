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
          // Önce izinleri kontrol et
          final hasPermission = await _checkAndRequestPermissions(context);
          if (hasPermission) {
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

  Future<bool> _checkAndRequestPermissions(BuildContext context) async {
    try {
      // Depolama izinlerini kontrol et
      var storageStatus = await Permission.storage.status;
      var manageStorageStatus = await Permission.manageExternalStorage.status;

      // İzin verilmediyse iste
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
      }

      // Android 11+ için yönetilen depolama izni
      if (!manageStorageStatus.isGranted && await Permission.manageExternalStorage.isRestricted) {
        manageStorageStatus = await Permission.manageExternalStorage.request();
      }

      // İzinler reddedildiyse kullanıcıyı bilgilir
      if (!storageStatus.isGranted) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Depolama İzni Gerekli'),
              content: const Text(
                'PDF dosyalarını kaydetmek için depolama iznine ihtiyacımız var. '
                'Lütfen ayarlardan izin verin.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Ayarlar'),
                ),
              ],
            ),
          );
        }
        return false;
      }

      return storageStatus.isGranted;
    } catch (e) {
      print('İzin kontrol hatası: $e');
      return false;
    }
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
  bool _permissionsGranted = false;

  String _getWebViewUrl() {
    return 'file:///android_asset/flutter_assets/assets/${widget.htmlFile}?dark=${widget.dark}';
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initializeDirectory();
    await _checkPermissions();
  }

  Future<void> _initializeDirectory() async {
    try {
      // Downloads dizinini al
      _downloadsDirectory = await getDownloadsDirectory();
      
      // Android 10+ için Public Downloads klasörü (fallback)
      if (_downloadsDirectory == null) {
        _downloadsDirectory = Directory('/storage/emulated/0/Download');
      }
      
      // Klasör yoksa oluştur
      if (!await _downloadsDirectory!.exists()) {
        await _downloadsDirectory!.create(recursive: true);
      }
      
      print('Downloads dizini: ${_downloadsDirectory!.path}');
    } catch (e) {
      print('Klasör hatası: $e');
      // Fallback: Uygulama dizini
      _downloadsDirectory = await getApplicationDocumentsDirectory();
    }
  }

  Future<void> _checkPermissions() async {
    try {
      // Depolama izinlerini kontrol et
      var storageStatus = await Permission.storage.status;
      var manageStorageStatus = await Permission.manageExternalStorage.status;

      setState(() {
        _permissionsGranted = storageStatus.isGranted;
      });

      if (!_permissionsGranted) {
        print('İzinler henüz verilmedi');
      }
    } catch (e) {
      print('İzin kontrol hatası: $e');
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      // Depolama izinlerini iste
      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
      }
      
      // Yönetilen depolama izni (Android 11+)
      if (await Permission.manageExternalStorage.isRestricted) {
        var manageStatus = await Permission.manageExternalStorage.status;
        if (!manageStatus.isGranted) {
          manageStatus = await Permission.manageExternalStorage.request();
        }
      }
      
      setState(() {
        _permissionsGranted = storageStatus.isGranted;
      });
      
      return storageStatus.isGranted;
    } catch (e) {
      print('İzin hatası: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.toolName),
        backgroundColor: widget.dark ? Colors.black : Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showDownloadInfo,
            tooltip: "Download Klasörünü Aç",
          ),
          IconButton(
            icon: const Icon(Icons.security),
            onPressed: _showPermissionDialog,
            tooltip: "İzinleri Kontrol Et",
          ),
        ],
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
                  await _saveFileWithPermissionCheck(fileName, base64Data);
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
                  await _saveImageFileWithPermissionCheck(fileName, base64Data);
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

  Future<void> _saveFileWithPermissionCheck(String fileName, String base64Data) async {
    // İzinleri kontrol et
    if (!_permissionsGranted) {
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        _showPermissionError();
        return;
      }
    }

    await _saveFile(fileName, base64Data);
  }

  Future<void> _saveImageFileWithPermissionCheck(String fileName, String base64Data) async {
    // İzinleri kontrol et
    if (!_permissionsGranted) {
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        _showPermissionError();
        return;
      }
    }

    await _saveImageFile(fileName, base64Data);
  }

  Future<void> _saveFile(String fileName, String base64Data) async {
    try {
      if (_downloadsDirectory == null) {
        await _initializeDirectory();
      }

      // Base64 veriyi decode et
      final cleanBase64 = base64Data.replaceFirst(RegExp(r'^data:.*?base64,'), '');
      final bytes = base64.decode(cleanBase64);
      
      // Benzersiz dosya adı oluştur
      final uniqueFileName = await _getUniqueFileName(fileName);
      final file = File('${_downloadsDirectory!.path}/$uniqueFileName');
      
      // Dosyayı kaydet
      await file.writeAsBytes(bytes);
      
      // Başarı mesajı göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('✅ $uniqueFileName kaydedildi'),
                Text(
                  'Konum: Download klasörü',
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

      // Base64 veriyi decode et
      final cleanBase64 = base64Data.replaceFirst(RegExp(r'^data:image\/[a-z]+;base64,'), '');
      final bytes = base64.decode(cleanBase64);
      
      // Dosya uzantısını kontrol et
      String finalFileName = fileName;
      if (!fileName.toLowerCase().endsWith('.png') && 
          !fileName.toLowerCase().endsWith('.jpg') && 
          !fileName.toLowerCase().endsWith('.jpeg')) {
        finalFileName = '$fileName.png';
      }
      
      // Benzersiz dosya adı oluştur
      final uniqueFileName = await _getUniqueFileName(finalFileName);
      final file = File('${_downloadsDirectory!.path}/$uniqueFileName');
      
      // Dosyayı kaydet
      await file.writeAsBytes(bytes);
      
      // Başarı mesajı göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('✅ $uniqueFileName kaydedildi'),
                Text(
                  'Konum: Download klasörü',
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

  Future<String> _getUniqueFileName(String fileName) async {
    final file = File('${_downloadsDirectory!.path}/$fileName');
    
    if (!await file.exists()) {
      return fileName;
    }
    
    // Dosya varsa, benzersiz isim oluştur
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya açılamadı: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showPermissionError() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('📁 Depolama izni gerekiyor. Lütfen izin verin.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'AYARLAR',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📁 Depolama İzinleri'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('İzin Durumu: ${_permissionsGranted ? "✅ Verildi" : "❌ Bekliyor"}'),
            const SizedBox(height: 10),
            const Text(
              'PDF dosyalarını kaydetmek için depolama izinlerine ihtiyaç var. '
              'Eğer izin verilmediyse, aşağıdaki butondan izin isteyebilirsiniz.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _requestPermissions();
            },
            child: const Text('İzin İste'),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Ayarlar'),
          ),
        ],
      ),
    );
  }

  void _showDownloadInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📁 Download Klasörü Bilgisi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yol: ${_downloadsDirectory?.path ?? "Bilinmiyor"}'),
            Text('İzinler: ${_permissionsGranted ? "✅ Var" : "❌ Yok"}'),
            const SizedBox(height: 10),
            const Text(
              'Dosyalarınız bu klasöre kaydediliyor. '
              'Dosya yöneticinizden "Download" klasörünü kontrol edin.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}

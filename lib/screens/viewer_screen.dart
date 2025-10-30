// lib/screens/viewer_screen.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewerScreen extends StatefulWidget {
  final File file;
  final String fileName;
  final bool dark;
  final VoidCallback? onFileOpened;
  const ViewerScreen({
    super.key, 
    required this.file, 
    required this.fileName, 
    required this.dark,
    this.onFileOpened,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  InAppWebViewController? _controller;
  bool _loaded = false;
  File? _savedFile;
  bool _isCheckingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onFileOpened?.call();
    });
  }

  String _makeViewerUrl() {
    final fileUri = Uri.file(widget.file.path).toString();
    final dark = widget.dark ? 'true' : 'false';
    final url = 'file:///android_asset/flutter_assets/assets/web/viewer.html?file=${Uri.encodeComponent(fileUri)}&dark=$dark';
    return url;
  }

  // İzin durumunu saklamak için SharedPreferences
  Future<bool> _hasStoragePermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_storage_permission') ?? false;
  }

  Future<void> _setStoragePermission(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_storage_permission', granted);
  }

  Future<bool> _checkRealStoragePermission() async {
    if (Platform.isAndroid) {
      return await Permission.manageExternalStorage.isGranted;
    }
    return false;
  }

  Future<void> _handleOnPdfSaved(List<dynamic> args) async {
    try {
      final originalName = args.isNotEmpty ? (args[0] as String) : widget.fileName;
      final base64Data = (args.length > 1 && args[1] != null) ? args[1] as String : null;
      
      if (base64Data == null || base64Data.isEmpty) {
        debugPrint('Base64 data boş veya null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF verisi alınamadı'))
          );
        }
        return;
      }

      // Download klasörüne kaydet
      await _savePdfToDownload(originalName, base64Data);

    } catch (e) {
      debugPrint('onPdfSaved error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydetme başarısız'))
        );
      }
    }
  }

  Future<void> _savePdfToDownload(String fileName, String base64Data) async {
    try {
      debugPrint('Dosya kaydediliyor: $fileName');
      debugPrint('Base64 veri uzunluğu: ${base64Data.length}');

      // Önce izin kontrolü yap
      final hasPermission = await _hasStoragePermission();
      final realPermission = await _checkRealStoragePermission();

      if (hasPermission && realPermission) {
        // İzin varsa direkt Download klasörüne kaydet
        final success = await _saveToDownloads(fileName, base64Data);
        if (success) return;
      }

      // İzin yoksa veya kayıt başarısızsa kullanıcıya sor
      if (!_isCheckingPermission) {
        _isCheckingPermission = true;
        final shouldRequest = await _showPermissionDialog();
        _isCheckingPermission = false;

        if (shouldRequest) {
          final granted = await _requestStoragePermission();
          if (granted) {
            final success = await _saveToDownloads(fileName, base64Data);
            if (success) return;
          }
        }
      }

      // Fallback: uygulama dizinine kaydet
      await _saveToAppDirectory(fileName, base64Data);

    } catch (e) {
      debugPrint('Dosya kaydetme hatası: $e');
      _showSnackBar('Dosya kaydedilirken hata oluştu: $e');
    }
  }

  Future<bool> _showPermissionDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.folder_open, color: Colors.blue),
              SizedBox(width: 10),
              Text('Tüm Dosya Erişimi Gerekli'),
            ],
          ),
          content: const Text(
            'PDF dosyalarınızı Download klasörüne kaydedebilmek için "Tüm Dosya Erişimi" iznine ihtiyacımız var.\n\nBu sayede tüm özellikleri tam olarak kullanabilirsiniz.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Şimdi Değil', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('İzin Ver'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<bool> _requestStoragePermission() async {
    try {
      // MANAGE_EXTERNAL_STORAGE iznini iste
      final status = await Permission.manageExternalStorage.request();
      
      if (status.isGranted) {
        await _setStoragePermission(true);
        _showSnackBar('Tüm dosya erişimi izni verildi! Artık dosyalar Download klasörünüze kaydedilecek.');
        return true;
      } else {
        // Kullanıcıyı ayarlara yönlendir
        _showSettingsDialog();
        return false;
      }
    } catch (e) {
      debugPrint('İzin isteme hatası: $e');
      return false;
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.orange),
              SizedBox(width: 10),
              Text('İzin Gerekli'),
            ],
          ),
          content: const Text(
            'Tüm dosya erişimi için ayarlardan izin vermeniz gerekiyor.\n\n"Tüm dosyalara erişim izni ver" seçeneğini aktif etmelisiniz.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ayarlara Git'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _saveToDownloads(String fileName, String base64Data) async {
    try {
      // Android Download klasörü yolunu belirle
      String downloadsPath = '/storage/emulated/0/Download';
      
      // Klasörü kontrol et
      final downloadsDir = Directory(downloadsPath);
      if (!await downloadsDir.exists()) {
        debugPrint('Download klasörü mevcut değil: $downloadsPath');
        return false;
      }

      // PDF_Manager_Plus alt klasörü oluştur
      final appDir = Directory('$downloadsPath/PDF_Manager_Plus');
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }

      // Dosya yolunu oluştur
      final file = File('${appDir.path}/$fileName');
      
      // Base64 veriyi decode et ve dosyaya yaz
      final bytes = base64.decode(base64Data);
      await file.writeAsBytes(bytes);

      // Dosyanın gerçekten yazıldığını kontrol et
      if (await file.exists()) {
        final fileSize = await file.length();
        debugPrint('Dosya başarıyla Download klasörüne kaydedildi: ${file.path}');
        debugPrint('Dosya boyutu: $fileSize bytes');
        
        _showSnackBar('Dosya Download klasörüne kaydedildi: PDF_Manager_Plus/$fileName');
        return true;
      } else {
        debugPrint('Dosya oluşturulamadı');
        return false;
      }

    } catch (e) {
      debugPrint('Download kaydetme hatası: $e');
      return false;
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

      _showSnackBar('Dosya uygulama dizinine kaydedildi. Dosya Yöneticisi > PDF_Manager_Plus klasörüne bakın.');
      debugPrint('Dosya uygulama dizinine kaydedildi: ${file.path}');
      debugPrint('Dosya boyutu: ${bytes.length} bytes');

    } catch (e) {
      debugPrint('Uygulama dizini kaydetme hatası: $e');
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

  Future<void> _printFile() async {
    try {
      final pdfData = await widget.file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (format) => pdfData,
      );
    } catch (e) {
      debugPrint('Print error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yazdırma başarısız'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _makeViewerUrl();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _savedFile);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName),
          backgroundColor: widget.dark ? Colors.black : Colors.red,
          foregroundColor: widget.dark ? Colors.red : Colors.white,
          toolbarHeight: 48,
          actions: [
            IconButton(
              icon: Icon(Icons.print,
                color: widget.dark ? Colors.red : Colors.white
              ),
              onPressed: _printFile,
            ),
            IconButton(
              icon: Icon(Icons.share,
                color: widget.dark ? Colors.red : Colors.white
              ),
              onPressed: () async {
                try {
                  await Share.shareXFiles([XFile(widget.file.path)],
                    text: 'PDF Dosyası: ${widget.fileName}'
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Paylaşım başarısız'))
                  );
                }
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            Container(color: widget.dark ? Colors.black : Colors.transparent),
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                allowFileAccess: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                supportZoom: true,
                useHybridComposition: true,
              ),
              onWebViewCreated: (controller) async {
                _controller = controller;
                controller.addJavaScriptHandler(handlerName: "onPdfSaved", callback: (args) {
                  _handleOnPdfSaved(args);
                });
              },
              onLoadStop: (controller, url) {
                setState(() => _loaded = true);
              },
              onConsoleMessage: (controller, message) {
                debugPrint('WEBVIEW: ${message.message}');
              },
              onLoadError: (controller, url, code, message) {
                debugPrint('WEBVIEW LOAD ERROR ($code): $message');
              },
            ),
            if (!_loaded)
              Center(
                child: CircularProgressIndicator(
                  color: widget.dark ? Colors.red : Colors.red
                ),
              ),
          ],
        ),
      ),
    );
  }
}

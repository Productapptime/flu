// lib/tools.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _hasStoragePermission = false;
  Directory? _appDocumentsDirectory;

  String _getWebViewUrl() {
    return 'file:///android_asset/flutter_assets/assets/${widget.htmlFile}?dark=${widget.dark}';
  }

  @override
  void initState() {
    super.initState();
    _initializeAppDirectory();
    _checkStoragePermission();
  }

  Future<void> _initializeAppDirectory() async {
    try {
      // Uygulamanın documents directory'sini al
      final directory = await getApplicationDocumentsDirectory();
      // PDF_Manager_Plus klasörü oluştur
      _appDocumentsDirectory = Directory('${directory.path}/PDF_Manager_Plus');
      if (!await _appDocumentsDirectory!.exists()) {
        await _appDocumentsDirectory!.create(recursive: true);
      }
    } catch (e) {
      print('Klasör oluşturma hatası: $e');
    }
  }

  Future<void> _checkStoragePermission() async {
    // Android 10+ için storage permission gerekli değil
    // Sadece Android 9 ve altı için kontrol ediyoruz
    if (await _isAndroid10OrAbove()) {
      setState(() {
        _hasStoragePermission = true;
      });
      return;
    }

    final status = await Permission.storage.status;
    setState(() {
      _hasStoragePermission = status.isGranted;
    });
  }

  Future<bool> _isAndroid10OrAbove() async {
    // Basit bir kontrol - Android 10 (API 29) ve üstü için storage permission gerekmez
    return true; // Modern Android versiyonları için her zaman true döndür
  }

  Future<void> _requestStoragePermission() async {
    // Android 10+ için permission gerekmez
    if (await _isAndroid10OrAbove()) {
      setState(() {
        _hasStoragePermission = true;
      });
      _controller?.reload();
      return;
    }

    final status = await Permission.storage.request();
    setState(() {
      _hasStoragePermission = status.isGranted;
    });
    
    if (status.isGranted) {
      _controller?.reload();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "📁 Uygulama Klasörüne Erişim",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "PDF dosyalarını uygulama klasörüne kaydedebilmek için izin gerekiyor.",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                "• PDF_Manager_Plus klasörüne erişim\n• Dosya kaydetme ve yönetme\n• Güvenli dosya depolama",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _requestStoragePermission();
              },
              child: const Text(
                "İzin Ver",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.toolName),
        backgroundColor: widget.dark ? Colors.black : Colors.red,
        foregroundColor: Colors.white,
        actions: [
          if (!_hasStoragePermission && !_isAndroid10OrAbove())
            IconButton(
              icon: const Icon(Icons.warning_amber_rounded),
              onPressed: _showPermissionDialog,
              tooltip: "Dosya Erişim İzni Gerekli",
            ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _openAppFolder,
            tooltip: "Uygulama Klasörünü Aç",
          ),
        ],
      ),
      body: _hasStoragePermission ? _buildWebView() : _buildPermissionRequiredView(),
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

  Widget _buildPermissionRequiredView() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            "📁 Uygulama Klasörüne Erişim",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: widget.dark ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          Text(
            "${widget.toolName} özelliğini kullanabilmek için uygulama klasörüne erişim izni gerekiyor.",
            style: TextStyle(
              fontSize: 16,
              color: widget.dark ? Colors.grey[300] : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.dark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildPermissionFeature("PDF_Manager_Plus klasörü oluşturma"),
                _buildPermissionFeature("Güvenli dosya depolama"),
                _buildPermissionFeature("Otomatik klasör yönetimi"),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Geri Dön"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _requestStoragePermission,
                  child: const Text(
                    "İzin Ver",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: widget.dark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFile(String fileName, String base64Data) async {
    try {
      if (_appDocumentsDirectory == null) {
        await _initializeAppDirectory();
      }

      // Base64 veriyi decode et
      final bytes = base64.decode(base64Data);
      
      // Uygulama klasörüne kaydet
      final file = File('${_appDocumentsDirectory!.path}/$fileName');
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
                  'Konum: PDF_Manager_Plus klasörü',
                  style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Klasörü Aç',
              textColor: Colors.white,
              onPressed: _openAppFolder,
            ),
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

  void _openAppFolder() {
    if (_appDocumentsDirectory != null && _appDocumentsDirectory!.existsSync()) {
      // Klasör içeriğini göster
      _showFolderContents();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📁 Uygulama klasörü henüz oluşturulmadı'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showFolderContents() {
    if (_appDocumentsDirectory == null) return;

    final files = _appDocumentsDirectory!.listSync();
    final fileList = files.whereType<File>().toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📁 PDF_Manager_Plus Klasörü'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: fileList.isEmpty
              ? const Center(child: Text('Henüz dosya yok'))
              : ListView.builder(
                  itemCount: fileList.length,
                  itemBuilder: (context, index) {
                    final file = fileList[index];
                    final size = (file.lengthSync() / 1024).toStringAsFixed(1);
                    return ListTile(
                      leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      title: Text(file.uri.pathSegments.last),
                      subtitle: Text('$size KB'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteFile(file),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _deleteFile(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dosyayı Sil'),
        content: Text('${file.uri.pathSegments.last} silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              file.deleteSync();
              Navigator.pop(context);
              _showFolderContents(); // Listeyi yenile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ Dosya silindi'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

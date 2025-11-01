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
        onTap: () {
          _openToolPage(context, title, htmlFile);
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
  Directory? _pdfManagerPlusDir;

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
      // Documents klasörü içinde PDF_Manager_Plus klasörü oluştur
      final documentsDir = await getApplicationDocumentsDirectory();
      _pdfManagerPlusDir = Directory('${documentsDir.path}/PDF_Manager_Plus');
      
      // Klasörü oluştur
      if (!await _pdfManagerPlusDir!.exists()) {
        await _pdfManagerPlusDir!.create(recursive: true);
        print('PDF_Manager_Plus klasörü oluşturuldu: ${_pdfManagerPlusDir!.path}');
      } else {
        print('PDF_Manager_Plus klasörü zaten var: ${_pdfManagerPlusDir!.path}');
      }
    } catch (e) {
      print('Klasör hatası: $e');
      // Fallback: direkt documents directory
      _pdfManagerPlusDir = await getApplicationDocumentsDirectory();
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
            icon: Icon(Icons.folder_open),
            onPressed: _openPdfManagerPlusFolder,
            tooltip: "PDF_Manager_Plus Klasörünü Aç",
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
          Center(
            child: CircularProgressIndicator(color: Colors.red),
          ),
      ],
    );
  }

  Future<void> _saveFile(String fileName, String base64Data) async {
    try {
      if (_pdfManagerPlusDir == null) {
        await _initializeDirectory();
      }

      final cleanBase64 = base64Data.replaceFirst(RegExp(r'^data:.*?base64,'), '');
      final bytes = base64.decode(cleanBase64);
      
      final uniqueFileName = await _getUniqueFileName(fileName);
      final file = File('${_pdfManagerPlusDir!.path}/$uniqueFileName');
      
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
                  'Konum: PDF_Manager_Plus klasörü',
                  style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
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
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _saveImageFile(String fileName, String base64Data) async {
    try {
      if (_pdfManagerPlusDir == null) {
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
      final file = File('${_pdfManagerPlusDir!.path}/$uniqueFileName');
      
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
                  'Konum: PDF_Manager_Plus klasörü',
                  style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
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
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<String> _getUniqueFileName(String fileName) async {
    final file = File('${_pdfManagerPlusDir!.path}/$fileName');
    
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
    } while (await File('${_pdfManagerPlusDir!.path}/$newFileName').exists());
    
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

  Future<void> _openPdfManagerPlusFolder() async {
    try {
      if (_pdfManagerPlusDir != null && await _pdfManagerPlusDir!.exists()) {
        // Klasör içeriğini göster
        _showFolderContents();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF_Manager_Plus klasörü henüz oluşturulmadı'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Klasör açma hatası: $e');
    }
  }

  void _showFolderContents() {
    if (_pdfManagerPlusDir == null) return;

    final files = _pdfManagerPlusDir!.listSync();
    final fileList = files.whereType<File>().toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📁 PDF_Manager_Plus Klasörü'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: fileList.isEmpty
              ? Center(child: Text('Henüz dosya yok'))
              : ListView.builder(
                  itemCount: fileList.length,
                  itemBuilder: (context, index) {
                    final file = fileList[index];
                    final size = (file.lengthSync() / 1024).toStringAsFixed(1);
                    final fileName = file.uri.pathSegments.last;
                    final modified = DateTime.fromMillisecondsSinceEpoch(file.lastModifiedSync());
                    final formattedDate = '${modified.day}/${modified.month}/${modified.year} ${modified.hour}:${modified.minute}';
                    
                    // Dosya türüne göre ikon belirle
                    IconData icon;
                    Color iconColor;
                    if (fileName.toLowerCase().endsWith('.pdf')) {
                      icon = Icons.picture_as_pdf;
                      iconColor = Colors.red;
                    } else if (fileName.toLowerCase().endsWith('.png') || 
                               fileName.toLowerCase().endsWith('.jpg') ||
                               fileName.toLowerCase().endsWith('.jpeg')) {
                      icon = Icons.image;
                      iconColor = Colors.green;
                    } else {
                      icon = Icons.insert_drive_file;
                      iconColor = Colors.blue;
                    }
                    
                    return ListTile(
                      leading: Icon(icon, color: iconColor),
                      title: Text(fileName),
                      subtitle: Text('$size KB • $formattedDate'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteFile(file),
                      ),
                      onTap: () => _openFile(file),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kapat'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showFolderPath();
            },
            child: Text('Yol Göster'),
          ),
        ],
      ),
    );
  }

  void _showFolderPath() {
    if (_pdfManagerPlusDir == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📁 Klasör Yolu'),
        content: SelectableText(
          _pdfManagerPlusDir!.path,
          style: TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _deleteFile(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dosyayı Sil'),
        content: Text('${file.uri.pathSegments.last} silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              file.deleteSync();
              Navigator.pop(context);
              _showFolderContents(); // Listeyi yenile
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🗑️ Dosya silindi'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

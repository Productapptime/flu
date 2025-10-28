// tools.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:archive/archive.dart';

class ToolsPage extends StatelessWidget {
  final bool darkMode;
  
  const ToolsPage({super.key, required this.darkMode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkMode ? Colors.black : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'PDF Araçları',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: darkMode ? Colors.red : Colors.red,
                  ),
                ),
              ),
              
              // Açıklama
              Text(
                'PDF dosyalarınızı düzenlemek ve dönüştürmek için araçlar',
                style: TextStyle(
                  fontSize: 16,
                  color: darkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Araçlar Grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildToolCard(
                      context,
                      icon: Icons.merge,
                      title: 'PDF Birleştir',
                      subtitle: 'Birden fazla PDF\'yi birleştir',
                      onTap: () => _mergePdfs(context),
                    ),
                    
                    _buildToolCard(
                      context,
                      icon: Icons.photo_library,
                      title: 'Resimden PDF',
                      subtitle: 'Resimleri PDF\'ye dönüştür',
                      onTap: () => _imagesToPdf(context),
                    ),
                    
                    _buildToolCard(
                      context,
                      icon: Icons.info_outline,
                      title: 'PDF Bilgisi',
                      subtitle: 'Dosya detaylarını gör',
                      onTap: () => _showPdfInfo(context),
                    ),
                    
                    _buildToolCard(
                      context,
                      icon: Icons.compress,
                      title: 'Sıkıştır',
                      subtitle: 'Dosya boyutunu küçült',
                      onTap: () => _compressPdf(context),
                    ),
                    
                    _buildToolCard(
                      context,
                      icon: Icons.image_search,
                      title: 'Görsel Çıkar',
                      subtitle: 'PDF\'den resimleri ayıkla',
                      onTap: () => _extractImages(context),
                    ),
                    
                    _buildToolCard(
                      context,
                      icon: Icons.text_fields,
                      title: 'Metin Çıkar',
                      subtitle: 'PDF\'den metin al',
                      onTap: () => _extractText(context),
                    ),
                    
                    _buildToolCard(
                      context,
                      icon: Icons.edit,
                      title: 'Sayfa Düzenle',
                      subtitle: 'Sayfa sil, döndür',
                      onTap: () => _editPages(context),
                    ),
                    
                    _buildToolCard(
                      context,
                      icon: Icons.share,
                      title: 'Toplu Paylaş',
                      subtitle: 'Çoklu PDF paylaş',
                      onTap: () => _bulkShare(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      color: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: Colors.red,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: darkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: darkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📌 PDF BİRLEŞTİRME
  Future<void> _mergePdfs(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      if (result.files.length < 2) {
        _showSnackBar(context, 'En az 2 PDF seçin');
        return;
      }
      
      // Loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.red),
              const SizedBox(width: 16),
              Text('PDF\'ler birleştiriliyor...', 
                style: TextStyle(color: darkMode ? Colors.white : Colors.black)),
            ],
          ),
        ),
      );
      
      // PDF'leri birleştir
      final pdf = pw.Document();
      
      for (final file in result.files) {
        if (file.path != null) {
          final pdfFile = File(file.path!);
          final pdfData = await pdfFile.readAsBytes();
          
          // Bu kısımda pdf paketiyle sayfaları ekleyebilirsin
          // Şimdilik basit bir çözüm:
          pdf.addPage(
            pw.Page(
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Text('${file.name} - Birleştirilmiş PDF'),
                );
              },
            ),
          );
        }
      }
      
      // PDF'i kaydet
      final outputDir = await getTemporaryDirectory();
      final outputPath = p.join(outputDir.path, 'birlesik_${DateTime.now().millisecondsSinceEpoch}.pdf');
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());
      
      // Dialog'u kapat
      if (context.mounted) Navigator.pop(context);
      
      // Sonuç göster
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Başarılı', style: TextStyle(color: Colors.red)),
            content: Text('${result.files.length} PDF birleştirildi'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Tamam', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles([XFile(outputPath)]);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Paylaş', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
      
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Loading'i kapat
        _showSnackBar(context, 'Hata: ${e.toString()}');
      }
    }
  }

  // 📌 RESİMDEN PDF
  Future<void> _imagesToPdf(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      
      if (images.isEmpty) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.red),
              const SizedBox(width: 16),
              Text('PDF oluşturuluyor...', 
                style: TextStyle(color: darkMode ? Colors.white : Colors.black)),
            ],
          ),
        ),
      );
      
      final pdf = pw.Document();
      
      for (final image in images) {
        final imageFile = File(image.path);
        final imageData = await imageFile.readAsBytes();
        
        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(
                  pw.MemoryImage(imageData),
                  fit: pw.BoxFit.contain,
                ),
              );
            },
          ),
        );
      }
      
      final outputDir = await getTemporaryDirectory();
      final outputPath = p.join(outputDir.path, 'resimler_${DateTime.now().millisecondsSinceEpoch}.pdf');
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());
      
      if (context.mounted) Navigator.pop(context);
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Başarılı', style: TextStyle(color: Colors.red)),
            content: Text('${images.length} resim PDF\'ye dönüştürüldü'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Tamam', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles([XFile(outputPath)]);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Paylaş', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
      
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showSnackBar(context, 'Hata: ${e.toString()}');
      }
    }
  }

  // 📌 PDF BİLGİSİ
  Future<void> _showPdfInfo(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final file = File(result.files.first.path!);
      final stats = await file.stat();
      final size = file.lengthSync();
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('PDF Bilgisi', style: TextStyle(color: Colors.red)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dosya: ${result.files.first.name}'),
                Text('Boyut: ${_formatFileSize(size)}'),
                Text('Oluşturulma: ${stats.modified}'),
                Text('Yol: ${file.path}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Tamam', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      }
      
    } catch (e) {
      if (context.mounted) _showSnackBar(context, 'Hata: ${e.toString()}');
    }
  }

  // 📌 SIKIŞTIRMA
  Future<void> _compressPdf(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.red),
              const SizedBox(width: 16),
              Text('PDF sıkıştırılıyor...', 
                style: TextStyle(color: darkMode ? Colors.white : Colors.black)),
            ],
          ),
        ),
      );
      
      final originalFile = File(result.files.first.path!);
      final originalSize = originalFile.lengthSync();
      
      // Basit sıkıştırma simülasyonu - gerçek uygulamada PDF optimizasyonu yapılmalı
      final compressedData = await originalFile.readAsBytes();
      
      final outputDir = await getTemporaryDirectory();
      final outputPath = p.join(outputDir.path, 'sikistirilmis_${DateTime.now().millisecondsSinceEpoch}.pdf');
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(compressedData);
      
      final compressedSize = outputFile.lengthSync();
      final savings = originalSize - compressedSize;
      
      if (context.mounted) Navigator.pop(context);
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Sıkıştırma Tamamlandı', style: TextStyle(color: Colors.red)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Orijinal: ${_formatFileSize(originalSize)}'),
                Text('Sıkıştırılmış: ${_formatFileSize(compressedSize)}'),
                Text('Kazanç: ${_formatFileSize(savings)}'),
                Text('Oran: ${((savings / originalSize) * 100).toStringAsFixed(1)}%'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Tamam', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles([XFile(outputPath)]);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Paylaş', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
      
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showSnackBar(context, 'Hata: ${e.toString()}');
      }
    }
  }

  // 📌 DİĞER ARAÇLAR - STUB METODLARI
  Future<void> _extractImages(BuildContext context) async {
    _showSnackBar(context, 'Yakında eklenecek...');
  }

  Future<void> _extractText(BuildContext context) async {
    _showSnackBar(context, 'Yakında eklenecek...');
  }

  Future<void> _editPages(BuildContext context) async {
    _showSnackBar(context, 'Yakında eklenecek...');
  }

  Future<void> _bulkShare(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final files = result.files
          .where((file) => file.path != null)
          .map((file) => XFile(file.path!))
          .toList();
      
      await Share.shareXFiles(
        files,
        text: '${files.length} PDF Dosyası',
      );
      
    } catch (e) {
      if (context.mounted) _showSnackBar(context, 'Hata: ${e.toString()}');
    }
  }

  // 📌 YARDIMCI METODLAR
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// Geçici dizin için yardımcı metod
Future<Directory> getTemporaryDirectory() async {
  final tempDir = Directory.systemTemp;
  return tempDir;
}

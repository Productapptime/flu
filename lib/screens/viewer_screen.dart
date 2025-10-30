// lib/screens/viewer_screen.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

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

  Future<void> _handleOnPdfSaved(List<dynamic> args) async {
    try {
      final originalName = args.isNotEmpty ? (args[0] as String) : widget.fileName;
      final base64Data = (args.length > 1 && args[1] != null) ? args[1] as String : null;
      final dir = widget.file.parent.path;
      final savedName = 'update_$originalName';
      final newPath = p.join(dir, savedName);

      if (base64Data != null && base64Data.isNotEmpty) {
        final bytes = base64Decode(base64Data);
        final f = await File(newPath).writeAsBytes(bytes);
        _savedFile = f;
      } else {
        final f = await widget.file.copy(newPath);
        _savedFile = f;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.basename(_savedFile!.path)} kaydedildi')));
      }
    } catch (e) {
      debugPrint('onPdfSaved error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydetme başarısız')));
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

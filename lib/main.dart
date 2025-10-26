import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PDFApp());
}

class PDFApp extends StatelessWidget {
  const PDFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF Manager + PDF.js',
      home: PDFHome(),
    );
  }
}

class PDFHome extends StatefulWidget {
  const PDFHome({super.key});

  @override
  State<PDFHome> createState() => _PDFHomeState();
}

class _PDFHomeState extends State<PDFHome> {
  InAppWebViewController? webViewController;
  bool isLoaded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PDF Manager + PDF.js',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.red,
      ),
      body: Stack(
        children: [
          InAppWebView(
            // 📂 assets/web/index.html dosyasını açıyoruz
            initialFile: "assets/web/index.html",

            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              allowFileAccess: true,
              useOnDownloadStart: true,
              mediaPlaybackRequiresUserGesture: false,
              transparentBackground: true,
              supportZoom: false, // CSS bozulmasın diye zoom kapalı
            ),

            onWebViewCreated: (controller) {
              webViewController = controller;
            },

            onLoadStop: (controller, url) async {
              setState(() => isLoaded = true);
              debugPrint("✅ Sayfa yüklendi: $url");
            },

            onConsoleMessage: (controller, message) {
              debugPrint("🌐 [WebView Log] ${message.message}");
            },

            // 🔹 Dosya seçici (input type=file) desteği
            androidOnShowFileChooser:
                (controller, fileChooserParams) async {
              return null; // Android’in kendi picker’ını açar
            },
          ),

          // ⏳ Yüklenme göstergesi
          if (!isLoaded)
            const Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),
        ],
      ),
    );
  }
}

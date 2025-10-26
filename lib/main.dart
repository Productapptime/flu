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
        title: const Text('PDF Manager + PDF.js'),
        backgroundColor: Colors.red,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialFile: "assets/web/index.html",
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              allowFileAccess: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              mediaPlaybackRequiresUserGesture: false,
              transparentBackground: true,
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStop: (controller, url) {
              setState(() => isLoaded = true);
            },
            onConsoleMessage: (controller, message) {
              debugPrint("WEBVIEW LOG: ${message.message}");
            },

            // 👇 Yeni parametre ismi (6.1.5 için)
            onShowFileChooser: (controller, params) async {
              return null; // Android dosya seçici açılır
            },
          ),
          if (!isLoaded)
            const Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),
        ],
      ),
    );
  }
}

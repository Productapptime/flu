// lib/screens/tools_webview.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ToolsWebView extends StatefulWidget {
  final bool darkMode;
  const ToolsWebView({super.key, required this.darkMode});

  @override
  State<ToolsWebView> createState() => _ToolsWebViewState();
}

class _ToolsWebViewState extends State<ToolsWebView> {
  InAppWebViewController? _controller;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final url = 'file:///android_asset/flutter_assets/assets/tools.html';

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Araçları'),
        backgroundColor: widget.darkMode ? Colors.black : Colors.red,
        foregroundColor: widget.darkMode ? Colors.red : Colors.white,
        toolbarHeight: 48,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
            color: widget.darkMode ? Colors.red : Colors.white
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Container(color: widget.darkMode ? Colors.black : Colors.transparent),
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
            onWebViewCreated: (controller) {
              _controller = controller;
            },
            onLoadStop: (controller, url) {
              setState(() => _loaded = true);
            },
            onConsoleMessage: (controller, message) {
              debugPrint('TOOLS WEBVIEW: ${message.message}');
            },
            onLoadError: (controller, url, code, message) {
              debugPrint('TOOLS WEBVIEW LOAD ERROR ($code): $message');
            },
          ),
          if (!_loaded)
            Center(
              child: CircularProgressIndicator(
                color: widget.darkMode ? Colors.red : Colors.red
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PdfManagerApp());
}

class PdfManagerApp extends StatefulWidget {
  const PdfManagerApp({super.key});

  @override
  State<PdfManagerApp> createState() => _PdfManagerAppState();
}

class _PdfManagerAppState extends State<PdfManagerApp> {
  ThemeMode _themeMode = ThemeMode.light;
  String _language = 'en';
  final List<File> _pdfFiles = [];
  final List<File> _recentFiles = [];
  final List<File> _favoriteFiles = [];
  int _selectedIndex = 0;

  void _toggleTheme(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  void _setLanguage(String lang) {
    setState(() => _language = lang);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Language set to ${lang.toUpperCase()}')),
    );
  }

  void _addPdfFile(File file) {
    if (!_pdfFiles.any((f) => f.path == file.path)) {
      setState(() {
        _pdfFiles.add(file);
        _recentFiles.insert(0, file);
      });
    }
  }

  void _toggleFavorite(File file) {
    setState(() {
      if (_favoriteFiles.contains(file)) {
        _favoriteFiles.remove(file);
      } else {
        _favoriteFiles.add(file);
      }
    });
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager Plus',
      theme: ThemeData(primarySwatch: Colors.red, brightness: Brightness.light),
      darkTheme: ThemeData(primarySwatch: Colors.red, brightness: Brightness.dark),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: PdfHomePage(
        pdfFiles: _pdfFiles,
        recentFiles: _recentFiles,
        favoriteFiles: _favoriteFiles,
        onImport: _addPdfFile,
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
        language: _language,
        onLanguageChange: _setLanguage,
        onFavoriteToggle: _toggleFavorite,
        selectedIndex: _selectedIndex,
        onNavTap: _onNavTap,
      ),
    );
  }
}

class PdfHomePage extends StatelessWidget {
  final List<File> pdfFiles;
  final List<File> recentFiles;
  final List<File> favoriteFiles;
  final Function(File) onImport;
  final Function(File) onFavoriteToggle;
  final bool isDark;
  final Function(bool) onToggleTheme;
  final String language;
  final Function(String) onLanguageChange;
  final int selectedIndex;
  final Function(int) onNavTap;

  const PdfHomePage({
    super.key,
    required this.pdfFiles,
    required this.recentFiles,
    required this.favoriteFiles,
    required this.onImport,
    required this.onFavoriteToggle,
    required this.isDark,
    required this.onToggleTheme,
    required this.language,
    required this.onLanguageChange,
    required this.selectedIndex,
    required this.onNavTap,
  });

  Future<void> _importFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        onImport(file);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported: ${p.basename(file.path)}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File import failed')),
      );
    }
  }

  void _openViewer(BuildContext context, File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewerScreen(
          file: file,
          fileName: p.basename(file.path),
          dark: isDark,
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('About PDF Manager Plus'),
        content: const Text('Simple and elegant PDF manager with built-in viewer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('English'),
              onTap: () {
                onLanguageChange('en');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Türkçe'),
              onTap: () {
                onLanguageChange('tr');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(BuildContext context, List<File> files) {
    if (files.isEmpty) {
      return const Center(child: Text('No files available'));
    }
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final isFav = favoriteFiles.contains(file);
        return ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
          title: Text(p.basename(file.path)),
          subtitle: Text(file.path),
          trailing: IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: Colors.red),
            onPressed: () => onFavoriteToggle(file),
          ),
          onTap: () => _openViewer(context, file),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildFileList(context, pdfFiles),
      _buildFileList(context, recentFiles),
      _buildFileList(context, favoriteFiles),
      const Center(child: Text('Tools coming soon...')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Manager Plus'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.red),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 22)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Import File'),
              onTap: () {
                Navigator.pop(context);
                _importFile(context);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.brightness_6),
              title: const Text('Dark / Light Mode'),
              value: isDark,
              onChanged: onToggleTheme,
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              subtitle: Text(language.toUpperCase()),
              onTap: () {
                Navigator.pop(context);
                _showLanguageSelector(context);
              },
            ),
          ],
        ),
      ),
      body: tabs[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        onTap: onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'All Files'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Recent'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Tools'),
        ],
      ),
    );
  }
}

class ViewerScreen extends StatefulWidget {
  final File file;
  final String fileName;
  final bool dark;

  const ViewerScreen({
    super.key,
    required this.file,
    required this.fileName,
    required this.dark,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  InAppWebViewController? _controller;
  bool _loaded = false;

  String _makeViewerUrl() {
    final fileUri = Uri.file(widget.file.path).toString();
    final dark = widget.dark ? 'true' : 'false';
    return 'file:///android_asset/flutter_assets/assets/web/viewer.html?file=${Uri.encodeComponent(fileUri)}&dark=$dark';
  }

  @override
  Widget build(BuildContext context) {
    final url = _makeViewerUrl();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: widget.dark ? Colors.black : Colors.red,
        foregroundColor: widget.dark ? Colors.red : Colors.white,
      ),
      body: Stack(
        children: [
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
            onWebViewCreated: (controller) => _controller = controller,
            onLoadStop: (controller, url) => setState(() => _loaded = true),
            onConsoleMessage: (controller, message) => debugPrint('WEBVIEW: ${message.message}'),
            onLoadError: (controller, url, code, message) =>
                debugPrint('LOAD ERROR: $message'),
          ),
          if (!_loaded)
            const Center(child: CircularProgressIndicator(color: Colors.red)),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.storage.request();
  runApp(const PdfManagerPlusApp());
}

class PdfManagerPlusApp extends StatefulWidget {
  const PdfManagerPlusApp({super.key});

  @override
  State<PdfManagerPlusApp> createState() => _PdfManagerPlusAppState();
}

class _PdfManagerPlusAppState extends State<PdfManagerPlusApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager Plus',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: PdfHomePage(
        isDark: _themeMode == ThemeMode.dark,
        onThemeToggle: _toggleTheme,
      ),
    );
  }
}

class PdfHomePage extends StatefulWidget {
  final bool isDark;
  final Function(bool) onThemeToggle;

  const PdfHomePage({super.key, required this.isDark, required this.onThemeToggle});

  @override
  State<PdfHomePage> createState() => _PdfHomePageState();
}

class _PdfHomePageState extends State<PdfHomePage> {
  List<String> pdfFiles = [];
  List<String> favorites = [];
  List<String> recents = [];
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      pdfFiles = prefs.getStringList('pdfFiles') ?? [];
      favorites = prefs.getStringList('favorites') ?? [];
      recents = prefs.getStringList('recents') ?? [];
    });
  }

  Future<void> _saveLists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pdfFiles', pdfFiles);
    await prefs.setStringList('favorites', favorites);
    await prefs.setStringList('recents', recents);
  }

  Future<void> _importPdf() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Depolama izni gerekli.")),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      if (!pdfFiles.contains(path)) {
        setState(() => pdfFiles.add(path));
        await _saveLists();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF eklendi: ${result.files.single.name}')));
    }
  }

  void _openPdf(String path) async {
    if (!recents.contains(path)) {
      setState(() {
        recents.insert(0, path);
      });
      await _saveLists();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(pdfPath: path),
      ),
    );
  }

  void _toggleFavorite(String path) async {
    setState(() {
      favorites.contains(path) ? favorites.remove(path) : favorites.add(path);
    });
    await _saveLists();
  }

  Widget _buildPdfList(List<String> list) {
    if (list.isEmpty) {
      return const Center(child: Text("Henüz PDF bulunmuyor."));
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final path = list[i];
        final name = path.split('/').last;
        final isFav = favorites.contains(path);
        return ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
          title: Text(name),
          trailing: IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null),
            onPressed: () => _toggleFavorite(path),
          ),
          onTap: () => _openPdf(path),
        );
      },
    );
  }

  Widget get _activeBody {
    switch (currentIndex) {
      case 1:
        return _buildPdfList(recents);
      case 2:
        return _buildPdfList(favorites);
      default:
        return _buildPdfList(pdfFiles);
    }
  }

  Widget _buildDrawer() => Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.indigo),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PDF Manager Plus',
                  style: const TextStyle(color: Colors.white, fontSize: 22),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text("PDF Ekle"),
              onTap: () {
                Navigator.pop(context);
                _importPdf();
              },
            ),
            SwitchListTile(
              title: const Text('Karanlık Mod'),
              secondary: const Icon(Icons.brightness_6),
              value: widget.isDark,
              onChanged: widget.onThemeToggle,
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text("Hakkında"),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'PDF Manager Plus',
                applicationVersion: '1.0.0',
                children: const [
                  Text("Cihazdan PDF import edip PDF.js (InAppWebView) ile görüntüler."),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(["Tüm Dosyalar", "Son Açılanlar", "Favoriler"][currentIndex]),
        actions: [
          IconButton(onPressed: _importPdf, icon: const Icon(Icons.add)),
        ],
      ),
      drawer: _buildDrawer(),
      body: _activeBody,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => setState(() => currentIndex = i),
        selectedItemColor: Colors.indigo,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: "Tümü"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Son"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favori"),
        ],
      ),
    );
  }
}

class PdfViewerScreen extends StatelessWidget {
  final String pdfPath;

  const PdfViewerScreen({super.key, required this.pdfPath});

  @override
  Widget build(BuildContext context) {
    final pdfUrl = Uri.file(pdfPath).toString();
    final viewerPath = "assets/web/viewer.html?file=$pdfUrl";

    return Scaffold(
      appBar: AppBar(title: Text(pdfPath.split('/').last)),
      body: InAppWebView(
        initialFile: viewerPath,
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
        ),
      ),
    );
  }
}

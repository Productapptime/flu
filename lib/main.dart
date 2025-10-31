import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.manageExternalStorage.request();
  await Permission.storage.request();
  runApp(const PdfManagerPlusApp());
}

class PdfManagerPlusApp extends StatelessWidget {
  const PdfManagerPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager Plus',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const PdfHomePage(),
    );
  }
}

class PdfHomePage extends StatefulWidget {
  const PdfHomePage({super.key});

  @override
  State<PdfHomePage> createState() => _PdfHomePageState();
}

class _PdfHomePageState extends State<PdfHomePage> {
  int _selectedIndex = 0;
  List<String> allFiles = [];
  List<String> favorites = [];
  List<String> recents = [];

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      allFiles = prefs.getStringList('allFiles') ?? [];
      favorites = prefs.getStringList('favorites') ?? [];
      recents = prefs.getStringList('recents') ?? [];
    });
  }

  Future<void> _saveLists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('allFiles', allFiles);
    await prefs.setStringList('favorites', favorites);
    await prefs.setStringList('recents', recents);
  }

  Future<void> _importPdf() async {
    // Depolama izni kontrolü
    final storageStatus = await Permission.storage.request();
    if (!storageStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Depolama izni verilmedi.")),
      );
      return;
    }

    try {
      // PDF seç
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        if (!allFiles.contains(path)) {
          setState(() => allFiles.add(path));
          await _saveLists();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF eklendi: ${result.files.single.name}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF seçilemedi: $e')),
      );
    }
  }

  void _openPdf(String path) async {
    if (!recents.contains(path)) {
      setState(() => recents.insert(0, path));
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
      favorites.contains(path)
          ? favorites.remove(path)
          : favorites.add(path);
    });
    await _saveLists();
  }

  Widget _buildPdfList(List<String> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text("Henüz PDF bulunmuyor."),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final path = list[index];
        final name = path.split('/').last;
        final isFav = favorites.contains(path);

        return ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
          title: Text(name),
          trailing: IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.red : null,
            ),
            onPressed: () => _toggleFavorite(path),
          ),
          onTap: () => _openPdf(path),
        );
      },
    );
  }

  Widget get _activeBody {
    switch (_selectedIndex) {
      case 1:
        return _buildPdfList(recents);
      case 2:
        return _buildPdfList(favorites);
      default:
        return _buildPdfList(allFiles);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(["All Files", "Recent", "Favorites"][_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: "PDF Import",
            onPressed: _importPdf,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PDF Manager Plus',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Import PDF'),
              onTap: () {
                Navigator.pop(context);
                _importPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'PDF Manager Plus',
                applicationVersion: '1.0.0',
                children: const [
                  Text("Cihazdan PDF import edip PDF.js ile açar."),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _activeBody,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.folder), label: "All Files"),
          BottomNavigationBarItem(
              icon: Icon(Icons.access_time), label: "Recent"),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite), label: "Favorites"),
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
    final viewerUrl = "assets/web/viewer.html?file=$pdfUrl";

    return Scaffold(
      appBar: AppBar(title: Text(pdfPath.split('/').last)),
      body: InAppWebView(
        initialFile: viewerUrl,
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
          cacheEnabled: true,
        ),
      ),
    );
  }
}

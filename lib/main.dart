import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔐 İzinleri iste
  await _requestPermissions();

  runApp(const PdfManagerPlusApp());
}

Future<void> _requestPermissions() async {
  if (await Permission.manageExternalStorage.isDenied) {
    await Permission.manageExternalStorage.request();
  }
  if (await Permission.storage.isDenied) {
    await Permission.storage.request();
  }
}

class PdfManagerPlusApp extends StatelessWidget {
  const PdfManagerPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager Plus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
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
  List<String> favoriteFiles = [];
  List<String> recentFiles = [];

  @override
  void initState() {
    super.initState();
    _loadSavedLists();
  }

  Future<void> _loadSavedLists() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      allFiles = prefs.getStringList('allFiles') ?? [];
      favoriteFiles = prefs.getStringList('favoriteFiles') ?? [];
      recentFiles = prefs.getStringList('recentFiles') ?? [];
    });
  }

  Future<void> _saveLists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('allFiles', allFiles);
    await prefs.setStringList('favoriteFiles', favoriteFiles);
    await prefs.setStringList('recentFiles', recentFiles);
  }

  Future<void> _importPdf() async {
    final manageStatus = await Permission.manageExternalStorage.request();
    final storageStatus = await Permission.storage.request();

    if (!manageStatus.isGranted && !storageStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Depolama izni verilmedi.")),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        if (!allFiles.contains(filePath)) {
          setState(() {
            allFiles.add(filePath);
          });
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

  void _openPdf(String filePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(pdfPath: filePath),
      ),
    );
  }

  Widget _buildFileList(List<String> files) {
    if (files.isEmpty) {
      return const Center(child: Text("Henüz PDF bulunmuyor."));
    }

    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final fileName = path.basename(files[index]);
        return ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
          title: Text(fileName),
          subtitle: Text(files[index]),
          trailing: IconButton(
            icon: Icon(
              favoriteFiles.contains(files[index])
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: Colors.pinkAccent,
            ),
            onPressed: () {
              setState(() {
                if (favoriteFiles.contains(files[index])) {
                  favoriteFiles.remove(files[index]);
                } else {
                  favoriteFiles.add(files[index]);
                }
              });
              _saveLists();
            },
          ),
          onTap: () => _openPdf(files[index]),
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildFileList(allFiles);
      case 1:
        return _buildFileList(recentFiles);
      case 2:
        return _buildFileList(favoriteFiles);
      default:
        return const Center(child: Text("Bilinmeyen sekme"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? "All Files"
              : _selectedIndex == 1
                  ? "Recent"
                  : "Favorites",
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _importPdf,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: const [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Center(
                child: Text(
                  'PDF Manager Plus',
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
              ),
            ),
            ListTile(leading: Icon(Icons.settings), title: Text("Ayarlar")),
            ListTile(leading: Icon(Icons.info), title: Text("Hakkında")),
          ],
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.folder), label: "All Files"),
          NavigationDestination(
              icon: Icon(Icons.access_time), label: "Recent"),
          NavigationDestination(
              icon: Icon(Icons.favorite), label: "Favorites"),
        ],
      ),
    );
  }
}

class PdfViewerPage extends StatelessWidget {
  final String pdfPath;
  const PdfViewerPage({super.key, required this.pdfPath});

  @override
  Widget build(BuildContext context) {
    final pdfUri = Uri.file(pdfPath).toString();
    final viewerUrl = Uri.file(
      '${Directory.current.path}/assets/web/viewer.html?file=$pdfUri',
    ).toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(path.basename(pdfPath)),
      ),
      body: InAppWebView(
        initialFile: "assets/web/viewer.html",
        initialUrlRequest: URLRequest(
          url: WebUri("file:///$viewerUrl"),
        ),
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
          ),
        ),
      ),
    );
  }
}

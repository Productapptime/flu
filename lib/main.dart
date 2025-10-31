import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() => runApp(const PdfManagerApp());

class PdfManagerApp extends StatefulWidget {
  const PdfManagerApp({super.key});
  @override
  State<PdfManagerApp> createState() => _PdfManagerAppState();
}

class _PdfManagerAppState extends State<PdfManagerApp> {
  ThemeMode _themeMode = ThemeMode.light;
  void toggleTheme(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager Plus',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(primarySwatch: Colors.indigo, brightness: Brightness.light),
      darkTheme: ThemeData(primarySwatch: Colors.indigo, brightness: Brightness.dark),
      home: PdfHomePage(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: toggleTheme,
      ),
    );
  }
}

class PdfHomePage extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleTheme;
  const PdfHomePage({super.key, required this.isDarkMode, required this.onToggleTheme});

  @override
  State<PdfHomePage> createState() => _PdfHomePageState();
}

class _PdfHomePageState extends State<PdfHomePage> {
  int _selectedIndex = 0;
  List<FileSystemEntity> pdfFiles = [];
  List<String> favorites = [];
  List<FileSystemEntity> recentFiles = [];
  Directory? appDir;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    initStorage();
  }

  Future<void> initStorage() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory('${dir.path}/pdf_files');
    if (!await base.exists()) await base.create(recursive: true);
    setState(() {
      appDir = base;
    });
    loadFiles();
  }

  Future<void> loadFiles() async {
    if (appDir == null) return;
    final files = appDir!.listSync();
    setState(() {
      pdfFiles = files;
      loading = false;
    });
  }

  Future<void> importFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final target = File('${appDir!.path}/${file.uri.pathSegments.last}');
    await file.copy(target.path);

    await loadFiles();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF başarıyla içe aktarıldı!')),
    );
  }

  Future<void> createFolder(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yeni Klasör Oluştur'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Klasör adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final folder = Directory('${appDir!.path}/${controller.text.trim()}');
                if (!await folder.exists()) await folder.create(recursive: true);
                await loadFiles();
                Navigator.pop(context);
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  void openPdf(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PDFViewerPage(pdfPath: file.path)),
    );
  }

  void toggleFavorite(String path) async {
    final prefs = await SharedPreferences.getInstance();
    if (favorites.contains(path)) {
      favorites.remove(path);
    } else {
      favorites.add(path);
    }
    await prefs.setStringList('favorites', favorites);
    setState(() {});
  }

  Widget buildAllFiles() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (pdfFiles.isEmpty) {
      return const Center(child: Text('Hiç dosya bulunamadı.'));
    }

    final folders = pdfFiles.whereType<Directory>().toList();
    final files = pdfFiles.whereType<File>().toList();

    return ListView(
      children: [
        ...folders.map((dir) => ListTile(
              leading: const Icon(Icons.folder, color: Colors.amber),
              title: Text(dir.path.split('/').last),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FolderView(folder: dir)),
                );
              },
            )),
        const Divider(),
        ...files.map((file) => ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text(file.path.split('/').last),
              trailing: IconButton(
                icon: Icon(
                  favorites.contains(file.path) ? Icons.favorite : Icons.favorite_border,
                  color: favorites.contains(file.path) ? Colors.pink : null,
                ),
                onPressed: () => toggleFavorite(file.path),
              ),
              onTap: () => openPdf(file),
            )),
      ],
    );
  }

  List<Widget> get pages => [
        buildAllFiles(),
        const Center(child: Text('Recent (yakında)')),
        const Center(child: Text('Favorites (yakında)')),
        const Center(child: Text('Tools (yakında)')),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(['All Files', 'Recent', 'Favorites', 'Tools'][_selectedIndex]),
        actions: [
          IconButton(icon: const Icon(Icons.create_new_folder_outlined), onPressed: () => createFolder(context)),
          IconButton(icon: const Icon(Icons.file_upload), onPressed: importFile),
          Switch(
            value: widget.isDarkMode,
            onChanged: widget.onToggleTheme,
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'All'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Recent'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favs'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Tools'),
        ],
      ),
    );
  }
}

class FolderView extends StatelessWidget {
  final Directory folder;
  const FolderView({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    final contents = folder.listSync();
    final pdfs = contents.whereType<File>().toList();

    return Scaffold(
      appBar: AppBar(title: Text(folder.path.split('/').last)),
      body: ListView(
        children: pdfs
            .map(
              (file) => ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(file.path.split('/').last),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PDFViewerPage(pdfPath: file.path)));
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class PDFViewerPage extends StatelessWidget {
  final String pdfPath;
  const PDFViewerPage({super.key, required this.pdfPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pdfPath.split('/').last)),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(
            'file:///android_asset/flutter_assets/assets/web/viewer.html?file=$pdfPath',
          ),
        ),
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            javaScriptEnabled: true,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
          ),
        ),
      ),
    );
  }
}

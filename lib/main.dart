import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle; // ✅ eklendi

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(const PdfManagerPlusApp());
}

/// 📂 Android 11+ için depolama izinleri
Future<void> _requestPermissions() async {
  await [
    Permission.manageExternalStorage,
    Permission.storage,
  ].request();
}

class PdfManagerPlusApp extends StatelessWidget {
  const PdfManagerPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager Plus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
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
          setState(() => allFiles.add(filePath));
          await _saveLists();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF eklendi: ${p.basename(filePath)}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF seçilemedi: $e')),
      );
    }
  }

  void _openPdf(String filePath) async {
    if (!recents.contains(filePath)) {
      setState(() => recents.insert(0, filePath));
      await _saveLists();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(pdfPath: filePath),
      ),
    );
  }

  void _toggleFavorite(String filePath) async {
    setState(() {
      favorites.contains(filePath)
          ? favorites.remove(filePath)
          : favorites.add(filePath);
    });
    await _saveLists();
  }

  Widget _buildPdfList(List<String> list) {
    if (list.isEmpty) {
      return const Center(child: Text("Henüz PDF bulunmuyor."));
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final path = list[index];
        final name = p.basename(path);
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

  Widget get _body {
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
            onPressed: _importPdf,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: const [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PDF Manager Plus',
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text("About"),
              subtitle: Text("Native InAppWebView PDF.js Viewer"),
            ),
          ],
        ),
      ),
      body: _body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder), label: "All"),
          NavigationDestination(icon: Icon(Icons.access_time), label: "Recent"),
          NavigationDestination(icon: Icon(Icons.favorite), label: "Favorites"),
        ],
      ),
    );
  }
}

/// 🧭 PDF Viewer Sayfası
class PdfViewerPage extends StatefulWidget {
  final String pdfPath;
  const PdfViewerPage({super.key, required this.pdfPath});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  late InAppWebViewController _controller;

  /// assets/web/viewer.html dosyasını cihazın temp klasörüne kopyalayıp oradan açıyoruz.
  Future<String> _prepareLocalViewer() async {
    final tempDir = await getTemporaryDirectory();
    final viewerFile = File('${tempDir.path}/viewer.html');

    // Eğer daha önce kopyalanmadıysa asset'ten yükle
    if (!await viewerFile.exists()) {
      final data = await rootBundle.loadString('assets/web/viewer.html');
      await viewerFile.writeAsString(data);
    }

    return viewerFile.path;
  }

  @override
  Widget build(BuildContext context) {
    final pdfUri = Uri.file(widget.pdfPath).toString();

    return FutureBuilder<String>(
      future: _prepareLocalViewer(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final viewerPath = snapshot.data!;
        final viewerUri = WebUri(
            'file://$viewerPath?file=$pdfUri'); // ✅ WebUri tipine dönüştürüldü

        return Scaffold(
          appBar: AppBar(title: Text(p.basename(widget.pdfPath))),
          body: InAppWebView(
            initialUrlRequest: URLRequest(url: viewerUri), // ✅ düzeltildi
            initialSettings: InAppWebViewSettings(
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              javaScriptEnabled: true,
            ),
            onWebViewCreated: (controller) => _controller = controller,
          ),
        );
      },
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.manageExternalStorage.request();
  runApp(const PDFReaderApp());
}

class PDFReaderApp extends StatelessWidget {
  const PDFReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AllFilesPage(),
    );
  }
}

class AllFilesPage extends StatefulWidget {
  const AllFilesPage({super.key});

  @override
  State<AllFilesPage> createState() => _AllFilesPageState();
}

class _AllFilesPageState extends State<AllFilesPage> {
  List<File> pdfFiles = [];
  List<Directory> folders = [];
  List<File> recentFiles = [];
  List<File> favoriteFiles = [];

  bool permissionGranted = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    if (await Permission.manageExternalStorage.request().isGranted ||
        await Permission.storage.request().isGranted) {
      setState(() => permissionGranted = true);
      await loadPDFFiles();
    } else {
      setState(() => permissionGranted = false);
    }
  }

  Future<void> loadPDFFiles() async {
    setState(() => isLoading = true);
    pdfFiles.clear();
    folders.clear();

    final Directory root = Directory('/storage/emulated/0/');
    try {
      await for (var entity in root.list(recursive: false, followLinks: false)) {
        if (entity is Directory) {
          folders.add(entity);
        } else if (entity is File &&
            entity.path.toLowerCase().endsWith('.pdf')) {
          pdfFiles.add(entity);
        }
      }
    } catch (e) {
      debugPrint('PDF tarama hatası: $e');
    }

    setState(() => isLoading = false);
  }

  Future<void> importPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final importedFile = File(result.files.single.path!);
      final newPath =
          '/storage/emulated/0/${p.basename(importedFile.path)}'; // kök dizine kopyala
      await importedFile.copy(newPath);

      setState(() {
        pdfFiles.add(File(newPath));
        recentFiles.insert(0, File(newPath));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF başarıyla eklendi: ${p.basename(newPath)}")),
      );
    }
  }

  void createFolder() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni Klasör Oluştur"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "Klasör adı"),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final newDir =
                  Directory('/storage/emulated/0/${nameController.text}');
              if (!await newDir.exists()) {
                await newDir.create();
                setState(() => folders.add(newDir));
              }
              Navigator.pop(context);
            },
            child: const Text("Oluştur"),
          ),
        ],
      ),
    );
  }

  void openPDF(File file) {
    recentFiles.insert(0, file);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewerPage(pdfPath: file.path),
      ),
    );
  }

  void movePDF(File file) async {
    Directory? selectedFolder = await showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Taşınacak klasörü seç"),
        children: folders
            .map(
              (folder) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, folder),
                child: Text(folder.path.split('/').last),
              ),
            )
            .toList(),
      ),
    );

    if (selectedFolder != null) {
      final newPath = p.join(selectedFolder.path, p.basename(file.path));
      await file.rename(newPath);
      setState(() {
        pdfFiles.remove(file);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Taşındı: ${p.basename(newPath)}")),
      );
    }
  }

  void toggleFavorite(File file) {
    setState(() {
      if (favoriteFiles.contains(file)) {
        favoriteFiles.remove(file);
      } else {
        favoriteFiles.add(file);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.menu),
        title: const Text("All Files"),
        actions: [
          IconButton(icon: const Icon(Icons.create_new_folder), onPressed: createFolder),
          IconButton(icon: const Icon(Icons.file_upload_outlined), onPressed: importPDF),
        ],
      ),
      body: !permissionGranted
          ? const Center(child: Text("Depolama izni verilmedi."))
          : isLoading
              ? const Center(child: CircularProgressIndicator())
              : folders.isEmpty && pdfFiles.isEmpty
                  ? const Center(child: Text("Henüz PDF veya klasör yok."))
                  : ListView(
                      children: [
                        ...folders.map((folder) => ListTile(
                              leading: const Icon(Icons.folder, color: Colors.amber),
                              title: Text(folder.path.split('/').last),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      FolderPage(folder: folder),
                                ),
                              ),
                            )),
                        const Divider(),
                        ...pdfFiles.map((file) => ListTile(
                              leading:
                                  const Icon(Icons.picture_as_pdf, color: Colors.red),
                              title: Text(p.basename(file.path)),
                              subtitle: Text(file.path),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'move') movePDF(file);
                                  if (value == 'fav') toggleFavorite(file);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                      value: 'move', child: Text("Taşı")),
                                  const PopupMenuItem(
                                      value: 'fav', child: Text("Favorilere ekle")),
                                ],
                              ),
                              onTap: () => openPDF(file),
                            )),
                      ],
                    ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder), label: 'All Files'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Recent'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Favorites'),
        ],
        selectedIndex: 0,
      ),
    );
  }
}

class FolderPage extends StatelessWidget {
  final Directory folder;
  const FolderPage({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    final files = folder
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.pdf'))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(folder.path.split('/').last)),
      body: files.isEmpty
          ? const Center(child: Text("Bu klasörde PDF yok."))
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return ListTile(
                  leading:
                      const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  title: Text(file.path.split('/').last),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PDFViewerPage(pdfPath: file.path),
                      ),
                    );
                  },
                );
              },
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
          url: Uri.parse(
            'file:///android_asset/flutter_assets/web/viewer.html?file=$pdfPath',
          ),
        ),
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
            javaScriptEnabled: true,
          ),
        ),
      ),
    );
  }
}

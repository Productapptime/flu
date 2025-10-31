import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:animations/animations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PdfManagerApp());
}

class PdfManagerApp extends StatefulWidget {
  const PdfManagerApp({super.key});

  @override
  State<PdfManagerApp> createState() => _PdfManagerAppState();
}

class _PdfManagerAppState extends State<PdfManagerApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void toggleTheme(bool dark) {
    setState(() => _themeMode = dark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: PdfHomePage(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: toggleTheme,
      ),
    );
  }
}

class PdfHomePage extends StatefulWidget {
  final bool isDark;
  final Function(bool) onToggleTheme;

  const PdfHomePage({super.key, required this.isDark, required this.onToggleTheme});

  @override
  State<PdfHomePage> createState() => _PdfHomePageState();
}

class _PdfHomePageState extends State<PdfHomePage> {
  List<String> _pdfFiles = [];
  List<String> _favorites = [];
  List<String> _recent = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pdfFiles = prefs.getStringList('pdfFiles') ?? [];
      _favorites = prefs.getStringList('favorites') ?? [];
      _recent = prefs.getStringList('recent') ?? [];
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pdfFiles', _pdfFiles);
    await prefs.setStringList('favorites', _favorites);
    await prefs.setStringList('recent', _recent);
  }

  Future<void> _importPdf() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      if (!_pdfFiles.contains(path)) {
        setState(() {
          _pdfFiles.add(path);
        });
        await _saveData();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF eklendi: ${result.files.single.name}')));
    }
  }

  void _openPdf(String path) async {
    if (!_recent.contains(path)) {
      _recent.insert(0, path);
      await _saveData();
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PdfViewerScreen(pdfPath: path)),
    );
  }

  void _toggleFavorite(String path) async {
    setState(() {
      if (_favorites.contains(path)) {
        _favorites.remove(path);
      } else {
        _favorites.add(path);
      }
    });
    await _saveData();
  }

  void _onBottomTap(int i) => setState(() => _selectedIndex = i);

  List<String> get _activeList {
    if (_selectedIndex == 1) return _recent;
    if (_selectedIndex == 2) return _favorites;
    return _pdfFiles;
  }

  Widget _buildList() {
    final files = _activeList;
    if (files.isEmpty) {
      return const Center(child: Text('Henüz PDF bulunmuyor.'));
    }

    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, i) {
        final path = files[i];
        final name = path.split('/').last;
        final fav = _favorites.contains(path);
        return ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
          title: Text(name),
          trailing: IconButton(
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? Colors.red : null),
            onPressed: () => _toggleFavorite(path),
          ),
          onTap: () => _openPdf(path),
        );
      },
    );
  }

  Widget _buildDrawer() => Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('PDF Manager Menu', style: TextStyle(color: Colors.white, fontSize: 20)),
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
            SwitchListTile(
              title: const Text('Dark Mode'),
              secondary: const Icon(Icons.brightness_6),
              value: widget.isDark,
              onChanged: widget.onToggleTheme,
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'PDF Manager',
                  applicationVersion: '1.0',
                  children: [const Text('Flutter PDF Manager with WebView Viewer')],
                );
              },
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    const tabs = ['All Files', 'Recent', 'Favorites'];
    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[_selectedIndex]),
        actions: [
          IconButton(onPressed: _importPdf, icon: const Icon(Icons.add)),
        ],
      ),
      drawer: _buildDrawer(),
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, anim, secAnim) => SharedAxisTransition(
          animation: anim,
          secondaryAnimation: secAnim,
          transitionType: SharedAxisTransitionType.horizontal,
          child: child,
        ),
        child: _buildList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomTap,
        selectedItemColor: Colors.indigo,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'All'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Recent'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favs'),
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
    final fileUrl = Uri.file(pdfPath).toString();
    final viewerUrl = 'assets/web/viewer.html?file=$fileUrl';

    return Scaffold(
      appBar: AppBar(title: Text(pdfPath.split('/').last)),
      body: InAppWebView(
        initialFile: viewerUrl,
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true, allowFileAccessFromFileURLs: true),
      ),
    );
  }
}

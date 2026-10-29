import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ComicReaderApp());
}

class ComicReaderApp extends StatelessWidget {
  const ComicReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leitor de BD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFE50914),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181818),
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const LibraryScreen(),
    const CollectionsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isTabletScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Row(
        children: [
          if (isTabletScreen)
            NavigationRail(
              backgroundColor: const Color(0xFF181818),
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              selectedIconTheme: const IconThemeData(color: Colors.redAccent),
              unselectedIconTheme: const IconThemeData(color: Colors.grey),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: Text('Biblioteca'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.collections_bookmark_outlined),
                  selectedIcon: Icon(Icons.collections_bookmark),
                  label: Text('Coleções'),
                ),
              ],
            ),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: isTabletScreen
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              selectedItemColor: Colors.redAccent,
              unselectedItemColor: Colors.grey,
              backgroundColor: const Color(0xFF181818),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Biblioteca'),
                BottomNavigationBarItem(icon: Icon(Icons.collections_bookmark), label: 'Coleções'),
              ],
            ),
    );
  }
}

// --- 1. ESTANTE DE QUADRINHOS (BIBLIOTECA) ---
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<FileSystemEntity> _comics = [];

  @override
  void initState() {
    super.initState();
    _loadComics();
  }

  Future<void> _loadComics() async {
    final appDir = await getApplicationDocumentsDirectory();
    final comicsDir = Directory('${appDir.path}/comics');
    if (!await comicsDir.exists()) await comicsDir.create(recursive: true);

    setState(() {
      _comics = comicsDir.listSync().where((e) => e.path.endsWith('.cbz') || e.path.endsWith('.zip')).toList();
    });
  }

  Future<void> _importComic() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cbz', 'zip'],
    );

    if (result != null && result.files.single.path != null) {
      final selectedFile = File(result.files.single.path!);
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = selectedFile.path.split('/').last;
      await selectedFile.copy('${appDir.path}/comics/$fileName');

      _loadComics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Importado com sucesso: $fileName')),
        );
      }
    }
  }

  Future<void> _deleteComic(FileSystemEntity file) async {
    await file.delete();
    _loadComics();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 180).floor().clamp(2, 8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: 'Importar Ficheiro CBZ/ZIP',
            onPressed: _importComic,
          ),
        ],
      ),
      body: _comics.isEmpty
          ? const Center(child: Text('Nenhum quadrinho importado.', style: TextStyle(color: Colors.grey)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.55,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
              ),
              itemCount: _comics.length,
              itemBuilder: (context, index) {
                final comic = _comics[index];
                final title = comic.path.split('/').last.replaceAll('.cbz', '').replaceAll('.zip', '');

                return Column(
                  crossAxisAlignment: CrossAlignment.start,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ReaderScreen(comicFile: File(comic.path))),
                          );
                        },
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF222222),
                              title: const Text('Eliminar Quadrinho'),
                              content: Text('Desejas eliminar "$title" do aplicativo?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteComic(comic);
                                  },
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                            color: const Color(0xFF222222),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: const Center(
                              child: Icon(Icons.menu_book, size: 48, color: Colors.white24),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Não lido',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// --- 2. COLEÇÕES COM CAPA E CONTADOR ---
class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  List> _collections = [];

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('collections');
    if (data != null) {
      setState(() {
        _collections = List>.from(json.decode(data));
      });
    }
  }

  Future<void> _saveCollections() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('collections', json.encode(_collections));
  }

  void _createOrEditCollection({int? index}) {
    final nameController = TextEditingController(text: index != null ? _collections[index]['name'] : '');
    String? imagePath = index != null ? _collections[index]['cover'] : null;

    showDialog(
      context: context,
      builder: (context) => StatefulWidget(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF222222),
          title: Text(index != null ? 'Editar Coleção' : 'Nova Coleção'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Coleção',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setDialogState(() => imagePath = picked.path);
                  }
                },
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(imagePath!), fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, color: Colors.grey),
                            SizedBox(height: 4),
                            Text('Escolher Capa da Galeria', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                ),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    if (index != null) {
                      _collections[index]['name'] = nameController.text;
                      _collections[index]['cover'] = imagePath;
                    } else {
                      _collections.add({
                        'name': nameController.text,
                        'cover': imagePath,
                        'count': 0,
                      });
                    }
                  });
                  _saveCollections();
                  Navigator.pop(context);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 180).floor().clamp(2, 8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coleções', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createOrEditCollection(),
          )
        ],
      ),
      body: _collections.isEmpty
          ? const Center(child: Text('Nenhuma coleção criada.', style: TextStyle(color: Colors.grey)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.55,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
              ),
              itemCount: _collections.length,
              itemBuilder: (context, index) {
                final collection = _collections[index];
                final coverPath = collection['cover'];
                final int count = collection['count'] ?? 0;

                return Column(
                  crossAxisAlignment: CrossAlignment.start,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onLongPress: () => _createOrEditCollection(index: index),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                            color: const Color(0xFF222222),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: coverPath != null
                                ? Image.file(
                                    File(coverPath),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  )
                                : const Center(child: Icon(Icons.folder, size: 48, color: Colors.white24)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      collection['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count ${count == 1 ? 'quadrinho' : 'quadrinhos'}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// --- 3. DASHBOARD DE TEMPO E OFENSIVA ---
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _weeklyMinutes = 0;
  int _monthlyMinutes = 0;
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    int weeklySecs = 0;
    for (int i = 0; i < 7; i++) {
      final dateStr = _formatDate(now.subtract(Duration(days: i)));
      weeklySecs += prefs.getInt('read_time_$dateStr') ?? 0;
    }

    int monthlySecs = 0;
    for (int i = 0; i < 30; i++) {
      final dateStr = _formatDate(now.subtract(Duration(days: i)));
      monthlySecs += prefs.getInt('read_time_$dateStr') ?? 0;
    }

    int streak = 0;
    DateTime checkDate = now;
    while (true) {
      final dateStr = _formatDate(checkDate);
      final readSecs = prefs.getInt('read_time_$dateStr') ?? 0;
      if (readSecs > 0) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (_formatDate(now) == dateStr) {
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    setState(() {
      _weeklyMinutes = (weeklySecs / 60).round();
      _monthlyMinutes = (monthlySecs / 60).round();
      _streakDays = streak;
    });
  }

  String _formatDate(DateTime dt) => "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas de Leitura', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 36),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAlignment.start,
                    children: [
                      const Text('Ofensiva Atual', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('$_streakDays dias seguidos', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAlignment.start,
                      children: [
                        const Text('Esta Semana', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 6),
                        Text(
                          '${(_weeklyMinutes / 60).toStringAsFixed(1)} h',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAlignment.start,
                      children: [
                        const Text('Neste Mês', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 6),
                        Text(
                          '${(_monthlyMinutes / 60).toStringAsFixed(1)} h',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- 4. LEITOR DE FICHEIROS CBZ/ZIP ---
class ReaderScreen extends StatefulWidget {
  final File comicFile;
  const ReaderScreen({super.key, required this.comicFile});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  List<ArchiveFile> _pages = [];
  bool _loading = true;
  int _currentPage = 0;
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _loadPages();
  }

  Future<void> _loadPages() async {
    final bytes = await widget.comicFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final imagePages = archive.where((file) {
      final ext = file.name.toLowerCase();
      return ext.endsWith('.jpg') || ext.endsWith('.png') || ext.endsWith('.jpeg') || ext.endsWith('.webp');
    }).toList();

    imagePages.sort((a, b) => a.name.compareTo(b.name));

    setState(() {
      _pages = imagePages;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _saveReadingTime();
    super.dispose();
  }

  Future<void> _saveReadingTime() async {
    final endTime = DateTime.now();
    final elapsedSeconds = endTime.difference(_startTime).inSeconds;
    if (elapsedSeconds < 5) return;

    final prefs = await SharedPreferences.getInstance();
    final dateStr = "${endTime.year}-${endTime.month.toString().padLeft(2, '0')}-${endTime.day.toString().padLeft(2, '0')}";
    final currentRead = prefs.getInt('read_time_$dateStr') ?? 0;
    await prefs.setInt('read_time_$dateStr', currentRead + elapsedSeconds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_loading ? 'Carregando...' : 'Página ${_currentPage + 1} de ${_pages.length}'),
        backgroundColor: Colors.black.withOpacity(0.7),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : PageView.builder(
              itemCount: _pages.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) {
                final pageData = _pages[index].content as List<int>;
                return InteractiveViewer(
                  child: Image.memory(Uint8List.fromList(pageData), fit: BoxFit.contain),
                );
              },
            ),
    );
  }
}

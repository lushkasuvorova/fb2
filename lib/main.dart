import 'dart:io';
import 'package:fb2/js/scroll_save.dart';
import 'package:flutter/material.dart';
import 'package:open_with_app/open_with_app.dart';
import 'parsers/fb2_parser.dart';
import 'inject_lines/inject_lines.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _plugin = OpenWithApp();
  late final WebViewController _controller;
  final _parser = Fb2Parser();
  final _injectLines = InjectLines();
  
  static const String _progressKey = 'reading_progress';
  static const String _lastFileKey = 'last_file_path';
  
  String? _currentFilePath;
  bool _isFirstLoad = true;
  bool _hasBook = false;

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'flutterSaveProgress',
        onMessageReceived: (JavaScriptMessage message) {
          final scrollY = double.tryParse(message.message) ?? 0;

          if (_currentFilePath != null) {
            _saveProgress(scrollY, _currentFilePath!);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _onPageLoaded();
          },
        ),
      );
    
    _plugin.getInitialFile().then((path) async {

      if (path != null) {
        await _loadFile(path);
      } 

      else {
        final lastFile = await _getLastFile();

        if (lastFile != null && File(lastFile).existsSync()) {
          await _loadFile(lastFile);
        }
      }

    });

    _plugin.getFileStream().listen(_loadFile);
  }

  Future<void> _onPageLoaded() async {
    await _setupScrollSave();

  // ========== ДОБАВЛЕНИЕ ЛИНИЙ ==========
    final width = await _controller.runJavaScriptReturningResult('window.innerWidth');
    final height = await _controller.runJavaScriptReturningResult('window.innerHeight');
    final contentHeight = await _controller.runJavaScriptReturningResult('document.documentElement.scrollHeight');
    final lines = await _injectLines.injectLines(width, height, contentHeight);
    await _controller.runJavaScript(lines);

    if (_isFirstLoad && _currentFilePath != null) {
      _isFirstLoad = false;
      await _restorePosition();
    }
  }

  // ========== СОХРАНЕНИЕ ПРОГРЕССА ==========
  
  Future<void> _saveProgress(double scrollPosition, String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('${_progressKey}_$filePath', scrollPosition);
      await prefs.setString(_lastFileKey, filePath);
    } catch (e) {
      debugPrint('Ошибка сохранения прогресса: $e');
    }
  }

  Future<double?> _getSavedProgress(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble('${_progressKey}_$filePath');
    } catch (e) {
      debugPrint('Ошибка получения прогресса: $e');
      return null;
    }
  }

  Future<String?> _getLastFile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastFileKey);
    } catch (e) {
      debugPrint('Ошибка получения последнего файла: $e');
      return null;
    }
  }

  // ========== ВОССТАНОВЛЕНИЕ ПОЗИЦИИ ==========
  
  Future<void> _restorePosition() async {
    if (_currentFilePath == null) return;
    
    try {
      final savedPosition = await _getSavedProgress(_currentFilePath!);
      if (savedPosition != null && savedPosition > 0) {
        
        await _controller.runJavaScript('''
          window.scrollTo(0, $savedPosition);
        ''');
      }
    } catch (e) {
      debugPrint('Ошибка восстановления позиции: $e');
    }
  }

  // ========== СОХРАНЕНИЕ ПРИ СКРОЛЛЕ ==========
  
  Future<void> _setupScrollSave() async {

    try {
      await _controller.runJavaScript(scrollSaveScript);
    } catch (e) {
      debugPrint("Ошибка JS: $e");
    }
  }

  // ========== ЗАГРУЗКА ФАЙЛА ==========
  
  Future<void> _loadFile(String? path) async {
    if (path == null) return;
    
    setState(() {
      _currentFilePath = path;
      _isFirstLoad = true;
      _hasBook = true;
    });
    
    try {
      debugPrint('Загружаем файл: $path');
      
      final xmlText = await File(path).readAsString();
      final htmlContent = await _parser.parse(xmlText);
      await _controller.loadHtmlString(htmlContent);
      
    } catch (e) {
      _controller.loadHtmlString('<html><body><p>Ошибка: $e</p></body></html>');
    }
  }
// ========== ВЫБОР ФАЙЛА ==========   

Future<void> _pickFb2() async {
    
 final result = await FilePicker.platform.pickFiles(       
  type: FileType.custom,       
  allowedExtensions: ['fb2'],     
 );
    
 if (result == null) {       
  return;     
 }
    
 final path = result.files.single.path;     
 if (path != null) {       
  await _loadFile(path);     
 }
  
}


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: _hasBook
            ? WebViewWidget(
                controller: _controller,
              )
            : Center(
                child: ElevatedButton(
                  onPressed: _pickFb2,
                  child: const Text('Выбрать FB2'),
                ),
              ),
        ),
      ),
    );
  }
}
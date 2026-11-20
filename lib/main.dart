import 'dart:io';
import 'dart:async';
import 'package:fb2/js/scroll_save.dart';
import 'package:flutter/material.dart';
import 'package:open_with_app/open_with_app.dart';
import 'parsers/fb2_parser.dart';
import 'inject_lines/inject_lines.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'services/reading_storage.dart';
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
  StreamSubscription<String?>? _fileSubscription;
  final _parser = Fb2Parser();
  final _injectLines = InjectLines();
  final _storage = ReadingStorage();
  
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
            _storage.saveProgress(scrollY, _currentFilePath!);
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
        final lastFile = await _storage.getLastFile();

        if (lastFile != null && File(lastFile).existsSync()) {
          await _loadFile(lastFile);
        }
      }
    });

    _fileSubscription = _plugin.getFileStream().listen(_loadFile);
  }

  @override
  void dispose() {
    _fileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onPageLoaded() async {
    await _setupScrollSave();

  // ========== ДОБАВЛЕНИЕ ЛИНИЙ ==========
    final [width, height, contentHeight] = await Future.wait([
      _controller.runJavaScriptReturningResult('window.innerWidth'),
      _controller.runJavaScriptReturningResult('window.innerHeight'),
      _controller.runJavaScriptReturningResult('document.documentElement.scrollHeight'),
    ]);
    final lines = await _injectLines.injectLines(width, height, contentHeight);
    await _controller.runJavaScript(lines);

    if (_isFirstLoad && _currentFilePath != null) {
      _isFirstLoad = false;
      await _restorePosition();
    }
  }

  // ========== ВОССТАНОВЛЕНИЕ ПОЗИЦИИ ==========
  
  Future<void> _restorePosition() async {
    if (_currentFilePath == null) return;
    try {
      final savedPosition = await _storage.getSavedProgress(_currentFilePath!);
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
        body: PopScope(
          canPop: !_hasBook,
          onPopInvokedWithResult: (didPop, result) {
            if (_hasBook) {
              setState(() {
                _hasBook = false;
              });
            }
          },
          child: SafeArea(
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
      ),
    );
  }
}
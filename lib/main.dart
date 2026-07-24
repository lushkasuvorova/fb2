import 'package:flutter/material.dart';
import 'package:open_with_app/open_with_app.dart';
import 'package:fb2_parse/fb2_parse.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  
  static const String _progressKey = 'reading_progress';
  static const String _lastFileKey = 'last_file_path';
  
  String? _currentFilePath;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _onPageLoaded();
          },
        ),
      )
      ..loadHtmlString('<html><body><p>Выберите FB2 файл</p></body></html>');
    
    _plugin.getInitialFile().then(_loadFile);
    _plugin.getFileStream().listen(_loadFile);
  }

  Future<void> _onPageLoaded() async {
    await _injectLines();
    
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
      debugPrint('📖 Прогресс сохранен: $scrollPosition px');
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
        debugPrint('📍 Восстанавливаем позицию: $savedPosition px');
        
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
    await _controller.runJavaScript('''
      let saveTimeout;
      let lastSavedPosition = -1;
      
      window.addEventListener('scroll', function() {
        clearTimeout(saveTimeout);
        
        saveTimeout = setTimeout(function() {
          const scrollY = window.scrollY;
          const scrollHeight = document.documentElement.scrollHeight;
          
          // Сохраняем если:
          // 1. Прочитано больше 5%
          // 2. Позиция изменилась существенно (больше 50px)
          if (scrollY / scrollHeight > 0.05 && Math.abs(scrollY - lastSavedPosition) > 50) {
            window.flutterSaveProgress(scrollY);
            lastSavedPosition = scrollY;
          }
        }, 500);
      });
    ''');
    
    _controller.addJavaScriptChannel(
      'flutterSaveProgress',
      onMessageReceived: (JavaScriptMessage message) {
        final scrollY = double.tryParse(message.message) ?? 0;
        if (_currentFilePath != null) {
          _saveProgress(scrollY, _currentFilePath!);
        }
      },
    );
  }

  // ========== ЗАГРУЗКА ФАЙЛА ==========
  
  Future<void> _loadFile(String? path) async {
    if (path == null) return;
    
    setState(() {
      _currentFilePath = path;
      _isFirstLoad = true;
    });
    
    try {
      debugPrint('Загружаем файл: $path');
      
      FB2Book book = FB2Book(path);
      await book.parse();

      String allContent = '';
      for (var section in book.body.sections!) {
        allContent += section.content ?? '';
      }
      
      String htmlContent = '''
      <style>
        body { font-size: 18px; padding: 10px; }
        p { margin-bottom: 1em; }
        h1, h2, h3, h4 { margin-top: 1.5em; margin-bottom: 0.5em; }
      </style>
      <body>
        $allContent
      </body>
      ''';
      
      await _controller.loadHtmlString(htmlContent);
      await _setupScrollSave();
      
    } catch (e) {
      _controller.loadHtmlString('<html><body><p>Ошибка: $e</p></body></html>');
    }
  }

  // ========== ДОБАВЛЕНИЕ ЛИНИЙ ==========
  
  Future<void> _injectLines() async {
    try {
      final width = await _controller.runJavaScriptReturningResult('window.innerWidth');
      final height = await _controller.runJavaScriptReturningResult('window.innerHeight');
      final contentHeight = await _controller.runJavaScriptReturningResult('document.documentElement.scrollHeight');

      final double windowWidth = double.parse(width.toString());
      final double windowHeight = double.parse(height.toString());
      final double totalHeight = double.parse(contentHeight.toString());
      
      if (windowWidth == 0 || windowHeight == 0) return;

      debugPrint('Ширина: $windowWidth, Высота: $windowHeight');
      debugPrint('Общая высота контента: $totalHeight');

      double currentHeight = 0;
      final List<Map<String, dynamic>> linesData = [];
      int lineNumber = 0;

      while (currentHeight < totalHeight) {
        currentHeight += windowHeight;
        if (currentHeight > totalHeight) currentHeight = totalHeight;
        linesData.add({
          'position': currentHeight,
          'number': ++lineNumber,
        });
      }

      final StringBuffer jsCode = StringBuffer();
      jsCode.writeln('''
        (function() {
          const oldContainer = document.getElementById('lines-container');
          if (oldContainer) oldContainer.remove();
          
          const container = document.createElement('div');
          container.id = 'lines-container';
          container.style.cssText = 'position: absolute; top: 0; left: 0; width: 100%; pointer-events: none; z-index: 9999;';
      ''');
      
      for (var data in linesData) {
        jsCode.writeln('''
          (() => {
            const line = document.createElement('div');
            line.style.cssText = 'position: absolute; top: ${data['position']}px; left: 0; width: 100%; height: 2px; background-color: rgba(255, 0, 0, 0.5); pointer-events: none; z-index: 9999;';
            
            const label = document.createElement('span');
            label.style.cssText = 'position: absolute; right: 10px; top: -10px; background: rgba(255, 0, 0, 0.7); color: white; padding: 2px 6px; font-size: 12px; font-family: Arial; border-radius: 3px;';
            label.textContent = '${data['number']}';
            
            line.appendChild(label);
            container.appendChild(line);
          })();
        ''');
      }
      
      jsCode.writeln('''
          document.body.appendChild(container);
        })();
      ''');
      
      await _controller.runJavaScript(jsCode.toString());
      debugPrint('Добавлено линий: ${linesData.length}');
      
    } catch (e) {
      debugPrint('Ошибка инъекции линий: $e');
    }
  }

  // ========== СОХРАНЕНИЕ ПРИ ВЫХОДЕ ==========
  
  @override
  void dispose() {
    _savePositionOnExit();
    super.dispose();
  }

  Future<void> _savePositionOnExit() async {
    if (_currentFilePath == null) return;
    
    try {
      final scrollY = await _controller.runJavaScriptReturningResult('''
        (function() {
          return window.scrollY || window.pageYOffset || document.documentElement.scrollTop || 0;
        })();
      ''');
      
      
      final position = double.parse(scrollY.toString());
      await _saveProgress(position, _currentFilePath!);
      debugPrint('💾 Прогресс сохранен при выходе: $position px');
      
    } catch (e) {
      debugPrint('Ошибка сохранения при выходе: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}
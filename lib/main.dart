import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_with_app/open_with_app.dart';
import 'package:xml/xml.dart';
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
      )
      ..loadHtmlString('<html><body><p>Выберите FB2 файл</p></body></html>');
    
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
    await _controller.runJavaScript('''
      let saveTimeout;
      let lastSavedPosition = -1;

      function sendScrollPosition() {
        clearTimeout(saveTimeout);

        saveTimeout = setTimeout(function() {

          let scrollY = 
              window.scrollY ||
              document.documentElement.scrollTop ||
              document.body.scrollTop ||
              0;

          if (Math.abs(scrollY - lastSavedPosition) > 100) {

            flutterSaveProgress.postMessage(
              scrollY.toString()
            );

            lastSavedPosition = scrollY;
          }

        }, 1000);
      }


      window.addEventListener(
        'scroll',
        sendScrollPosition,
        true
      );

      document.addEventListener(
        'scroll',
        sendScrollPosition,
        true
      );

      document.body.addEventListener(
        'scroll',
        sendScrollPosition,
        true
      );

    ''');
    
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
    });
    
    try {
      debugPrint('Загружаем файл: $path');
      
      final xmlText = await File(path).readAsString();
      final document = XmlDocument.parse(xmlText);
      final body = document.findAllElements('body').first;

      String parseNode(XmlNode node) {
        if (node is XmlText) {
          return node.value;
        }

        if (node is! XmlElement) {
          return '';
        }

        switch (node.name.local) {
          case 'section':
            return node.children.map(parseNode).join();

          case 'title':
            return '<h2>${node.children.map(parseNode).join()}</h2>';

          case 'subtitle':
            return '<h3>${node.children.map(parseNode).join()}</h3>';

          case 'p':
            return '<p>${node.children.map(parseNode).join()}</p>';

          case 'text-author':
            return '<p>${node.children.map(parseNode).join()}</p>';

          case 'strong':
            return '<b>${node.children.map(parseNode).join()}</b>';

          case 'emphasis':
            return '<i>${node.children.map(parseNode).join()}</i>';

          case 'strikethrough':
            return '<del>${node.children.map(parseNode).join()}</del>';

          case 'sup':
            return '<sup>${node.children.map(parseNode).join()}</sup>';

          case 'sub':
            return '<sub>${node.children.map(parseNode).join()}</sub>';

          case 'epigraph':
            return '''
            <blockquote style="font-style:italic;margin-left:25px;">
              ${node.children.map(parseNode).join()}
            </blockquote>
            ''';

          case 'poem':
            return '''
            <div class="poem">
              ${node.children.map(parseNode).join()}
            </div>
            ''';

          case 'stanza':
            return '''
            <div class="stanza">
              ${node.children.map(parseNode).join()}
            </div>
            ''';

          case 'v':
            return '${node.innerText}<br>';

          default:
            return node.children.map(parseNode).join();
        }
      }

      final html = parseNode(body);
            
      String htmlContent = '''
      <html>
      <head>
      <meta charset="utf-8">
      <style>
        body { font-size: 18px; padding: 10px; }
        p { margin-bottom: 1em; }
        h1, h2, h3, h4 { margin-top: 1.5em; margin-bottom: 0.5em; }
        blockquote { color: gray; }
        .poem { margin-left: 20px; }
        .stanza { margin-bottom: 1em; }
      </style>
      </head>
      <body>
        ${html.toString()}
      </body>
      </html>
      ''';
      
      await _controller.loadHtmlString(htmlContent);
      
      
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
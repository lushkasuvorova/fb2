import 'package:flutter/material.dart';
import 'package:open_with_app/open_with_app.dart';
import 'package:fb2_parse/fb2_parse.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  @override
  void initState() {
    super.initState();
    
     _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)

    ..setNavigationDelegate(NavigationDelegate(onPageFinished: (String url) {_injectLines();}))

    ..loadHtmlString('<html><body><p>Выберите FB2 файл</p></body></html>');
    
    _plugin.getInitialFile().then(_loadFile); // Холодный старт
    _plugin.getFileStream().listen(_loadFile); // Теплый старт
  }

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
        linesData.add({
        'position': currentHeight,
        'number': ++lineNumber,
      });

      }

      // Создаем JavaScript код динамически
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
      debugPrint('Ошибка: $e');
    }
  }

  Future<void> _loadFile(String? path) async {
    if (path == null) return;
    try {
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
      _controller.loadHtmlString(htmlContent);
    } catch (e) {
      _controller.loadHtmlString('<html><body><p>Ошибка: $e</p></body></html>');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea( // ← оборачиваем в SafeArea
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}

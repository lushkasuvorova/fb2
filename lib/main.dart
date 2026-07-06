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
    ..loadHtmlString('<html><body><p>Выберите FB2 файл</p></body></html>');
    
    _plugin.getInitialFile().then(_loadFile); // Холодный старт
    _plugin.getFileStream().listen(_loadFile); // Теплый старт
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

import 'package:flutter/material.dart';
import 'package:open_with_app/open_with_app.dart';
import 'dart:io';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _plugin = OpenWithApp();
  String _content = 'Выберите FB2 файл';
  
  @override
  void initState() {
    super.initState();
    _plugin.getInitialFile().then(_loadFile); // Холодный старт
    _plugin.getFileStream().listen(_loadFile); // Теплый старт
  }

  Future<void> _loadFile(String? path) async {
    if (path == null) return;
    try {
      final content = await File(path).readAsString();
      setState(() => _content = content);
    } catch (e) {
      setState(() => _content = 'Ошибка: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Text(
                _content,
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';

class TxtParser {
  Future<String> parse(String rawText) async {
    // Экранируем спецсимволы HTML (<, >, &), чтобы текст с символами вроде "a < b" не ломал вёрстку
    const htmlEscape = HtmlEscape();

    // Разбиваем текст на абзацы по переносам строк
    final paragraphs = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => '<p>${htmlEscape.convert(line)}</p>')
        .join('\n');

    return '''
      <html>
      <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { max-width: 100%; overflow-x: hidden; 
                font-size: 18px; padding: 10px;
                overflow-wrap: anywhere; word-wrap: break-word; word-break: normal; hyphens: auto; }
        p { margin-bottom: 1em; }
      </style>
      </head>
      <body>
        $paragraphs
      </body>
      </html>
    ''';
  }
}

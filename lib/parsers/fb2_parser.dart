import 'package:xml/xml.dart';

class Fb2Parser {

  Future<String> parse(String xmlText) async {

    final document = XmlDocument.parse(xmlText);

    // картинки
    final Map<String, String> images = {};
    for (final binary in document.findAllElements('binary')) {
      final id = binary.getAttribute('id');
      if (id != null) {
        final contentType = binary.getAttribute('content-type') ?? 'image/jpeg';
        final base64Data = binary.innerText.replaceAll(RegExp(r'\s+'), '');
        images[id] = 'data:$contentType;base64,$base64Data';
      }
    }

    // обложка
    String coverHtml = '';
    final coverElement = document.findAllElements('coverpage').firstOrNull;
    if (coverElement != null) {
      final coverImg = coverElement.findAllElements('image').firstOrNull;
      if (coverImg != null) {
        coverHtml = _buildImageTag(coverImg, images);
      }
    }

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

        case 'empty-line':
          return '<br>';

        case 'image':
          return _buildImageTag(node, images);

        default:
          return node.children.map(parseNode).join();
      }
    }

    final html = parseNode(body);
            
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
        h1, h2, h3, h4 { margin-top: 1.5em; margin-bottom: 0.5em; }
        blockquote { color: gray; }
        .poem { margin-left: 20px; }
        .stanza { margin-bottom: 1em; }
        img, svg, table { max-width: 100%; height: auto; display: block; margin: 1em auto; } 
      </style>
      </head>
      <body>
        $coverHtml
        ${html.toString()}
      </body>
      </html>
      ''';
     
  }

  String _buildImageTag(XmlElement node, Map<String, String> images) {
    final hrefAttr = node.attributes
        .where((attr) => attr.name.local == 'href')
        .firstOrNull;

    if (hrefAttr == null) return '';

    final imageId = hrefAttr.value.replaceFirst('#', '');
    final dataUri = images[imageId];

    if (dataUri == null) return '';

    return '<img src="$dataUri" alt="" />';
  }
}
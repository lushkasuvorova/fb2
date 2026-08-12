import 'package:xml/xml.dart';

class Fb2Parser {

  Future<String> parse(String xmlText) async {

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
            
    return '''
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
     
  }
}
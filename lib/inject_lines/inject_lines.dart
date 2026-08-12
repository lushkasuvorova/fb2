class InjectLines {
    
  Future<String> injectLines(Object width, Object height, Object contentHeight) async {

    try {
      
      final double windowWidth = double.parse(width.toString());
      final double windowHeight = double.parse(height.toString());
      final double totalHeight = double.parse(contentHeight.toString());
      
      if (windowWidth == 0 || windowHeight == 0) return '';

      // debugPrint('Ширина: $windowWidth, Высота: $windowHeight');
      // debugPrint('Общая высота контента: $totalHeight');

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
            
      return jsCode.toString();
      //
      // debugPrint('Добавлено линий: ${linesData.length}');
      
    } catch (e) {
      return '';
      // debugPrint('Ошибка инъекции линий: $e');
    }
  }
}
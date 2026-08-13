const String scrollSaveScript ='''
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

    ''';
// Custom Flutter bootstrap (Phase 1 commit 3). `flutter build web` fills
// the two placeholders below; everything else is ours.
//
// - Every font the engine fetches comes from the app itself: Roboto, the
//   engine's default fallback, is in web/fonts/roboto/ at the exact path
//   the engine asks for; any Noto fallback would 404 there instead of
//   reaching Google (the build checks no screen needs one). CanvasKit is
//   local too (`--no-web-resources-cdn`).
// - The loading screen of index.html shows real progress: its bar moves
//   when each large file has actually arrived (resource timing), then
//   through the engine's start, and it is removed on Flutter's first frame.
{{flutter_js}}
{{flutter_build_config}}

(function () {
  var loader = window.mtLoader;

  // Weights ≈ gzipped sizes in KiB: the bar advances in proportion to the
  // bytes that have actually arrived. A file missing from this list simply
  // does not move the bar.
  var files = [
    { match: /canvaskit\.wasm$/, weight: 1530 },
    { match: /main\.dart\.js$/, weight: 850 },
    { match: /Inter\.ttf$/, weight: 450 },
    { match: /canvaskit\.js$/, weight: 25 },
  ];
  var total = files.reduce(function (s, f) { return s + f.weight; }, 0);
  var arrived = 0;
  // Downloads fill 85 % of the bar; engine start and first frame the rest.
  function onResource(name) {
    for (var i = 0; i < files.length; i++) {
      if (!files[i].done && files[i].match.test(name)) {
        files[i].done = true;
        arrived += files[i].weight;
        loader && loader.progress((arrived / total) * 0.85);
      }
    }
  }
  if ('PerformanceObserver' in window) {
    try {
      new PerformanceObserver(function (list) {
        list.getEntries().forEach(function (e) { onResource(e.name); });
      }).observe({ type: 'resource', buffered: true });
    } catch (_) { /* old browser: stages only */ }
  }

  window.addEventListener('flutter-first-frame', function () {
    loader && loader.done();
  }, { once: true });

  _flutter.loader.load({
    config: { fontFallbackBaseUrl: 'fonts/' },
    onEntrypointLoaded: async function (engineInitializer) {
      loader && loader.stage('Starting…', 0.88);
      var appRunner = await engineInitializer.initializeEngine();
      loader && loader.stage('Almost there…', 0.95);
      await appRunner.runApp();
    },
  });
})();

{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {canvasKitBaseUrl: 'canvaskit/', fontFallbackBaseUrl: 'assets/fonts/'},
  onEntrypointLoaded: async function(engineInitializer) {
    const runner = await engineInitializer.initializeEngine();
    await runner.runApp();
    window.dispatchEvent(new Event('stage1-ready'));
  }
});

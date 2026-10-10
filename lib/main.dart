import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FloorPlanApp());
}

class FloorPlanApp extends StatelessWidget {
  const FloorPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '户型装修设计',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // flutter_inappwebview 的 WebViewAssetLoader 把 flutter assets
  // (APK 内 assets/flutter_assets/) 映射到 https://appassets.androidplatform.net/，
  // 使页面以 https origin 运行，ES module + import map + localStorage 均可用。
  static final WebUri _indexUrl = WebUri(
    'https://appassets.androidplatform.net/assets/flutter_assets/assets/index.html',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: _indexUrl),
        initialSettings: InAppWebViewSettings(
          webViewAssetLoader: WebViewAssetLoader(
            domain: 'appassets.androidplatform.net',
            pathHandlers: [AssetsPathHandler(path: '/assets/')],
          ),
          javaScriptEnabled: true,
          domStorageEnabled: true,
          allowFileAccess: true,
          supportZoom: false,
          builtInZoomControls: false,
          mediaPlaybackRequiresUserGesture: false,
          useHybridComposition: true,
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 浅色主题：白色状态栏 + 深色图标（避免 Android 默认深色状态栏与浅色界面割裂）
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  InAppWebViewController? _controller;

  static const String _domain = 'appassets.androidplatform.net';

  // flutter_inappwebview 的 WebViewAssetLoader 把 flutter assets
  // (APK 内 assets/flutter_assets/) 映射到 https://appassets.androidplatform.net/，
  // 使页面以 https origin 运行，ES module + import map + localStorage 均可用。
  static final WebUri _indexUrl = WebUri(
    'https://$_domain/assets/flutter_assets/assets/index.html',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 屏幕方向/尺寸变化（横竖屏切换）后状态栏高度会变，重新注入。
  @override
  void didChangeMetrics() {
    _injectStatusBarPadding();
  }

  double get _statusBarTop => MediaQuery.paddingOf(context).top;

  // Android 15 (targetSdk 35) 强制 edge-to-edge，WebView 内容会延伸到
  // 状态栏后面，而页面自身的 env(safe-area-inset-top) 在部分 WebView 上
  // 不被传入（为 0）。这里把真实状态栏高度直接写进 .app 的 padding-top。
  Future<void> _injectStatusBarPadding() async {
    final controller = _controller;
    if (controller == null) return;
    final top = _statusBarTop.toStringAsFixed(0);
    try {
      await controller.evaluateJavascript(source: '''
        (function(){
          var app = document.querySelector('.app');
          if (app) app.style.paddingTop = '${top}px';
        })();
      ''');
    } catch (_) {
      // 页面尚未就绪时忽略，onLoadStop 会再次注入。
    }
  }

  Future<void> _onWebViewCreated(InAppWebViewController controller) async {
    _controller = controller;
    // 网页全屏按钮/快捷键通过 JS bridge 通知：进入全屏切横屏，退出回竖屏。
    controller.addJavaScriptHandler(
      handlerName: 'fullscreenState',
      callback: (args) {
        final on = args.isNotEmpty && args.first == true;
        SystemChrome.setPreferredOrientations(
          on
              ? const [
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]
              : const [DeviceOrientation.portraitUp],
        );
        return null;
      },
    );
    // 网页导出文件分块传到此，交由原生 MediaStore 写入系统下载目录。
    const saveChannel = MethodChannel('app/save_file');
    controller.addJavaScriptHandler(
      handlerName: 'saveChunk',
      callback: (args) async {
        if (args.isEmpty) return null;
        try {
          final map = Map<String, dynamic>.from(args.first as Map);
          return await saveChannel
              .invokeMethod<Map<dynamic, dynamic>>('chunk', map);
        } catch (_) {
          return null;
        }
      },
    );
    await _injectStatusBarPadding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: _indexUrl),
        initialSettings: InAppWebViewSettings(
          webViewAssetLoader: WebViewAssetLoader(
            domain: _domain,
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
        onWebViewCreated: _onWebViewCreated,
        onLoadStop: (controller, url) => _injectStatusBarPadding(),
      ),
    );
  }
}
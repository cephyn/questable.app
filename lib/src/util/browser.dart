// Conditional export: uses `package:web` on web, stub on other platforms.
export 'browser_stub.dart'
    if (dart.library.js_interop) 'browser_web.dart';

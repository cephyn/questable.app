// Conditional export: uses `dart:html` on web, stub on other platforms.
export 'browser_stub.dart'
    if (dart.library.html) 'browser_web.dart';

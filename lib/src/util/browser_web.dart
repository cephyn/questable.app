import 'package:web/web.dart' as web;

String getDocumentTitle() => web.document.title;

void setDocumentTitle(String title) {
  web.document.title = title;
}

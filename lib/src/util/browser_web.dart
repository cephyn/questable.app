import 'dart:html' as html;

String getDocumentTitle() => html.document.title;

void setDocumentTitle(String title) {
  html.document.title = title;
}

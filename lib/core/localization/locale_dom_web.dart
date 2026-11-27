import 'package:web/web.dart' as web;

void syncDocumentLocale(String bcp47, bool isRtl) {
  try {
    final docEl = web.document.documentElement;
    if (docEl != null) {
      docEl.setAttribute('lang', bcp47);
      docEl.setAttribute('dir', isRtl ? 'rtl' : 'ltr');
    }
  } catch (_) {}
}

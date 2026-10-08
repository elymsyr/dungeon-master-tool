/// Entity-mention helpers for plain-text surfaces.
///
/// Mentions are stored in description / text / markdown fields as
/// `@[Name](entity:id)` markdown links (see `markdown_text_area.dart`). A
/// markdown renderer strips the leading `@` and shows the link; but plain
/// `Text` surfaces (the projection entity-card view, the projection
/// `EntitySnapshot`) have no renderer — they would show the raw markdown.
///
/// [stripMentions] collapses every mention (with or without the `@` prefix)
/// down to just its display name so plain-text views stay readable.
final RegExp _mentionRe = RegExp(r'@?\[([^\]]+)\]\(entity:[^)]+\)');

/// Replaces `@[Name](entity:id)` / `[Name](entity:id)` with `Name` and drops
/// embedded images (`![alt](dmt-img:…)`).
String stripMentions(String text) {
  if (text.isEmpty) return text;
  if (text.contains(markdownImageScheme)) {
    text = text.replaceAll(_imageRe, '');
  }
  if (!text.contains('](entity:')) return text;
  return text.replaceAllMapped(_mentionRe, (m) => m[1]!);
}

/// Markdown alanına gömülü resim: `![alt](dmt-img:<encoded ref> "50%")`. Ref
/// (yerel yol ya da herhangi bir `AssetRef` URI'si) percent-encode edilir;
/// aksi hâlde Windows yolları, boşluklar, `#` ve parantezler markdown link
/// sözdizimini bozar. İsteğe bağlı title satır genişliğinin yüzdesidir —
/// `imageBuilder` `#WxH` boyutunu değil yalnız title'ı alıyor.
const String markdownImageScheme = 'dmt-img:';

final RegExp _imageRe =
    RegExp(r'!\[([^\]]*)\]\(dmt-img:([^)\s]+)(?:\s+"(\d+)%")?\)');

/// [ref] için eklenecek markdown parçası; [width] yüzde (null = varsayılan).
String markdownImage(String ref, String alt, {int? width}) {
  final enc =
      Uri.encodeComponent(ref).replaceAll('(', '%28').replaceAll(')', '%29');
  final title = width == null ? '' : ' "$width%"';
  return '![${alt.replaceAll(RegExp(r'[\[\]]'), '')}]($markdownImageScheme$enc$title)';
}

/// `dmt-img:` sonrasındaki kodlanmış kısmı ref'e çevirir; bozuksa null.
String? decodeMarkdownImageRef(String encoded) {
  try {
    return Uri.decodeComponent(encoded);
  } catch (_) {
    return null;
  }
}

/// Resim title'ındaki yüzde genişlik (`"50%"` → 50), 10–100 aralığında.
int? markdownImageWidth(String? title) {
  final w = int.tryParse(title?.replaceAll('%', '').trim() ?? '');
  return w?.clamp(10, 100);
}

/// [text] içine gömülü tüm resim ref'leri — `UnusedMediaSweeper` bunları
/// referans sayar ki yalnız markdown'da kullanılan dosya silinmesin.
Iterable<String> markdownImageRefs(String text) sync* {
  if (!text.contains(markdownImageScheme)) return;
  for (final m in _imageRe.allMatches(text)) {
    final ref = decodeMarkdownImageRef(m[2]!);
    if (ref != null && ref.isNotEmpty) yield ref;
  }
}

/// Edit modunun blokları için gömülü resim.
typedef MarkdownImageBlock = ({String ref, String alt, int? width});

/// [text]'i metin ve resim bloklarına böler: sonuç her zaman `String` ile
/// başlar ve biter, aralarda [MarkdownImageBlock] ve (boş olabilen) metin
/// sırayla gelir. Resme bitişik birer `\n` ayraç sayılıp atılır;
/// [joinMarkdownImages] onu geri koyar.
List<Object> splitMarkdownImages(String text) {
  final out = <Object>[];
  var last = 0;
  var afterImage = false;
  void addText(String t, {required bool beforeImage}) {
    if (afterImage && t.startsWith('\n')) t = t.substring(1);
    if (beforeImage && t.endsWith('\n')) t = t.substring(0, t.length - 1);
    out.add(t);
  }

  if (text.contains(markdownImageScheme)) {
    for (final m in _imageRe.allMatches(text)) {
      final ref = decodeMarkdownImageRef(m[2]!);
      if (ref == null) continue;
      addText(text.substring(last, m.start), beforeImage: true);
      out.add((ref: ref, alt: m[1]!, width: markdownImageWidth(m[3])));
      last = m.end;
      afterImage = true;
    }
  }
  addText(text.substring(last), beforeImage: false);
  return out;
}

/// [splitMarkdownImages]'in tersi: boş olmayan bloklar `\n` ile birleşir.
String joinMarkdownImages(List<Object> blocks) => [
      for (final b in blocks)
        if (b is MarkdownImageBlock)
          markdownImage(b.ref, b.alt, width: b.width)
        else if (b is String && b.isNotEmpty)
          b,
    ].join('\n');

/// Gömülü resim [ref]'inin markdown görüntü URI'si.
Uri markdownImageUri(String ref) =>
    Uri.parse('$markdownImageScheme${Uri.encodeComponent(ref)}');

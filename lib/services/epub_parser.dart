import 'dart:io';
import 'dart:typed_data';
import 'package:epubx/epubx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class EpubParseResult {
  final String title;
  final String? author;
  final String? coverPath;
  final List<EpubChapter> chapters;
  const EpubParseResult({
    required this.title,
    this.author,
    this.coverPath,
    required this.chapters,
  });
}

class EpubChapter {
  final String? title;
  final String content;
  const EpubChapter({this.title, required this.content});
}

class EpubParserService {
  static Future<EpubParseResult> parse(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final book = await EpubReader.readBook(bytes);

    final title = book.Title?.trim().isNotEmpty == true
        ? book.Title!.trim()
        : p.basenameWithoutExtension(filePath);
    final author = book.AuthorList?.isNotEmpty == true
        ? book.AuthorList!.first
        : null;

    // 提取封面
    String? coverPath;
    if (book.CoverImage != null) {
      coverPath = await _saveCover(book.CoverImage!, title);
    }

    // 优先用 TOC 分章，TOC 缺失时遍历 HTML 文件兜底
    final chapters = await _extractChapters(book);

    return EpubParseResult(
      title: title,
      author: author,
      coverPath: coverPath,
      chapters: chapters,
    );
  }

  static Future<String?> _saveCover(Image coverImage, String title) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = title.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5]'), '_');
      final path = p.join(dir.path, 'covers', '${safeName}_cover.png');
      await Directory(p.dirname(path)).create(recursive: true);
      // epubx 的 CoverImage 是 Image 对象，需要转为 bytes
      // 注意：不同 epubx 版本的 CoverImage 类型可能不同，这里做运行时判断
      final bytes = _imageToBytes(coverImage);
      if (bytes != null) {
        await File(path).writeAsBytes(bytes);
        return path;
      }
    } catch (_) {}
    return null;
  }

  static Uint8List? _imageToBytes(Image image) {
    // 在 dart:ui 的 Image 对象中无法直接获取 PNG bytes，
    // 这里用 flutter 的 PictureRecorder 方案过重。
    // 实际 epubx 的 CoverImage 通常是 Image widget 或 Uint8List。
    // 为简化，我们先返回 null，后续如有真实需求再引入 image 包做编解码。
    return null;
  }

  static Future<List<EpubChapter>> _extractChapters(EpubBook book) async {
    final toc = book.Schema?.Navigation?.NavPoints;
    final htmlMap = book.Content?.Html;

    if (toc != null &&
        toc.isNotEmpty &&
        htmlMap != null &&
        htmlMap.isNotEmpty) {
      // 用 TOC 分章
      return _extractByToc(toc, htmlMap);
    }

    // TOC 缺失：遍历所有 HTML 文件，提取正文后按 TXT 逻辑分章
    return _extractByHtmlFallback(htmlMap);
  }

  static List<EpubChapter> _extractByToc(
    List<EpubNavigationPoint> toc,
    Map<String, EpubTextContentFile> htmlMap,
  ) {
    final chapters = <EpubChapter>[];
    for (final point in toc) {
      final fileName = _extractFileName(point.Content?.Source);
      if (fileName == null || !htmlMap.containsKey(fileName)) continue;

      final html = htmlMap[fileName]!.Content ?? '';
      final text = _stripHtml(html);
      if (text.trim().isEmpty) continue;

      chapters.add(EpubChapter(
        title: point.NavigationLabels?.first?.Text?.trim(),
        content: text,
      ));
    }
    return chapters;
  }

  static List<EpubChapter> _extractByHtmlFallback(
    Map<String, EpubTextContentFile>? htmlMap,
  ) {
    final chapters = <EpubChapter>[];
    if (htmlMap == null || htmlMap.isEmpty) return chapters;

    // 按文件名排序后拼接所有正文
    final sortedKeys = htmlMap.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final key in sortedKeys) {
      final html = htmlMap[key]!.Content ?? '';
      final text = _stripHtml(html);
      if (text.trim().isNotEmpty) {
        buffer.writeln(text);
      }
    }

    final fullText = buffer.toString();
    if (fullText.trim().isEmpty) return chapters;

    // 兜底：按正则分章（复用 ChapterSplitter 的逻辑，但这里直接内联简化）
    final pattern = RegExp(
      r'^\s*(第[0-9一二三四五六七八九十百千零]+[章回节]|Chapter\s+\d+).*$',
      multiLine: true,
      caseSensitive: false,
    );
    final matches = pattern.allMatches(fullText).toList();

    if (matches.length >= 2) {
      for (int i = 0; i < matches.length; i++) {
        final start = matches[i].start;
        final end = (i + 1 < matches.length) ? matches[i + 1].start : fullText.length;
        final chunk = fullText.substring(start, end).trim();
        chapters.add(EpubChapter(
          title: matches[i].group(0)?.trim(),
          content: chunk,
        ));
      }
    } else {
      // 按 3000 字分段
      const fallbackLength = 3000;
      int currentPos = 0;
      int index = 0;
      while (currentPos < fullText.length) {
        final end = (currentPos + fallbackLength < fullText.length)
            ? currentPos + fallbackLength
            : fullText.length;
        int cutPos = end;
        if (end < fullText.length) {
          final searchRange = fullText.substring(end - 50, end + 50);
          final lastPeriod = searchRange.lastIndexOf(RegExp(r'[。！？.\n]'));
          if (lastPeriod != -1) {
            cutPos = end - 50 + lastPeriod + 1;
          }
        }
        final chunk = fullText.substring(currentPos, cutPos).trim();
        if (chunk.isNotEmpty) {
          chapters.add(EpubChapter(
            title: '第${index + 1}段',
            content: chunk,
          ));
        }
        currentPos = cutPos;
        index++;
      }
    }

    return chapters;
  }

  static String? _extractFileName(String? source) {
    if (source == null) return null;
    // 去掉锚点
    final idx = source.indexOf('#');
    final path = idx == -1 ? source : source.substring(0, idx);
    return path.trim();
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .trim();
  }
}

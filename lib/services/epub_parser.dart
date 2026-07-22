import 'dart:io';
import 'dart:typed_data';
import 'package:epubx/epubx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class EpubParseResult {
  final String title;
  final String? author;
  final String? coverPath;
  final List<EpubChapterItem> chapters;
  const EpubParseResult({
    required this.title,
    this.author,
    this.coverPath,
    required this.chapters,
  });
}

class EpubChapterItem {
  final String? title;
  final String content;
  const EpubChapterItem({this.title, required this.content});
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

    String? coverPath;
    if (book.CoverImage != null) {
      coverPath = await _saveCover(book.CoverImage!, title);
    }

    final chapters = _extractChapters(book);

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
      final bytes = _imageToBytes(coverImage);
      if (bytes != null) {
        await File(path).writeAsBytes(bytes);
        return path;
      }
    } catch (_) {}
    return null;
  }

  static Uint8List? _imageToBytes(Image image) {
    return null;
  }

  static List<EpubChapterItem> _extractChapters(EpubBook book) {
    final result = <EpubChapterItem>[];

    if (book.Chapters != null && book.Chapters!.isNotEmpty) {
      _flattenChapters(book.Chapters!, result);
    }

    if (result.isNotEmpty) {
      return result;
    }

    final htmlMap = book.Content?.Html;
    return _extractByHtmlFallback(htmlMap);
  }

  static void _flattenChapters(
    List<EpubChapter> chapters,
    List<EpubChapterItem> result,
  ) {
    for (final ch in chapters) {
      final html = ch.HtmlContent ?? '';
      final text = _stripHtml(html);
      if (text.trim().isNotEmpty) {
        result.add(EpubChapterItem(
          title: ch.Title?.trim(),
          content: text,
        ));
      }
      if (ch.SubChapters != null && ch.SubChapters!.isNotEmpty) {
        _flattenChapters(ch.SubChapters!, result);
      }
    }
  }

  static List<EpubChapterItem> _extractByHtmlFallback(
    Map<String, EpubTextContentFile>? htmlMap,
  ) {
    final chapters = <EpubChapterItem>[];
    if (htmlMap == null || htmlMap.isEmpty) return chapters;

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
        chapters.add(EpubChapterItem(
          title: matches[i].group(0)?.trim(),
          content: chunk,
        ));
      }
    } else {
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
          chapters.add(EpubChapterItem(
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
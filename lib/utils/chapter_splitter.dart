import '../models/chapter.dart';
import 'constants.dart';

class SplitResult {
  final String? title;
  final String content;
  const SplitResult({this.title, required this.content});
}

class ChapterSplitter {
  // 按优先级排序的章节标题正则规则
  static final List<RegExp> _chapterPatterns = [
    RegExp(r'^\s*第[0-9一二三四五六七八九十百千零]+章.*$', multiLine: true),
    RegExp(r'^\s*第[0-9一二三四五六七八九十百千零]+回.*$', multiLine: true),
    RegExp(r'^\s*第[0-9一二三四五六七八九十百千零]+节.*$', multiLine: true),
    RegExp(r'^\s*[第卷集篇][0-9一二三四五六七八九十百千零]+.*$', multiLine: true),
    RegExp(r'^\s*Chapter\s+\d+.*$', caseSensitive: false, multiLine: true),
    RegExp(r'^\s*CHAPTER\s+\d+.*$', multiLine: true),
  ];

  /// 将全文切分为章节列表。
  /// 优先使用正则识别章节标题，无法识别时使用固定字数兜底。
  static List<SplitResult> split(String text, {int fallbackLength = AppConstants.defaultChapterSplitLength}) {
    final results = <SplitResult>[];

    // 先尝试正则分章
    final matches = <_ChapterMatch>[];
    final lines = text.split('\n');
    int globalOffset = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final pattern in _chapterPatterns) {
        if (pattern.hasMatch(line)) {
          matches.add(_ChapterMatch(
            title: line.trim(),
            lineIndex: i,
            charStart: globalOffset,
          ));
          break;
        }
      }
      globalOffset += line.length + 1; // +1 for '\n'
    }

    if (matches.length >= 2) {
      // 使用正则匹配结果切分
      for (int i = 0; i < matches.length; i++) {
        final start = matches[i].charStart;
        final end = (i + 1 < matches.length) ? matches[i + 1].charStart : text.length;
        final content = text.substring(start, end).trim();
        results.add(SplitResult(title: matches[i].title, content: content));
      }
    } else {
      // 兜底：按固定字数分段
      int index = 0;
      int currentPos = 0;
      while (currentPos < text.length) {
        final end = (currentPos + fallbackLength < text.length)
            ? currentPos + fallbackLength
            : text.length;
        // 尽量在句号、换行处截断，避免切断句子
        int cutPos = end;
        if (end < text.length) {
          final searchRange = text.substring(end - 50, end + 50);
          final lastPeriod = searchRange.lastIndexOf(RegExp(r'[。！？.\n]'));
          if (lastPeriod != -1) {
            cutPos = end - 50 + lastPeriod + 1;
          }
        }
        final chunk = text.substring(currentPos, cutPos).trim();
        if (chunk.isNotEmpty) {
          results.add(SplitResult(
            title: '第${index + 1}段',
            content: chunk,
          ));
        }
        currentPos = cutPos;
        index++;
      }
    }

    return results;
  }
}

class _ChapterMatch {
  final String title;
  final int lineIndex;
  final int charStart;
  _ChapterMatch({required this.title, required this.lineIndex, required this.charStart});
}

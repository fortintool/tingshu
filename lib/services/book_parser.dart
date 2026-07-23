import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:charset/charset.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/reading_progress.dart';
import '../utils/chapter_splitter.dart';
import 'epub_parser.dart';
import 'pdf_parser.dart';

class BookParser {
  static final BookParser instance = BookParser._init();
  BookParser._init();

  final _db = DatabaseHelper.instance;

  /// 自动检测编码并解码 bytes 为字符串。
  /// 优先 UTF-8，然后尝试 GBK，最后用 latin1 兜底。
  String _decodeBytes(List<int> bytes) {
    // 1. 先试 UTF-8（allowMalformed 让它尽量解码不抛异常）
    try {
      final utf8Str = utf8.decode(bytes, allowMalformed: false);
      // 检查是否有替换字符（U+FFFD），如果很少可能就是 UTF-8
      final replacementCount = utf8Str.runes.where((r) => r == 0xFFFD).length;
      if (replacementCount == 0 || replacementCount / utf8Str.length < 0.01) {
        return utf8Str;
      }
    } catch (_) {}

    // 2. 尝试 GBK
    try {
      final gbkStr = gbk.decode(bytes);
      if (gbkStr.isNotEmpty) {
        return gbkStr;
      }
    } catch (_) {}

    // 3. 尝试 GB18030（GBK 的超集）
    try {
      final gb18030Str = Charset.fromName('GB18030')?.decode(bytes) ?? '';
      if (gb18030Str.isNotEmpty) {
        return gb18030Str;
      }
    } catch (_) {}

    // 4. 最后兜底：UTF-8 with allowMalformed
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 从文件管理器选择并导入书籍（支持 TXT / EPUB）。
  Future<int?> importBook() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('FilePicker error: $e');
      return null;
    }

    if (result == null || result.files.isEmpty) return null;

    final platformFile = result.files.first;
    final path = platformFile.path;
    final name = platformFile.name;
    final ext = p.extension(name).toLowerCase();

    // 优先使用 bytes（兼容 Android content:// URI 场景）
    final bytes = platformFile.bytes;

    if (ext == '.epub') {
      if (bytes != null) {
        final tempPath = await _saveTempFile(name, bytes);
        if (tempPath != null) return importEpubFromPath(tempPath);
      }
      if (path != null) return importEpubFromPath(path);
      return null;
    }
    if (ext == '.pdf') {
      if (bytes != null) {
        final tempPath = await _saveTempFile(name, bytes);
        if (tempPath != null) return importPdfFromPath(tempPath);
      }
      if (path != null) return importPdfFromPath(path);
      return null;
    }

    // TXT：优先用 bytes 直接解码，避免 content:// URI 无法读取
    if (bytes != null) {
      final content = _decodeBytes(bytes);
      if (content.trim().isEmpty) return null;
      return _importTxtContent(p.basenameWithoutExtension(name), content, path);
    }

    if (path != null) return importTxtFromPath(path);
    return null;
  }

  /// 将 bytes 写入临时目录，返回临时文件路径。
  Future<String?> _saveTempFile(String fileName, Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final tempPath = p.join(
        dir.path,
        'import_${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );
      await File(tempPath).writeAsBytes(bytes);
      return tempPath;
    } catch (e) {
      debugPrint('_saveTempFile error: $e');
      return null;
    }
  }

  /// TXT 导入核心逻辑：直接传入已解码的文本内容。
  Future<int?> _importTxtContent(String fileName, String content, String? filePath) async {
    try {
      // 自动分章
      final splitResults = ChapterSplitter.split(content);

      final now = DateTime.now().millisecondsSinceEpoch;

      // 插入书籍记录
      final book = Book(
        title: fileName,
        filePath: filePath ?? '',
        fileType: 'txt',
        totalChars: content.length,
        createdAt: now,
        updatedAt: now,
      );
      final bookId = await _db.insertBook(book);

      // 构建章节对象并批量插入
      final chapters = <Chapter>[];
      int globalCharStart = 0;
      for (int i = 0; i < splitResults.length; i++) {
        final r = splitResults[i];
        final chapterContent = r.content;
        final charStart = globalCharStart;
        final charEnd = globalCharStart + chapterContent.length;
        chapters.add(Chapter(
          bookId: bookId,
          title: r.title,
          content: chapterContent,
          charStart: charStart,
          charEnd: charEnd,
          chapterIndex: i,
          createdAt: now,
        ));
        globalCharStart = charEnd;
      }

      await _db.insertChaptersBatch(chapters);

      // 查询插入后的章节以获取真实 id
      final savedChapters = await _db.getChaptersByBook(bookId);
      if (savedChapters.isEmpty) return bookId;

      // 初始化默认进度（第一章开头）
      final firstChapter = savedChapters.first;
      await _db.upsertProgress(ReadingProgress(
        bookId: bookId,
        chapterId: firstChapter.id!,
        charPosition: 0,
        updatedAt: now,
      ));

      return bookId;
    } catch (e, st) {
      debugPrint('_importTxtContent error: $e\n$st');
      return null;
    }
  }

  /// 根据扩展名自动路由到对应解析器（用于分享导入）。
  Future<int?> importBookFromPath(String filePath) async {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.epub') return importEpubFromPath(filePath);
    if (ext == '.pdf') return importPdfFromPath(filePath);
    return importTxtFromPath(filePath);
  }

  /// 从给定路径导入 TXT（也用于接收分享的场景）。
  Future<int?> importTxtFromPath(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final fileName = p.basenameWithoutExtension(filePath);
      final bytes = await file.readAsBytes();
      final content = _decodeBytes(bytes);

      if (content.trim().isEmpty) return null;
      return _importTxtContent(fileName, content, filePath);
    } catch (e, st) {
      debugPrint('importTxtFromPath error: $e\n$st');
      return null;
    }
  }

  /// 从给定路径导入 EPUB。
  Future<int?> importEpubFromPath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final result = await EpubParserService.parse(filePath);
    if (result.chapters.isEmpty) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    int totalChars = 0;
    for (final c in result.chapters) {
      totalChars += c.content.length;
    }

    final book = Book(
      title: result.title,
      author: result.author,
      coverPath: result.coverPath,
      filePath: filePath,
      fileType: 'epub',
      totalChars: totalChars,
      createdAt: now,
      updatedAt: now,
    );
    final bookId = await _db.insertBook(book);

    final chapters = <Chapter>[];
    int globalCharStart = 0;
    for (int i = 0; i < result.chapters.length; i++) {
      final c = result.chapters[i];
      final charStart = globalCharStart;
      final charEnd = globalCharStart + c.content.length;
      chapters.add(Chapter(
        bookId: bookId,
        title: c.title,
        content: c.content,
        charStart: charStart,
        charEnd: charEnd,
        chapterIndex: i,
        createdAt: now,
      ));
      globalCharStart = charEnd;
    }

    await _db.insertChaptersBatch(chapters);

    final savedChapters = await _db.getChaptersByBook(bookId);
    if (savedChapters.isEmpty) return bookId;

    final firstChapter = savedChapters.first;
    await _db.upsertProgress(ReadingProgress(
      bookId: bookId,
      chapterId: firstChapter.id!,
      charPosition: 0,
      updatedAt: now,
    ));

    return bookId;
  }

  /// 从给定路径导入 PDF。
  Future<int?> importPdfFromPath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final result = await PdfParserService.parse(filePath);
    if (result.chapters.isEmpty) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    int totalChars = 0;
    for (final c in result.chapters) {
      totalChars += c.content.length;
    }

    final book = Book(
      title: result.title,
      filePath: filePath,
      fileType: 'pdf',
      totalChars: totalChars,
      createdAt: now,
      updatedAt: now,
    );
    final bookId = await _db.insertBook(book);

    final chapters = <Chapter>[];
    int globalCharStart = 0;
    for (int i = 0; i < result.chapters.length; i++) {
      final c = result.chapters[i];
      final charStart = globalCharStart;
      final charEnd = globalCharStart + c.content.length;
      chapters.add(Chapter(
        bookId: bookId,
        title: c.title,
        content: c.content,
        charStart: charStart,
        charEnd: charEnd,
        chapterIndex: i,
        createdAt: now,
      ));
      globalCharStart = charEnd;
    }

    await _db.insertChaptersBatch(chapters);

    final savedChapters = await _db.getChaptersByBook(bookId);
    if (savedChapters.isEmpty) return bookId;

    final firstChapter = savedChapters.first;
    await _db.upsertProgress(ReadingProgress(
      bookId: bookId,
      chapterId: firstChapter.id!,
      charPosition: 0,
      updatedAt: now,
    ));

    return bookId;
  }
}

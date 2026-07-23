import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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

  /// 从文件管理器选择并导入书籍（支持 TXT / EPUB）。
  Future<int?> importBook() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
        withReadStream: false,
      );
    } catch (e) {
      debugPrint('FilePicker error: $e');
      return null;
    }

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final path = file.path;
    if (path == null) return null;

    final ext = p.extension(path).toLowerCase();
    if (ext == '.epub') {
      return importEpubFromPath(path);
    }
    if (ext == '.pdf') {
      return importPdfFromPath(path);
    }
    return importTxtFromPath(path);
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
    final file = File(filePath);
    if (!await file.exists()) return null;

    final fileName = p.basenameWithoutExtension(filePath);
    final content = await file.readAsString();

    if (content.trim().isEmpty) return null;

    // 自动分章
    final splitResults = ChapterSplitter.split(content);

    final now = DateTime.now().millisecondsSinceEpoch;

    // 插入书籍记录
    final book = Book(
      title: fileName,
      filePath: filePath,
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

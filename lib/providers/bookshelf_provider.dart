import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/book.dart';
import '../models/reading_progress.dart';

enum BookSortMode { lastRead, title }

class BookWithProgress {
  final Book book;
  final ReadingProgress? progress;
  final double progressPercent;

  BookWithProgress({
    required this.book,
    required this.progress,
    required this.progressPercent,
  });
}

class BookshelfNotifier extends StateNotifier<AsyncValue<List<BookWithProgress>>> {
  BookshelfNotifier() : super(const AsyncValue.loading());

  final _db = DatabaseHelper.instance;
  BookSortMode _sortMode = BookSortMode.lastRead;

  BookSortMode get sortMode => _sortMode;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final orderBy = _sortMode == BookSortMode.lastRead
          ? 'lastReadAt DESC, createdAt DESC'
          : 'title COLLATE NOCASE ASC';
      final books = await _db.getAllBooks(orderBy: orderBy);

      final booksWithProgress = <BookWithProgress>[];
      for (final book in books) {
        final progress = await _db.getProgress(book.id!);
        double percent = 0;
        if (progress != null && book.totalChars != null && book.totalChars! > 0) {
          final chapter = await _db.getChapter(progress.chapterId);
          if (chapter != null) {
            final totalRead = chapter.charStart + progress.charPosition;
            percent = (totalRead / book.totalChars!) * 100;
            if (percent > 100) percent = 100;
          }
        }
        booksWithProgress.add(BookWithProgress(
          book: book,
          progress: progress,
          progressPercent: percent,
        ));
      }

      state = AsyncValue.data(booksWithProgress);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setSortMode(BookSortMode mode) async {
    _sortMode = mode;
    await load();
  }

  Future<void> deleteBook(int id) async {
    await _db.deleteBook(id);
    await load();
  }

  Future<void> renameBook(int id, String newTitle) async {
    final book = await _db.getBook(id);
    if (book == null) return;
    await _db.updateBook(book.copyWith(
      title: newTitle,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await load();
  }
}

final bookshelfProvider =
    StateNotifierProvider<BookshelfNotifier, AsyncValue<List<BookWithProgress>>>(
  (ref) => BookshelfNotifier(),
);

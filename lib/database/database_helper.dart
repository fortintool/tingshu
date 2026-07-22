import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/reading_progress.dart';
import '../models/app_settings.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tingshu.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        coverPath TEXT,
        filePath TEXT NOT NULL,
        fileType TEXT NOT NULL,
        totalChars INTEGER DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        lastReadAt INTEGER,
        sortOrder INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER NOT NULL,
        title TEXT,
        content TEXT NOT NULL,
        charStart INTEGER NOT NULL,
        charEnd INTEGER NOT NULL,
        chapterIndex INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE reading_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER NOT NULL UNIQUE,
        chapterId INTEGER NOT NULL,
        charPosition INTEGER NOT NULL,
        totalListenedMs INTEGER DEFAULT 0,
        updatedAt INTEGER NOT NULL,
        FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE user_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        defaultVoice TEXT,
        defaultSpeed REAL DEFAULT 1.0,
        defaultPitch REAL DEFAULT 1.0,
        themeMode TEXT DEFAULT 'system',
        syncHighlightEnabled INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE book_settings (
        bookId INTEGER PRIMARY KEY,
        voice TEXT,
        speed REAL,
        pitch REAL,
        FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    // 插入默认全局设置
    await db.insert('user_settings', {
      'id': 1,
      'defaultSpeed': 1.0,
      'defaultPitch': 1.0,
      'themeMode': 'system',
      'syncHighlightEnabled': 1,
    });
  }

  // ================== Books ==================
  Future<int> insertBook(Book book) async {
    final db = await database;
    return await db.insert('books', book.toMap());
  }

  Future<List<Book>> getAllBooks({String orderBy = 'lastReadAt DESC'}) async {
    final db = await database;
    final maps = await db.query('books', orderBy: orderBy);
    return maps.map((e) => Book.fromMap(e)).toList();
  }

  Future<Book?> getBook(int id) async {
    final db = await database;
    final maps = await db.query('books', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Book.fromMap(maps.first);
    return null;
  }

  Future<int> updateBook(Book book) async {
    final db = await database;
    return await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<int> deleteBook(int id) async {
    final db = await database;
    return await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  // ================== Chapters ==================
  Future<int> insertChapter(Chapter chapter) async {
    final db = await database;
    return await db.insert('chapters', chapter.toMap());
  }

  Future<void> insertChaptersBatch(List<Chapter> chapters) async {
    final db = await database;
    final batch = db.batch();
    for (final c in chapters) {
      batch.insert('chapters', c.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<Chapter>> getChaptersByBook(int bookId) async {
    final db = await database;
    final maps = await db.query(
      'chapters',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'chapterIndex ASC',
    );
    return maps.map((e) => Chapter.fromMap(e)).toList();
  }

  Future<Chapter?> getChapter(int id) async {
    final db = await database;
    final maps = await db.query('chapters', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Chapter.fromMap(maps.first);
    return null;
  }

  Future<Chapter?> getChapterByIndex(int bookId, int chapterIndex) async {
    final db = await database;
    final maps = await db.query(
      'chapters',
      where: 'bookId = ? AND chapterIndex = ?',
      whereArgs: [bookId, chapterIndex],
    );
    if (maps.isNotEmpty) return Chapter.fromMap(maps.first);
    return null;
  }

  // ================== Reading Progress ==================
  Future<int> upsertProgress(ReadingProgress progress) async {
    final db = await database;
    final existing = await db.query(
      'reading_progress',
      where: 'bookId = ?',
      whereArgs: [progress.bookId],
    );
    if (existing.isNotEmpty) {
      return await db.update(
        'reading_progress',
        progress.toMap(),
        where: 'bookId = ?',
        whereArgs: [progress.bookId],
      );
    } else {
      return await db.insert('reading_progress', progress.toMap());
    }
  }

  Future<ReadingProgress?> getProgress(int bookId) async {
    final db = await database;
    final maps = await db.query(
      'reading_progress',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
    if (maps.isNotEmpty) return ReadingProgress.fromMap(maps.first);
    return null;
  }

  Future<int> deleteProgress(int bookId) async {
    final db = await database;
    return await db.delete(
      'reading_progress',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
  }

  // ================== User Settings ==================
  Future<UserSettings> getUserSettings() async {
    final db = await database;
    final maps = await db.query('user_settings', where: 'id = 1');
    if (maps.isNotEmpty) return UserSettings.fromMap(maps.first);
    return const UserSettings();
  }

  Future<int> updateUserSettings(UserSettings settings) async {
    final db = await database;
    return await db.update(
      'user_settings',
      settings.toMap(),
      where: 'id = 1',
    );
  }

  // ================== Book Settings ==================
  Future<BookSettings?> getBookSettings(int bookId) async {
    final db = await database;
    final maps = await db.query(
      'book_settings',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
    if (maps.isNotEmpty) return BookSettings.fromMap(maps.first);
    return null;
  }

  Future<int> upsertBookSettings(BookSettings settings) async {
    final db = await database;
    final existing = await db.query(
      'book_settings',
      where: 'bookId = ?',
      whereArgs: [settings.bookId],
    );
    if (existing.isNotEmpty) {
      return await db.update(
        'book_settings',
        settings.toMap(),
        where: 'bookId = ?',
        whereArgs: [settings.bookId],
      );
    } else {
      return await db.insert('book_settings', settings.toMap());
    }
  }

  Future<int> deleteBookSettings(int bookId) async {
    final db = await database;
    return await db.delete(
      'book_settings',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
  }

  Future close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}

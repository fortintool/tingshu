import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/reading_progress.dart';
import '../database/database_helper.dart';
import 'tts_service.dart';

/// TTS 听书场景的 AudioHandler。
/// 适配 audio_service 框架：让通知栏/锁屏/耳机按钮能控制 TTS。
///
/// 注意：PlayerScreen 直接使用 TtsService 播放，不经过此 handler。
/// 此 handler 仅用于 ProgressSaver 保存进度和通知栏基础控制。
class TtsAudioHandler extends BaseAudioHandler {
  TtsAudioHandler({required this.ttsService});

  final TtsService ttsService;
  final DatabaseHelper _db = DatabaseHelper.instance;

  // 当前播放上下文
  Book? _currentBook;
  Chapter? _currentChapter;
  bool _isPlaying = false;

  /// 播放指定章节（通知栏控制用）
  Future<void> playChapter({
    required Book book,
    required Chapter chapter,
    int startOffset = 0,
  }) async {
    try {
      _currentBook = book;
      _currentChapter = chapter;

      final item = MediaItem(
        id: 'book-${book.id}-chapter-${chapter.id}',
        album: book.title,
        title: chapter.title ?? '未命名章节',
        artist: book.author ?? '听书',
      );
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (_isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        playing: true,
        processingState: AudioProcessingState.ready,
      ));
      mediaItem.add(item);

      await ttsService.speak(
        text: chapter.content,
        bookId: book.id!,
        chapterId: chapter.id!,
        chapterCharStart: chapter.charStart,
        startOffset: startOffset,
      );
      _isPlaying = true;
      _updatePlayingState(true);
    } catch (e, st) {
      debugPrint('playChapter error: $e\n$st');
    }
  }

  void _updatePlayingState(bool playing) {
    _isPlaying = playing;
    playbackState.add(playbackState.value.copyWith(
      playing: playing,
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
    ));
  }

  // ============ BaseAudioHandler 回调 ============

  @override
  Future<void> play() async {
    if (_currentChapter == null || _currentBook == null) return;
    try {
      if (ttsService.currentCharPosition == 0 && !_isPlaying) {
        await ttsService.speak(
          text: _currentChapter!.content,
          bookId: _currentBook!.id!,
          chapterId: _currentChapter!.id!,
          chapterCharStart: _currentChapter!.charStart,
          startOffset: 0,
        );
      } else {
        await ttsService.resume();
      }
      _updatePlayingState(true);
    } catch (e) {
      debugPrint('AudioHandler play error: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await ttsService.pause();
      _updatePlayingState(false);
    } catch (e) {
      debugPrint('AudioHandler pause error: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await ttsService.stop();
      _updatePlayingState(false);
    } catch (e) {
      debugPrint('AudioHandler stop error: $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_currentBook == null || _currentChapter == null) return;
    final nextIdx = _currentChapter!.chapterIndex + 1;
    final next = await _db.getChapterByIndex(_currentBook!.id!, nextIdx);
    if (next == null) return;
    await playChapter(book: _currentBook!, chapter: next, startOffset: 0);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentBook == null || _currentChapter == null) return;
    final prevIdx = _currentChapter!.chapterIndex - 1;
    if (prevIdx < 0) return;
    final prev = await _db.getChapterByIndex(_currentBook!.id!, prevIdx);
    if (prev == null) return;
    await playChapter(book: _currentBook!, chapter: prev, startOffset: 0);
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> skipToQueueItem(int index) async {}

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {}

  // ============ 进度保存 ============

  /// 强制保存当前进度（由生命周期变化时调用）
  Future<void> flushProgress() async {
    final bookId = ttsService.currentBookId;
    final chapterId = ttsService.currentChapterId;
    if (bookId == null || chapterId == null) return;
    final chapter = await _db.getChapter(chapterId);
    if (chapter == null) return;
    final charPos = ttsService.currentCharPosition;
    final totalListenedMs = await _accumulateListenedMs(bookId, chapterId, charPos);
    await _db.upsertProgress(ReadingProgress(
      bookId: bookId,
      chapterId: chapterId,
      charPosition: charPos,
      totalListenedMs: totalListenedMs,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _db.updateBook((await _db.getBook(bookId))!.copyWith(
      lastReadAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  int _sessionStartMs = 0;

  Future<int> _accumulateListenedMs(int bookId, int chapterId, int charPos) async {
    final existing = await _db.getProgress(bookId);
    int base = existing?.totalListenedMs ?? 0;
    if (_sessionStartMs > 0) {
      final delta = DateTime.now().millisecondsSinceEpoch - _sessionStartMs;
      base += delta;
      _sessionStartMs = 0;
    }
    return base;
  }

  void onPlaybackStart() {
    _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> dispose() async {
    await ttsService.stop();
  }
}

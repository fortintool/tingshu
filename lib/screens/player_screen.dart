import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../services/tts_service.dart';
import '../database/database_helper.dart';
import '../providers/player_provider.dart';
import '../providers/book_settings_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/sync_highlight_view.dart';
import 'chapter_list_screen.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final Book book;
  const PlayerScreen({super.key, required this.book});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

enum PlayerMode { listening, reading }

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  Chapter? _currentChapter;
  bool _isPlaying = false;
  PlayerMode _mode = PlayerMode.listening;
  int _currentPosition = 0;
  ScrollController? _textScrollController;

  StreamSubscription? _progressSub;
  StreamSubscription? _completionSub;

  @override
  void initState() {
    super.initState();
    _textScrollController = ScrollController();
    _loadAndPlay();
    _subscribeStreams();
  }

  Future<void> _loadAndPlay() async {
    try {
      final db = DatabaseHelper.instance;
      final bookId = widget.book.id!;

      final progress = await db.getProgress(bookId);
      int startChapterId;
      int startCharPos;
      if (progress != null) {
        startChapterId = progress.chapterId;
        startCharPos = progress.charPosition;
      } else {
        final chapters = await db.getChaptersByBook(bookId);
        if (chapters.isEmpty) return;
        startChapterId = chapters.first.id!;
        startCharPos = 0;
      }

      final chapter = await db.getChapter(startChapterId);
      if (chapter == null) return;

      if (mounted) {
        setState(() {
          _currentChapter = chapter;
          _currentPosition = startCharPos;
        });
      }

      await _playChapter(chapter, startCharPos);
    } catch (e, st) {
      debugPrint('PlayerScreen _loadAndPlay error: $e\n$st');
    }
  }

  void _subscribeStreams() {
    _progressSub = TtsService.instance.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _currentPosition = progress.chapter;
        });
      }
    });

    _completionSub = TtsService.instance.completionStream.listen((_) {
      _onChapterComplete();
    });
  }

  Future<void> _playChapter(Chapter chapter, int startOffset) async {
    try {
      await TtsService.instance.speak(
        text: chapter.content,
        bookId: widget.book.id!,
        chapterId: chapter.id!,
        chapterCharStart: chapter.charStart,
        startOffset: startOffset,
      );
      if (mounted) {
        setState(() => _isPlaying = true);
        ref.read(playerStateProvider.notifier).setPlaying(
              book: widget.book,
              chapter: chapter,
              isPlaying: true,
            );
      }
    } catch (e) {
      debugPrint('_playChapter error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }

  Future<void> _onChapterComplete() async {
    if (_currentChapter == null) return;
    try {
      final nextIdx = _currentChapter!.chapterIndex + 1;
      final next = await DatabaseHelper.instance.getChapterByIndex(
        widget.book.id!,
        nextIdx,
      );
      if (next == null) {
        if (mounted) setState(() => _isPlaying = false);
        return;
      }
      if (mounted) {
        setState(() {
          _currentChapter = next;
          _currentPosition = 0;
        });
      }
      await _playChapter(next, 0);
    } catch (e) {
      debugPrint('_onChapterComplete error: $e');
    }
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await TtsService.instance.pause();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        if (_currentChapter == null) return;
        final pos = TtsService.instance.currentCharPosition;
        await _playChapter(_currentChapter!, pos);
      }
      ref.read(playerStateProvider.notifier).setPlaying(
            book: widget.book,
            chapter: _currentChapter,
            isPlaying: _isPlaying,
          );
    } catch (e) {
      debugPrint('_togglePlay error: $e');
    }
  }

  Future<void> _nextChapter() async {
    if (_currentChapter == null) return;
    try {
      final nextIdx = _currentChapter!.chapterIndex + 1;
      final next = await DatabaseHelper.instance.getChapterByIndex(
        widget.book.id!,
        nextIdx,
      );
      if (next == null) return;
      if (mounted) {
        setState(() {
          _currentChapter = next;
          _currentPosition = 0;
        });
      }
      await _playChapter(next, 0);
    } catch (e) {
      debugPrint('_nextChapter error: $e');
    }
  }

  Future<void> _prevChapter() async {
    if (_currentChapter == null) return;
    try {
      final prevIdx = _currentChapter!.chapterIndex - 1;
      if (prevIdx < 0) return;
      final prev = await DatabaseHelper.instance.getChapterByIndex(
        widget.book.id!,
        prevIdx,
      );
      if (prev == null) return;
      if (mounted) {
        setState(() {
          _currentChapter = prev;
          _currentPosition = 0;
        });
      }
      await _playChapter(prev, 0);
    } catch (e) {
      debugPrint('_prevChapter error: $e');
    }
  }

  void _showBookSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BookSettingsSheet(bookId: widget.book.id!),
    );
  }

  void _onTextTap(int charOffset) {
    if (_currentChapter == null) return;
    setState(() => _currentPosition = charOffset);
    TtsService.instance.speak(
      text: _currentChapter!.content.substring(charOffset),
      bookId: widget.book.id!,
      chapterId: _currentChapter!.id!,
      chapterCharStart: charOffset,
    );
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _completionSub?.cancel();
    TtsService.instance.stop();
    _textScrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _currentChapter;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        actions: [
          IconButton(
            tooltip: _mode == PlayerMode.listening ? '切换听读同步' : '切换纯听音',
            icon: Icon(
              _mode == PlayerMode.listening ? Icons.menu_book : Icons.audiotrack,
            ),
            onPressed: () {
              setState(() {
                _mode = _mode == PlayerMode.listening ? PlayerMode.reading : PlayerMode.listening;
              });
            },
          ),
          IconButton(
            tooltip: '章节列表',
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChapterListScreen(book: widget.book),
                ),
              );
            },
          ),
        ],
      ),
      body: _mode == PlayerMode.listening
          ? _buildListeningView(chapter)
          : _buildReadingView(chapter),
    );
  }

  Widget _buildListeningView(Chapter? chapter) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            chapter?.title ?? '加载中...',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                iconSize: 48,
                onPressed: _prevChapter,
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton(
                iconSize: 72,
                onPressed: _togglePlay,
                icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle),
              ),
              IconButton(
                iconSize: 48,
                onPressed: _nextChapter,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _showBookSettings,
            icon: const Icon(Icons.tune),
            label: const Text('本书语音设置'),
          ),
          const SizedBox(height: 24),
          Text(
            chapter?.content ?? '',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReadingView(Chapter? chapter) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Text(chapter?.title ?? '加载中...', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text(
                _currentPosition.toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: chapter == null
                ? const Center(child: CircularProgressIndicator())
                : Scrollbar(
                    controller: _textScrollController,
                    child: SyncHighlightView(
                      text: chapter.content,
                      currentPosition: _currentPosition,
                      onTapPosition: _onTextTap,
                    ),
                  ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                iconSize: 36,
                onPressed: _prevChapter,
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton(
                iconSize: 48,
                onPressed: _togglePlay,
                icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle),
              ),
              IconButton(
                iconSize: 36,
                onPressed: _nextChapter,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookSettingsSheet extends ConsumerStatefulWidget {
  final int bookId;
  const _BookSettingsSheet({required this.bookId});

  @override
  ConsumerState<_BookSettingsSheet> createState() => _BookSettingsSheetState();
}

class _BookSettingsSheetState extends ConsumerState<_BookSettingsSheet> {
  List<Map<String, String>> _voices = [];
  bool _loadingVoices = true;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    List<Map<String, String>> list = [];
    Timer? timer;
    bool completed = false;

    timer = Timer(const Duration(seconds: 2), () {
      if (!completed && mounted) {
        setState(() {
          _loadingVoices = false;
          _voices = [];
        });
      }
      completed = true;
    });

    try {
      list = await TtsService.instance.getVoices();
      if (!completed && mounted) {
        timer.cancel();
        setState(() {
          _voices = list;
          _loadingVoices = false;
        });
      }
      completed = true;
    } catch (e) {
      debugPrint('_BookSettingsSheet _loadVoices error: $e');
      if (!completed && mounted) {
        timer.cancel();
        setState(() => _loadingVoices = false);
      }
      completed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookSettings = ref.watch(bookSettingsProvider(widget.bookId));
    final globalSettings = ref.watch(settingsProvider);
    final bookNotifier = ref.read(bookSettingsProvider(widget.bookId).notifier);

    final effectiveVoice = bookSettings?.voice ?? globalSettings.defaultVoice;
    final effectiveSpeed = bookSettings?.speed ?? globalSettings.defaultSpeed;
    final effectivePitch = bookSettings?.pitch ?? globalSettings.defaultPitch;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('本书语音设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => bookNotifier.clear(),
                  child: const Text('恢复全局默认'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _loadingVoices
                ? const Center(child: CircularProgressIndicator())
                : ListTile(
                    title: const Text('发音人'),
                    subtitle: Text(effectiveVoice ?? '系统默认'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showVoicePicker(bookNotifier, bookSettings?.voice),
                  ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('语速'),
              subtitle: Text('${effectiveSpeed.toStringAsFixed(1)}x'),
            ),
            Slider(
              value: effectiveSpeed,
              min: 0.5,
              max: 3.0,
              divisions: 25,
              label: effectiveSpeed.toStringAsFixed(1),
              onChanged: (v) => bookNotifier.setSpeed(v),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('音调'),
              subtitle: Text('${effectivePitch.toStringAsFixed(1)}x'),
            ),
            Slider(
              value: effectivePitch,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: effectivePitch.toStringAsFixed(1),
              onChanged: (v) => bookNotifier.setPitch(v),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _testSpeak,
              icon: const Icon(Icons.play_arrow),
              label: const Text('试听当前设置'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVoicePicker(BookSettingsNotifier notifier, String? currentVoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择发音人', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _voices.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return RadioListTile<String?>(
                      title: const Text('系统默认（回退全局）'),
                      value: null,
                      groupValue: currentVoice,
                      onChanged: (v) {
                        notifier.setVoice(v);
                        Navigator.pop(ctx);
                      },
                    );
                  }
                  final voice = _voices[i - 1];
                  final name = voice['name'] ?? '';
                  final locale = voice['locale'] ?? '';
                  return RadioListTile<String?>(
                    title: Text(name),
                    subtitle: locale.isNotEmpty ? Text(locale) : null,
                    value: name,
                    groupValue: currentVoice,
                    onChanged: (v) {
                      notifier.setVoice(v);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testSpeak() async {
    final bookSettings = ref.read(bookSettingsProvider(widget.bookId));
    final globalSettings = ref.read(settingsProvider);
    final effectiveSpeed = bookSettings?.speed ?? globalSettings.defaultSpeed;
    final effectivePitch = bookSettings?.pitch ?? globalSettings.defaultPitch;
    final effectiveVoice = bookSettings?.voice ?? globalSettings.defaultVoice;

    final tts = TtsService.instance;
    await tts.stop();
    if (effectiveVoice != null) {
      await tts.tts.setVoice({'name': effectiveVoice, 'locale': effectiveVoice});
    }
    await tts.tts.setSpeechRate(effectiveSpeed);
    await tts.tts.setPitch(effectivePitch);
    await tts.speak(
      text: '这是本书专属设置的试听效果。',
      bookId: widget.bookId,
      chapterId: -1,
      chapterCharStart: 0,
    );
  }
}

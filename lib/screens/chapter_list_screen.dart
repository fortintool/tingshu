import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/reading_progress.dart';
import '../database/database_helper.dart';
import '../services/audio_handler.dart';
import '../providers/audio_handler_provider.dart';

class ChapterListScreen extends ConsumerStatefulWidget {
  final Book book;
  const ChapterListScreen({super.key, required this.book});

  @override
  ConsumerState<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends ConsumerState<ChapterListScreen> {
  List<Chapter> _chapters = [];
  ReadingProgress? _progress;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final chapters = await db.getChaptersByBook(widget.book.id!);
    final progress = await db.getProgress(widget.book.id!);
    if (mounted) {
      setState(() {
        _chapters = chapters;
        _progress = progress;
        _loading = false;
      });
    }
  }

  Future<void> _selectChapter(Chapter chapter) async {
    final handler = ref.read(audioHandlerProvider);
    await handler.playChapter(
      book: widget.book,
      chapter: chapter,
      startOffset: 0,
    );
    handler.onPlaybackStart();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.book.title} - 章节列表')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chapters.isEmpty
              ? const Center(child: Text('暂无章节'))
              : ListView.builder(
                  itemCount: _chapters.length,
                  itemBuilder: (_, index) {
                    final chapter = _chapters[index];
                    final isCurrent = _progress?.chapterId == chapter.id;

                    return ListTile(
                      title: Text(
                        chapter.title ?? '第${index + 1}章',
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text('${chapter.charEnd - chapter.charStart} 字'),
                      trailing: isCurrent
                          ? Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () => _selectChapter(chapter),
                    );
                  },
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../providers/bookshelf_provider.dart';
import '../providers/settings_provider.dart';
import '../services/book_parser.dart';
import '../services/share_import_service.dart';
import '../widgets/book_cover.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

class BookshelfScreen extends ConsumerStatefulWidget {
  const BookshelfScreen({super.key});

  @override
  ConsumerState<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends ConsumerState<BookshelfScreen> {
  bool _initialized = false;
  final _shareService = ShareImportService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        ref.read(bookshelfProvider.notifier).load();
      }
    });

    _shareService.listen(
      onImported: (bookId) {
        ref.read(bookshelfProvider.notifier).load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('通过分享导入成功')),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _shareService.dispose();
    super.dispose();
  }

  Future<void> _importBook() async {
    try {
      final id = await BookParser.instance.importBook();
      if (id == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导入失败或未选择文件')),
          );
        }
        return;
      }
      await ref.read(bookshelfProvider.notifier).load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入成功')),
        );
      }
    } catch (e) {
      debugPrint('_importBook error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入出错: $e')),
        );
      }
    }
  }

  void _openBook(Book book) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(book: book)),
    );
  }

  Future<void> _toggleTheme() async {
    final current = ref.read(settingsProvider).themeMode;
    final next = current == 'dark' ? 'light' : 'dark';
    await ref.read(settingsProvider.notifier).setThemeMode(next);
  }

  Future<void> _renameBook(Book book) async {
    final controller = TextEditingController(text: book.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新书名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty && newTitle != book.title) {
      await ref.read(bookshelfProvider.notifier).renameBook(book.id!, newTitle);
    }
  }

  Future<void> _deleteBook(Book book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除书籍'),
        content: Text('确定要删除「${book.title}」吗？\n相关章节与进度也会一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(bookshelfProvider.notifier).deleteBook(book.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookshelfProvider);
    final notifier = ref.read(bookshelfProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          PopupMenuButton<BookSortMode>(
            tooltip: '排序',
            icon: const Icon(Icons.sort),
            initialValue: notifier.sortMode,
            onSelected: (m) => notifier.setSortMode(m),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: BookSortMode.lastRead,
                child: Text('按最近阅读'),
              ),
              PopupMenuItem(
                value: BookSortMode.title,
                child: Text('按书名'),
              ),
            ],
          ),
          IconButton(
            tooltip: isDark ? '切换到浅色模式' : '切换到深色模式',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
          ),
          IconButton(
            tooltip: '导入书籍',
            icon: const Icon(Icons.add),
            onPressed: _importBook,
          ),
          IconButton(
            tooltip: '播放设置',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (booksWithProgress) {
          if (booksWithProgress.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('书架为空', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('点击右上角 + 导入书籍', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: booksWithProgress.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final item = booksWithProgress[i];
              return _BookTile(
                book: item.book,
                progressPercent: item.progressPercent,
                onTap: () => _openBook(item.book),
                onLongPress: () => _showBookMenu(item.book),
              );
            },
          );
        },
      ),
    );
  }

  void _showBookMenu(Book book) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _renameBook(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteBook(book);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final Book book;
  final double progressPercent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _BookTile({
    required this.book,
    required this.progressPercent,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final lastRead = book.lastReadAt;
    final lastReadStr = lastRead == null
        ? '尚未阅读'
        : '最近阅读：${_formatTime(lastRead)}';
    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              BookCover(book: book),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          book.fileType.toUpperCase(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (book.author != null && book.author!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Text('·'),
                          const SizedBox(width: 8),
                          Text(
                            book.author!,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (progressPercent > 0)
                      Column(
                        children: [
                          LinearProgressIndicator(
                            value: progressPercent / 100,
                            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 2),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${progressPercent.toStringAsFixed(1)}%',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    if (progressPercent <= 0)
                      Text(
                        lastReadStr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

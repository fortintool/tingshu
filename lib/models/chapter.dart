class Chapter {
  final int? id;
  final int bookId;
  final String? title;
  final String content;
  final int charStart;
  final int charEnd;
  final int chapterIndex;
  final int createdAt;

  const Chapter({
    this.id,
    required this.bookId,
    this.title,
    required this.content,
    required this.charStart,
    required this.charEnd,
    required this.chapterIndex,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'title': title,
      'content': content,
      'charStart': charStart,
      'charEnd': charEnd,
      'chapterIndex': chapterIndex,
      'createdAt': createdAt,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'] as int?,
      bookId: map['bookId'] as int,
      title: map['title'] as String?,
      content: map['content'] as String,
      charStart: map['charStart'] as int,
      charEnd: map['charEnd'] as int,
      chapterIndex: map['chapterIndex'] as int,
      createdAt: map['createdAt'] as int,
    );
  }
}

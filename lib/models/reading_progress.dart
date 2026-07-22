class ReadingProgress {
  final int? id;
  final int bookId;
  final int chapterId;
  final int charPosition;
  final int totalListenedMs;
  final int updatedAt;

  const ReadingProgress({
    this.id,
    required this.bookId,
    required this.chapterId,
    required this.charPosition,
    this.totalListenedMs = 0,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'chapterId': chapterId,
      'charPosition': charPosition,
      'totalListenedMs': totalListenedMs,
      'updatedAt': updatedAt,
    };
  }

  factory ReadingProgress.fromMap(Map<String, dynamic> map) {
    return ReadingProgress(
      id: map['id'] as int?,
      bookId: map['bookId'] as int,
      chapterId: map['chapterId'] as int,
      charPosition: map['charPosition'] as int,
      totalListenedMs: map['totalListenedMs'] as int? ?? 0,
      updatedAt: map['updatedAt'] as int,
    );
  }

  ReadingProgress copyWith({
    int? id,
    int? bookId,
    int? chapterId,
    int? charPosition,
    int? totalListenedMs,
    int? updatedAt,
  }) {
    return ReadingProgress(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      charPosition: charPosition ?? this.charPosition,
      totalListenedMs: totalListenedMs ?? this.totalListenedMs,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

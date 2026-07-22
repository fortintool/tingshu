class Book {
  final int? id;
  final String title;
  final String? author;
  final String? coverPath;
  final String filePath;
  final String fileType;
  final int totalChars;
  final int createdAt;
  final int updatedAt;
  final int? lastReadAt;
  final int sortOrder;

  const Book({
    this.id,
    required this.title,
    this.author,
    this.coverPath,
    required this.filePath,
    required this.fileType,
    this.totalChars = 0,
    required this.createdAt,
    required this.updatedAt,
    this.lastReadAt,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'coverPath': coverPath,
      'filePath': filePath,
      'fileType': fileType,
      'totalChars': totalChars,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastReadAt': lastReadAt,
      'sortOrder': sortOrder,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as int?,
      title: map['title'] as String,
      author: map['author'] as String?,
      coverPath: map['coverPath'] as String?,
      filePath: map['filePath'] as String,
      fileType: map['fileType'] as String,
      totalChars: map['totalChars'] as int? ?? 0,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
      lastReadAt: map['lastReadAt'] as int?,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? coverPath,
    String? filePath,
    String? fileType,
    int? totalChars,
    int? createdAt,
    int? updatedAt,
    int? lastReadAt,
    int? sortOrder,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      totalChars: totalChars ?? this.totalChars,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

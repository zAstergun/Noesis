import 'dart:convert';

class StudyLink {
  final String id;
  final String url;
  final String title;
  final bool isImage;
  final DateTime addedAt;

  StudyLink({
    required this.id,
    required this.url,
    required this.title,
    this.isImage = false,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  static bool detectIfImageUrl(String url) {
    final clean = url.trim().toLowerCase();
    return clean.endsWith('.png') ||
        clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.gif') ||
        clean.endsWith('.svg') ||
        clean.contains('images.unsplash.com') ||
        clean.contains('imgur.com') ||
        clean.contains('wikimedia.org') ||
        clean.contains('/image') ||
        clean.contains('format=jpg') ||
        clean.contains('format=png');
  }

  StudyLink copyWith({
    String? id,
    String? url,
    String? title,
    bool? isImage,
    DateTime? addedAt,
  }) {
    return StudyLink(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      isImage: isImage ?? this.isImage,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'is_image': isImage,
      'added_at': addedAt.toIso8601String(),
    };
  }

  factory StudyLink.fromMap(Map<String, dynamic> map) {
    final urlStr = map['url']?.toString() ?? '';
    final isImg = map['is_image'] == true || detectIfImageUrl(urlStr);
    return StudyLink(
      id: map['id']?.toString() ?? 'link-${DateTime.now().millisecondsSinceEpoch}',
      url: urlStr,
      title: map['title']?.toString() ?? (isImg ? 'Imagem Anexada' : 'Link de Estudo'),
      isImage: isImg,
      addedAt: map['added_at'] != null ? DateTime.tryParse(map['added_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory StudyLink.fromJson(String source) => StudyLink.fromMap(jsonDecode(source));
}

class StudyNote {
  final String id;
  final String notebookId;
  final String title;
  final String content;
  final List<StudyLink> links;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyNote({
    required this.id,
    required this.notebookId,
    required this.title,
    required this.content,
    List<StudyLink>? links,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : links = links ?? [],
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Extrai todas as imagens vinculadas (tanto da lista de links quanto em tags markdown ![alt](url))
  List<String> get allImageUrls {
    final urls = <String>{};

    // Imagens da lista de links
    for (final l in links) {
      if (l.isImage && l.url.trim().isNotEmpty) {
        urls.add(l.url.trim());
      }
    }

    // Imagens encontradas no Markdown: ![qualquer coisa](url)
    final mdImageRegex = RegExp(r'!\[.*?\]\((https?://[^\s\)]+)\)');
    final matches = mdImageRegex.allMatches(content);
    for (final m in matches) {
      final u = m.group(1);
      if (u != null && u.trim().isNotEmpty) {
        urls.add(u.trim());
      }
    }

    return urls.toList();
  }

  /// Links gerais que não são puramente imagens
  List<StudyLink> get generalLinks {
    return links.where((l) => !l.isImage).toList();
  }

  StudyNote copyWith({
    String? id,
    String? notebookId,
    String? title,
    String? content,
    List<StudyLink>? links,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyNote(
      id: id ?? this.id,
      notebookId: notebookId ?? this.notebookId,
      title: title ?? this.title,
      content: content ?? this.content,
      links: links ?? this.links,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'notebook_id': notebookId,
      'title': title,
      'content': content,
      'links': links.map((x) => x.toMap()).toList(),
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StudyNote.fromMap(Map<String, dynamic> map) {
    return StudyNote(
      id: map['id']?.toString() ?? 'note-${DateTime.now().millisecondsSinceEpoch}',
      notebookId: map['notebook_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Sem título',
      content: map['content']?.toString() ?? '',
      links: map['links'] is List
          ? (map['links'] as List).map((x) => StudyLink.fromMap(Map<String, dynamic>.from(x))).toList()
          : [],
      tags: map['tags'] is List ? List<String>.from(map['tags']) : [],
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory StudyNote.fromJson(String source) => StudyNote.fromMap(jsonDecode(source));
}

class StudyNotebook {
  final String id;
  final String title;
  final String subject;
  final String description;
  final String colorHex;
  final int iconCode;
  final List<StudyNote> notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyNotebook({
    required this.id,
    required this.title,
    required this.subject,
    this.description = '',
    this.colorHex = '7C6CF0',
    this.iconCode = 0xe3e6, // Icons.menu_book_rounded
    List<StudyNote>? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : notes = notes ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get noteCount => notes.length;

  int get totalLinksCount {
    int count = 0;
    for (final n in notes) {
      count += n.links.length;
    }
    return count;
  }

  int get totalImagesCount {
    int count = 0;
    for (final n in notes) {
      count += n.allImageUrls.length;
    }
    return count;
  }

  StudyNotebook copyWith({
    String? id,
    String? title,
    String? subject,
    String? description,
    String? colorHex,
    int? iconCode,
    List<StudyNote>? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyNotebook(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      iconCode: iconCode ?? this.iconCode,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'description': description,
      'color_hex': colorHex,
      'icon_code': iconCode,
      'notes': notes.map((x) => x.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StudyNotebook.fromMap(Map<String, dynamic> map) {
    final notebookId = map['id']?.toString() ?? 'nb-${DateTime.now().millisecondsSinceEpoch}';
    return StudyNotebook(
      id: notebookId,
      title: map['title']?.toString() ?? 'Novo Caderno',
      subject: map['subject']?.toString() ?? 'Geral',
      description: map['description']?.toString() ?? '',
      colorHex: map['color_hex']?.toString() ?? '7C6CF0',
      iconCode: map['icon_code'] is int ? map['icon_code'] as int : 0xe3e6,
      notes: map['notes'] is List
          ? (map['notes'] as List).map((x) => StudyNote.fromMap(Map<String, dynamic>.from(x))).toList()
          : [],
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory StudyNotebook.fromJson(String source) => StudyNotebook.fromMap(jsonDecode(source));
}

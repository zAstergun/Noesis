import 'dart:convert';

class Flashcard {
  final String id;
  final String front;
  final String back;
  final List<String> tags;
  String difficulty; // 'easy' | 'good' | 'hard' | 'unreviewed'
  int reviewCount;
  DateTime? lastReviewed;
  final String? audioUrl; // Legacy ou áudio geral
  final String? frontAudioUrl; // Áudio específico da Frente / Pergunta
  final String? backAudioUrl; // Áudio específico do Verso / Resposta

  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.tags = const [],
    this.difficulty = 'unreviewed',
    this.reviewCount = 0,
    this.lastReviewed,
    this.audioUrl,
    this.frontAudioUrl,
    this.backAudioUrl,
  });

  String? get effectiveFrontAudio => (frontAudioUrl != null && frontAudioUrl!.trim().isNotEmpty)
      ? frontAudioUrl
      : audioUrl;

  String? get effectiveBackAudio => (backAudioUrl != null && backAudioUrl!.trim().isNotEmpty)
      ? backAudioUrl
      : null;

  bool get hasFrontAudio => effectiveFrontAudio != null && effectiveFrontAudio!.trim().isNotEmpty;
  bool get hasBackAudio => effectiveBackAudio != null && effectiveBackAudio!.trim().isNotEmpty;
  bool get hasAudio => hasFrontAudio || hasBackAudio;

  String? audioForSide(bool isFront) => isFront ? effectiveFrontAudio : effectiveBackAudio;
  bool hasAudioForSide(bool isFront) => isFront ? hasFrontAudio : hasBackAudio;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'front': front,
      'back': back,
      'tags': tags,
      'difficulty': difficulty,
      'review_count': reviewCount,
      'last_reviewed': lastReviewed?.toIso8601String(),
      'audio_url': audioUrl ?? frontAudioUrl,
      'front_audio_url': frontAudioUrl ?? audioUrl,
      'back_audio_url': backAudioUrl,
    };
  }

  factory Flashcard.fromMap(Map<String, dynamic> map) {
    final legacyAudio = map['audio_url']?.toString();
    final fAudio = map['front_audio_url']?.toString() ?? legacyAudio;
    final bAudio = map['back_audio_url']?.toString();
    return Flashcard(
      id: map['id']?.toString() ?? 'card-${DateTime.now().millisecondsSinceEpoch}',
      front: map['front']?.toString() ?? '',
      back: map['back']?.toString() ?? '',
      tags: map['tags'] is List ? List<String>.from(map['tags']) : const [],
      difficulty: map['difficulty']?.toString() ?? 'unreviewed',
      reviewCount: (map['review_count'] as num?)?.toInt() ?? 0,
      lastReviewed: map['last_reviewed'] != null ? DateTime.tryParse(map['last_reviewed'].toString()) : null,
      audioUrl: legacyAudio,
      frontAudioUrl: fAudio,
      backAudioUrl: bAudio,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory Flashcard.fromJson(String source) => Flashcard.fromMap(jsonDecode(source));

  Flashcard copyWith({
    String? id,
    String? front,
    String? back,
    List<String>? tags,
    String? difficulty,
    int? reviewCount,
    DateTime? lastReviewed,
    String? audioUrl,
    String? frontAudioUrl,
    String? backAudioUrl,
    bool clearAudio = false,
    bool clearFrontAudio = false,
    bool clearBackAudio = false,
  }) {
    return Flashcard(
      id: id ?? this.id,
      front: front ?? this.front,
      back: back ?? this.back,
      tags: tags ?? this.tags,
      difficulty: difficulty ?? this.difficulty,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      audioUrl: clearAudio ? null : (audioUrl ?? this.audioUrl),
      frontAudioUrl: (clearAudio || clearFrontAudio) ? null : (frontAudioUrl ?? this.frontAudioUrl),
      backAudioUrl: (clearAudio || clearBackAudio) ? null : (backAudioUrl ?? this.backAudioUrl),
    );
  }
}

class FlashcardDeck {
  final String id;
  final String title;
  final String subject;
  final String description;
  final List<Flashcard> cards;
  final DateTime createdAt;
  final String colorHex;
  final int iconCode;

  FlashcardDeck({
    required this.id,
    required this.title,
    required this.subject,
    required this.description,
    required this.cards,
    required this.createdAt,
    this.colorHex = '7C6CF0', // Lavanda padrão
    this.iconCode = 0xe5e1, // Icons.style_rounded
  });

  int get cardCount => cards.length;
  int get masteredCount => cards.where((c) => c.difficulty == 'easy').length;
  int get goodCount => cards.where((c) => c.difficulty == 'good').length;
  int get hardCount => cards.where((c) => c.difficulty == 'hard').length;
  int get unreviewedCount => cards.where((c) => c.difficulty == 'unreviewed').length;

  double get progressPercentage {
    if (cards.isEmpty) return 0.0;
    // Ponderação: easy = 100%, good = 65%, hard = 25%
    double score = 0;
    for (final card in cards) {
      if (card.difficulty == 'easy') {
        score += 1.0;
      } else if (card.difficulty == 'good') {
        score += 0.65;
      } else if (card.difficulty == 'hard') {
        score += 0.25;
      }
    }
    return (score / cards.length).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'description': description,
      'cards': cards.map((c) => c.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
      'color_hex': colorHex,
      'icon_code': iconCode,
    };
  }

  factory FlashcardDeck.fromMap(Map<String, dynamic> map) {
    var rawCards = map['cards'];
    List<Flashcard> parsedCards = [];
    if (rawCards is List) {
      parsedCards = rawCards.map((c) => Flashcard.fromMap(Map<String, dynamic>.from(c))).toList();
    } else if (rawCards is String) {
      try {
        final decoded = jsonDecode(rawCards);
        if (decoded is List) {
          parsedCards = decoded.map((c) => Flashcard.fromMap(Map<String, dynamic>.from(c))).toList();
        }
      } catch (_) {}
    }

    return FlashcardDeck(
      id: map['id']?.toString() ?? 'deck-${DateTime.now().millisecondsSinceEpoch}',
      title: map['title']?.toString() ?? 'Novo Baralho',
      subject: map['subject']?.toString() ?? 'Geral',
      description: map['description']?.toString() ?? '',
      cards: parsedCards,
      createdAt: map['created_at'] != null ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
      colorHex: map['color_hex']?.toString() ?? '7C6CF0',
      iconCode: (map['icon_code'] as num?)?.toInt() ?? 0xe5e1,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory FlashcardDeck.fromJson(String source) => FlashcardDeck.fromMap(jsonDecode(source));

  FlashcardDeck copyWith({
    String? id,
    String? title,
    String? subject,
    String? description,
    List<Flashcard>? cards,
    DateTime? createdAt,
    String? colorHex,
    int? iconCode,
  }) {
    return FlashcardDeck(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      cards: cards ?? this.cards,
      createdAt: createdAt ?? this.createdAt,
      colorHex: colorHex ?? this.colorHex,
      iconCode: iconCode ?? this.iconCode,
    );
  }
}

import '../../../core/localization/noesis_l10n.dart';

enum RoadmapStepStatus {
  todo,
  doing,
  done;

  String get label {
    switch (this) {
      case RoadmapStepStatus.todo:
        return NoesisL10n.tr('A fazer');
      case RoadmapStepStatus.doing:
        return NoesisL10n.tr('Em andamento');
      case RoadmapStepStatus.done:
        return NoesisL10n.tr('Concluída');
    }
  }

  String get localizedLabel => label;

  static RoadmapStepStatus fromString(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    if (normalized == 'done' ||
        normalized == 'concluida' ||
        normalized == NoesisL10n.tr('Concluída', null, 'br').toLowerCase() ||
        normalized == NoesisL10n.tr('Concluída').toLowerCase()) {
      return RoadmapStepStatus.done;
    }
    if (normalized == 'doing' ||
        normalized == NoesisL10n.tr('Em andamento', null, 'br').toLowerCase() ||
        normalized == NoesisL10n.tr('Em andamento').toLowerCase()) {
      return RoadmapStepStatus.doing;
    }
    return RoadmapStepStatus.todo;
  }
}

class RoadmapSubtopic {
  const RoadmapSubtopic({
    required this.id,
    required this.title,
    this.done = false,
  });

  final String id;
  final String title;
  final bool done;

  RoadmapSubtopic copyWith({String? id, String? title, bool? done}) {
    return RoadmapSubtopic(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
      };

  factory RoadmapSubtopic.fromJson(Map<String, dynamic> json, {int fallbackIndex = 0}) {
    return RoadmapSubtopic(
      id: (json['id'] ?? 'sub-$fallbackIndex').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      done: json['done'] == true,
    );
  }
}

class RoadmapStep {
  const RoadmapStep({
    required this.id,
    required this.title,
    this.description = '',
    this.estimatedHours = 4,
    this.status = RoadmapStepStatus.todo,
    this.learningObjectives = const [],
    this.keyTopics = const [],
    this.practicalMilestone = '',
    this.subtopics = const [],
    this.resources = const [],
  });

  final String id;
  final String title;
  final String description;
  final int estimatedHours;
  final RoadmapStepStatus status;
  final List<String> learningObjectives;
  final List<String> keyTopics;
  final String practicalMilestone;
  final List<RoadmapSubtopic> subtopics;
  final List<String> resources;

  int get completedSubtopicsCount => subtopics.where((s) => s.done).length;

  RoadmapStep copyWith({
    String? id,
    String? title,
    String? description,
    int? estimatedHours,
    RoadmapStepStatus? status,
    List<String>? learningObjectives,
    List<String>? keyTopics,
    String? practicalMilestone,
    List<RoadmapSubtopic>? subtopics,
    List<String>? resources,
  }) {
    return RoadmapStep(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      status: status ?? this.status,
      learningObjectives: learningObjectives ?? this.learningObjectives,
      keyTopics: keyTopics ?? this.keyTopics,
      practicalMilestone: practicalMilestone ?? this.practicalMilestone,
      subtopics: subtopics ?? this.subtopics,
      resources: resources ?? this.resources,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'estimated_hours': estimatedHours,
        'status': status.name,
        'learning_objectives': learningObjectives,
        'key_topics': keyTopics,
        'practical_milestone': practicalMilestone,
        'subtopics': subtopics.map((s) => s.toJson()).toList(),
        'resources': resources,
      };

  factory RoadmapStep.fromJson(Map<String, dynamic> json, {int fallbackIndex = 0}) {
    final rawSubs = (json['subtopics'] as List? ?? const []);
    final subs = <RoadmapSubtopic>[];
    for (int i = 0; i < rawSubs.length; i++) {
      final item = rawSubs[i];
      if (item is Map) {
        subs.add(RoadmapSubtopic.fromJson(Map<String, dynamic>.from(item), fallbackIndex: i));
      } else if (item != null && item.toString().trim().isNotEmpty) {
        subs.add(RoadmapSubtopic(id: 'sub-$fallbackIndex-$i', title: item.toString().trim()));
      }
    }

    final rawRes = (json['resources'] as List? ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final rawObj = (json['learning_objectives'] ?? json['learningObjectives'] ?? const <dynamic>[]) as List? ?? const [];
    final objectives = rawObj.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();

    final rawTopics = (json['key_topics'] ?? json['keyTopics'] ?? const <dynamic>[]) as List? ?? const [];
    final topics = rawTopics.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();

    return RoadmapStep(
      id: (json['id'] ?? 'step-$fallbackIndex-${DateTime.now().millisecondsSinceEpoch}').toString(),
      title: (json['title'] ?? NoesisL10n.tr('Etapa {n}', {'n': fallbackIndex + 1})).toString(),
      description: (json['description'] ?? '').toString(),
      estimatedHours: ((json['estimated_hours'] ?? json['estimatedHours']) as num?)?.toInt() ?? 4,
      status: RoadmapStepStatus.fromString(json['status']?.toString()),
      learningObjectives: objectives,
      keyTopics: topics,
      practicalMilestone: (json['practical_milestone'] ?? json['practicalMilestone'] ?? '').toString(),
      subtopics: subs,
      resources: rawRes,
    );
  }
}

class StudyRoadmap {
  const StudyRoadmap({
    required this.id,
    required this.title,
    this.goal = '',
    required this.subject,
    this.level = NoesisL10n.defaultRoadmapLevel,
    this.estimatedWeeks = 4,
    this.steps = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String goal;
  final String subject;
  final String level;
  final int estimatedWeeks;
  final List<RoadmapStep> steps;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalSteps => steps.length;
  int get completedSteps => steps.where((s) => s.status == RoadmapStepStatus.done).length;
  int get totalEstimatedHours => steps.fold<int>(0, (acc, s) => acc + s.estimatedHours);

  double get progress {
    if (steps.isEmpty) return 0.0;
    double scoreSum = 0;
    for (final step in steps) {
      if (step.status == RoadmapStepStatus.done) {
        scoreSum += 1.0;
      } else if (step.subtopics.isNotEmpty) {
        scoreSum += step.completedSubtopicsCount / step.subtopics.length;
      } else if (step.status == RoadmapStepStatus.doing) {
        scoreSum += 0.4;
      }
    }
    return (scoreSum / steps.length).clamp(0.0, 1.0);
  }

  StudyRoadmap copyWith({
    String? id,
    String? title,
    String? goal,
    String? subject,
    String? level,
    int? estimatedWeeks,
    List<RoadmapStep>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyRoadmap(
      id: id ?? this.id,
      title: title ?? this.title,
      goal: goal ?? this.goal,
      subject: subject ?? this.subject,
      level: level ?? this.level,
      estimatedWeeks: estimatedWeeks ?? this.estimatedWeeks,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'goal': goal,
        'subject': subject,
        'level': level,
        'estimated_weeks': estimatedWeeks,
        'steps': steps.map((s) => s.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory StudyRoadmap.fromJson(Map<String, dynamic> json) {
    final rawSteps = (json['steps'] as List? ?? const []);
    final parsedSteps = <RoadmapStep>[];
    for (int i = 0; i < rawSteps.length; i++) {
      final item = rawSteps[i];
      if (item is Map) {
        parsedSteps.add(RoadmapStep.fromJson(Map<String, dynamic>.from(item), fallbackIndex: i));
      }
    }

    return StudyRoadmap(
      id: (json['roadmap_key'] ?? json['id'] ?? 'roadmap-${DateTime.now().millisecondsSinceEpoch}').toString(),
      title: (json['title'] ?? NoesisL10n.tr('Trilha de Estudos')).toString(),
      goal: (json['goal'] ?? '').toString(),
      subject: (json['subject'] ?? NoesisL10n.tr('Geral')).toString(),
      level: (json['level'] ?? NoesisL10n.tr('Intermediário')).toString(),
      estimatedWeeks: ((json['estimated_weeks'] ?? json['estimatedWeeks']) as num?)?.toInt() ?? 4,
      steps: parsedSteps,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

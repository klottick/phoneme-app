import 'package:linguist/src/core/course/lesson_policy.dart';

/// Phase of a discovery listening section attempt.
enum LessonSectionPhase { exercise, debrief }

/// Serialization format version written by [LessonSectionSession.toJson] and
/// accepted by [LessonSectionSession.fromJson].
const int kLessonSectionSessionVersion = 1;

/// Pure validated state of one discovery listening section session.
///
/// State machine:
/// - In [LessonSectionPhase.exercise], [submit] records the latest outcome
///   for the current ([currentItemId]) item once per round, and [advance]
///   moves to the next queued item. Advancing past the last item enters
///   [LessonSectionPhase.debrief].
/// - In [LessonSectionPhase.debrief], [reviewMistakes] starts the next round
///   with only the items whose latest outcome is not correct, in original
///   item order, and returns to the debrief when that round ends.
///
/// Retries replace an item's latest outcome for completion ([correctCount],
/// [canComplete]) while [attemptCount] retains the aggregate attempts.
/// Invalid state transitions throw [StateError]; restoring a corrupt or
/// incompatible serialized snapshot throws [FormatException] without a partial
/// restore. Exposed collections are unmodifiable views: callers cannot
/// corrupt the session state.
class LessonSectionSession {
  /// Starts a fresh first pass over [itemIds].
  ///
  /// Copies and validates [itemIds] (nonempty, unique, nonempty IDs) and
  /// [sessionId] (nonempty); [contentRevision] must be positive and
  /// [policy] defaults to [LessonPolicy] (80%). Misuse throws
  /// [ArgumentError].
  factory LessonSectionSession({
    required List<String> itemIds,
    required String sessionId,
    int contentRevision = 1,
    LessonPolicy? policy,
  }) {
    final ids = _validatedItemIds('itemIds', itemIds);
    return LessonSectionSession._(
      itemIds: ids,
      sessionId: _validatedNonempty('sessionId', sessionId),
      contentRevision: _validatedRevision(contentRevision),
      policy: policy ?? LessonPolicy(),
      queue: ids,
      position: 0,
      round: 1,
      attemptCount: 0,
      phase: LessonSectionPhase.exercise,
      submittedThisRound: const <String>[],
      lastCorrect: null,
      latestAnswers: const <String, bool>{},
    );
  }

  /// Restores a snapshot written by [toJson].
  ///
  /// [itemIds] and [contentRevision] describe the section content the
  /// snapshot is being restored for. The snapshot must be compatible with
  /// them; the saved [LessonPolicy] is authoritative on resume, not a new
  /// default. Any unknown key type, corrupted value, or inconsistent
  /// combination (version, IDs, queue, position, counts, outcomes, phase)
  /// throws [FormatException] and nothing is restored.
  factory LessonSectionSession.fromJson(
    Map<String, dynamic> json, {
    required List<String> itemIds,
    required int contentRevision,
  }) {
    final version = _strictInt(json, 'version');
    if (version != kLessonSectionSessionVersion) {
      throw FormatException(
          'Unsupported session version $version '
          '(expected $kLessonSectionSessionVersion).',
          json);
    }

    final sessionId = json['sessionId'];
    if (sessionId is! String || sessionId.isEmpty) {
      throw FormatException('sessionId must be a nonempty string, found: '
          '$sessionId', json);
    }

    final savedRevision = _strictInt(json, 'contentRevision');
    if (savedRevision < 1) {
      throw FormatException(
          'contentRevision must be positive, found: $savedRevision',
          json);
    }
    if (savedRevision != contentRevision) {
      throw FormatException(
          'Saved contentRevision $savedRevision does not match the section '
          'contentRevision $contentRevision.',
          json);
    }

    final provided = _validatedItemIds('itemIds (section content)', itemIds);
    final savedIds = _uniqueIdList(json, 'itemIds');
    var idsMatch = savedIds.length == provided.length;
    if (idsMatch) {
      for (var i = 0; i < provided.length; i++) {
        if (savedIds[i] != provided[i]) {
          idsMatch = false;
          break;
        }
      }
    }
    if (!idsMatch) {
      throw FormatException('itemIds do not match the section content.', json);
    }
    final idSet = provided.toSet();

    final queue = _uniqueIdList(json, 'queue');
    if (queue.isEmpty) {
      throw FormatException('queue must contain the round items.', json);
    }
    for (final id in queue) {
      if (!idSet.contains(id)) {
        throw FormatException('queue contains an unknown item id: $id', json);
      }
    }
    final queueSet = queue.toSet();

    final submitted = _uniqueIdList(json, 'submittedThisRound');
    for (final id in submitted) {
      if (!queueSet.contains(id)) {
        throw FormatException(
            'submittedThisRound contains an id outside the queue: $id',
            json);
      }
    }
    final submittedSet = submitted.toSet();

    final position = _strictInt(json, 'position');
    if (position < 0) {
      throw FormatException('position must be >= 0, found: $position', json);
    }
    final round = _strictInt(json, 'round');
    if (round < 1) {
      throw FormatException('round must be >= 1, found: $round', json);
    }
    final attemptCount = _strictInt(json, 'attemptCount');
    if (attemptCount < 0) {
      throw FormatException('attemptCount must be >= 0, found: $attemptCount',
          json);
    }

    final phaseName = json['phase'];
    LessonSectionPhase phase;
    if (phaseName == 'exercise') {
      phase = LessonSectionPhase.exercise;
    } else if (phaseName == 'debrief') {
      phase = LessonSectionPhase.debrief;
    } else {
      throw FormatException(
          'phase must be "exercise" or "debrief", found: $phaseName', json);
    }

    final Object? lastCorrect = json['lastCorrect'];
    if (lastCorrect != null && lastCorrect is! bool) {
      throw FormatException(
          'lastCorrect must be a bool or null, found: $lastCorrect', json);
    }

    final answered = _uniqueIdList(json, 'answered');
    for (final id in answered) {
      if (!idSet.contains(id)) {
        throw FormatException('answered contains an unknown item id: $id', json);
      }
    }

    final Object? latestRaw = json['latestAnswers'];
    if (latestRaw is! Map) {
      throw FormatException('latestAnswers must be a map, found: $latestRaw',
          json);
    }
    if (latestRaw.keys.any((Object? key) => key is! String)) {
      throw FormatException('latestAnswers keys must be nonempty strings.',
          json);
    }
    final Map<String, bool> latestAnswers = <String, bool>{};
    for (final MapEntry<Object?, Object?> entry in latestRaw.entries) {
      final String key = entry.key as String;
      final Object? value = entry.value;
      if (key.isEmpty || !idSet.contains(key)) {
        throw FormatException(
            'latestAnswers contains an unknown item id: $key', json);
      }
      // bool is an int subtype in Dart; accept exact bools only.
      if (value is! bool) {
        throw FormatException('latestAnswers[$key] must be a bool, '
            'found: $value', json);
      }
      latestAnswers[key] = value;
    }
    if (answered.length != latestAnswers.length ||
        !answered.every((id) => latestAnswers.containsKey(id))) {
      throw FormatException(
          'answered and latestAnswers must describe the same items.',
          json);
    }

    final Object? policyRaw = json['policy'];
    if (policyRaw is! Map) {
      throw FormatException('policy must be a map, found: $policyRaw', json);
    }
    if (policyRaw.keys.any((Object? key) => key is! String)) {
      throw FormatException('policy keys must be strings.', json);
    }
    final LessonPolicy policy;
    try {
      policy = LessonPolicy.fromJson(policyRaw.cast<String, dynamic>());
    } on FormatException {
      rethrow;
    }

    // Phase/state invariants.
    if (phase == LessonSectionPhase.exercise) {
      if (position >= queue.length) {
        throw FormatException(
            'position $position has no current item in an exercise queue '
            'of ${queue.length}.',
            json);
      }
      if (submittedSet.difference(queue.sublist(0, position + 1).toSet())
          .isNotEmpty) {
        throw FormatException(
            'submittedThisRound cannot contain items beyond the current '
            'position.',
            json);
      }
      if (queue.sublist(0, position).toSet().difference(submittedSet)
          .isNotEmpty) {
        throw FormatException(
            'submittedThisRound is missing an already passed item.',
            json);
      }
    } else {
      if (position != queue.length) {
        throw FormatException(
            'position must equal the queue length at the debrief, found: '
            '$position.',
            json);
      }
      if (submittedSet.length != queueSet.length ||
          submittedSet.difference(queueSet).isNotEmpty) {
        throw FormatException(
            'submittedThisRound must equal the queue at the debrief.',
            json);
      }
      // Impossible coverage: a completed round answers every queued item.
      if (queueSet.difference(latestAnswers.keys.toSet()).isNotEmpty) {
        throw FormatException(
            'A completed round cannot omit answers for its items.',
            json);
      }
      if (round == 1 &&
          (queueSet.length != idSet.length ||
              queueSet.difference(idSet).isNotEmpty)) {
        throw FormatException(
            'A first-pass debrief must cover every item of the section.',
            json);
      }
    }
    if (attemptCount < answered.length) {
      throw FormatException(
          'attemptCount cannot be lower than the number of answered items.',
          json);
    }
    if (attemptCount < submitted.length) {
      throw FormatException(
          'attemptCount cannot be lower than this round\'s submissions.',
          json);
    }
    if ((attemptCount == 0) != (lastCorrect == null)) {
      throw FormatException(
          'lastCorrect must be set exactly when attempts were recorded.',
          json);
    }

    return LessonSectionSession._(
      itemIds: provided,
      sessionId: sessionId,
      contentRevision: savedRevision,
      policy: policy,
      queue: queue,
      position: position,
      round: round,
      attemptCount: attemptCount,
      phase: phase,
      submittedThisRound: submitted,
      lastCorrect: lastCorrect as bool?,
      latestAnswers: latestAnswers,
    );
  }

  LessonSectionSession._({
    required List<String> itemIds,
    required String sessionId,
    required int contentRevision,
    required LessonPolicy policy,
    required List<String> queue,
    required int position,
    required int round,
    required int attemptCount,
    required LessonSectionPhase phase,
    required List<String> submittedThisRound,
    required bool? lastCorrect,
    required Map<String, bool> latestAnswers,
  })  : _itemIds = List.unmodifiable(itemIds),
        _sessionId = sessionId,
        _contentRevision = contentRevision,
        _policy = policy,
        _queue = List.of(queue),
        _position = position,
        _round = round,
        _attemptCount = attemptCount,
        _phase = phase,
        _submittedThisRound = Set.of(submittedThisRound),
        _lastCorrect = lastCorrect,
        _latestAnswers = Map.of(latestAnswers);

  final List<String> _itemIds;
  final String _sessionId;
  final int _contentRevision;
  final LessonPolicy _policy;
  List<String> _queue;
  int _position;
  int _round;
  int _attemptCount;
  LessonSectionPhase _phase;
  Set<String> _submittedThisRound;
  bool? _lastCorrect;
  Map<String, bool> _latestAnswers;

  /// The section item IDs in original order (unmodifiable).
  List<String> get itemIds => _itemIds;

  /// The current round's item queue in order (unmodifiable).
  List<String> get queue => List.unmodifiable(_queue);

  /// Zero-based index of the current item within [queue].
  int get position => _position;

  /// Current round number; the first pass is round 1.
  int get round => _round;

  /// Total item outcomes recorded across every round so far.
  int get attemptCount => _attemptCount;

  /// Session owner identity; rejected on resume if it changed.
  String get sessionId => _sessionId;

  /// Section content revision this session was started against.
  int get contentRevision => _contentRevision;

  /// The completion policy in force for this session.
  LessonPolicy get policy => _policy;

  /// Current phase: exercise or debrief.
  LessonSectionPhase get phase => _phase;

  /// Item IDs with any recorded outcome (unmodifiable).
  Set<String> get answered => Set.unmodifiable(_latestAnswers.keys);

  /// Last recorded outcome, or null before the first submission.
  bool? get lastCorrect => _lastCorrect;

  /// The item currently being attempted, or null in the debrief.
  String? get currentItemId =>
      _phase == LessonSectionPhase.exercise ? _queue[_position] : null;

  /// Latest outcome per item ID (unmodifiable).
  Map<String, bool> get latestAnswers => Map.unmodifiable(_latestAnswers);

  /// Items whose latest outcome is wrong, in original item order.
  List<String> get unresolvedItemIds => _itemIds
      .where((String id) => _latestAnswers[id] == false)
      .toList(growable: false);

  /// How many items currently have a correct latest outcome.
  int get correctCount =>
      _latestAnswers.values.where((bool value) => value).length;

  /// How many items have at least one recorded outcome.
  int get answeredItemCount => _latestAnswers.length;

  /// Whether this session satisfies the policy and may be completed;
  /// requires the debrief, every item attempted, and the threshold met.
  bool get canComplete =>
      _phase == LessonSectionPhase.debrief &&
      _latestAnswers.length == _itemIds.length &&
      _policy.isPassing(
          correct: correctCount, total: _itemIds.length);

  /// Records the current item's outcome once for the round.
  ///
  /// Throws [StateError] unless the phase is exercise and the current item
  /// has not been submitted this round.
  void submit(bool correct) {
    if (_phase != LessonSectionPhase.exercise) {
      throw StateError('submit() requires the exercise phase.');
    }
    final String id = _queue[_position];
    if (_submittedThisRound.contains(id)) {
      throw StateError('Item $id was already submitted in this round; '
          'use advance().');
    }
    _latestAnswers[id] = correct;
    _submittedThisRound.add(id);
    _attemptCount += 1;
    _lastCorrect = correct;
  }

  /// Moves past the current item, or enters the debrief at round end.
  ///
  /// Throws [StateError] unless the phase is exercise and the current item
  /// has been submitted this round.
  void advance() {
    if (_phase != LessonSectionPhase.exercise) {
      throw StateError('advance() requires the exercise phase.');
    }
    final String id = _queue[_position];
    if (!_submittedThisRound.contains(id)) {
      throw StateError('Item $id must be submitted before advancing.');
    }
    _position += 1;
    if (_position >= _queue.length) {
      _phase = LessonSectionPhase.debrief;
    }
  }

  /// Starts a new review round containing only [unresolvedItemIds], in
  /// original item order.
  ///
  /// Throws [StateError] unless the phase is debrief and at least one item
  /// is unresolved.
  void reviewMistakes() {
    if (_phase != LessonSectionPhase.debrief) {
      throw StateError('reviewMistakes() requires the debrief phase.');
    }
    final List<String> unresolved = unresolvedItemIds;
    if (unresolved.isEmpty) {
      throw StateError('Every item is already resolved; no review needed.');
    }
    _queue = List.of(unresolved);
    _position = 0;
    _round += 1;
    _submittedThisRound = <String>{};
    _phase = LessonSectionPhase.exercise;
  }

  /// Serializes the full session state for saving.
  ///
  /// The round-1 content revision, item IDs, and the saved [LessonPolicy]
  /// travel with the snapshot; [LessonSectionSession.fromJson] uses the
  /// saved policy as authoritative on resume.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': kLessonSectionSessionVersion,
      'sessionId': _sessionId,
      'contentRevision': _contentRevision,
      'itemIds': List.of(_itemIds),
      'queue': List.of(_queue),
      'position': _position,
      'round': _round,
      'attemptCount': _attemptCount,
      'phase': _phase == LessonSectionPhase.exercise
          ? 'exercise'
          : 'debrief',
      'submittedThisRound': List.of(_submittedThisRound),
      'lastCorrect': _lastCorrect,
      'answered': List.of(_latestAnswers.keys),
      'latestAnswers': Map.of(_latestAnswers),
      'policy': _policy.toJson(),
    };
  }

  static int _strictInt(Map<String, dynamic> json, String key) {
    final Object? raw = json[key];
    // bool is an int subtype in Dart; reject it explicitly.
    if (raw is bool || raw is! int) {
      throw FormatException('$key must be an integer, found: $raw', json);
    }
    return raw;
  }

  static String _validatedNonempty(String name, String value) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, name, 'Must be nonempty.');
    }
    return value;
  }

  static int _validatedRevision(int contentRevision) {
    if (contentRevision < 1) {
      throw ArgumentError.value(
          contentRevision, 'contentRevision', 'Must be positive.');
    }
    return contentRevision;
  }

  static List<String> _validatedItemIds(String name, List<String> itemIds) {
    if (itemIds.isEmpty) {
      throw ArgumentError.value(itemIds, name, 'Must contain at least one id.');
    }
    for (final String id in itemIds) {
      if (id.isEmpty) {
        throw ArgumentError.value(id, name, 'Ids must be nonempty.');
      }
    }
    if (itemIds.toSet().length != itemIds.length) {
      throw ArgumentError.value(itemIds, name, 'Ids must be unique.');
    }
    return List.of(itemIds);
  }

  static List<String> _uniqueIdList(Map<String, dynamic> json, String key) {
    final Object? raw = json[key];
    if (raw is! List) {
      throw FormatException('$key must be a list, found: $raw', json);
    }
    final List<String> ids = <String>[];
    final Set<String> seen = <String>{};
    for (final Object? value in raw) {
      if (value is! String || value.isEmpty) {
        throw FormatException(
            '$key must contain nonempty strings, found: $value', json);
      }
      if (!seen.add(value)) {
        throw FormatException('$key contains a duplicate id: $value', json);
      }
      ids.add(value);
    }
    return ids;
  }
}

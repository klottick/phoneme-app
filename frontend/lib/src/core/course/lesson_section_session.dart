import 'package:linguist/src/core/course/lesson_policy.dart';

/// Phase of a discovery listening section attempt.
enum LessonSectionPhase { exercise, debrief }

/// Serialization format version written by [LessonSectionSession.toJson] and
/// accepted by [LessonSectionSession.fromJson].
const int kLessonSectionSessionVersion = 1;

/// Pure validated state of one discovery listening section session.
///
/// State machine:
/// - In [LessonSectionPhase.exercise], [submit] records the latest outcome for
///   the current ([currentItemId]) item once per round, and [advance] moves to
///   the next queued item. Advancing past the last item enters
///   [LessonSectionPhase.debrief].
/// - In [LessonSectionPhase.debrief], [reviewMistakes] starts the next round
///   with only the items whose latest outcome is wrong, in original item
///   order, and returns to the debrief when that round ends.
///
/// Retries replace an item's latest outcome for completion ([correctCount],
/// [canComplete]) while [attemptCount] retains the aggregate attempts.
///
/// `answered` is the current-round submission status for the current exercise
/// item (true only while that item has been submitted this round); it is false
/// for an unsubmitted item and for the debrief. A historical outcome in
/// [latestAnswers] is not a current-round submission. `answeredItemCount` and
/// [latestAnswers] expose aggregate coverage.
///
/// Invalid state transitions throw [StateError]; restoring a corrupt or
/// unreachable serialized snapshot throws [FormatException] without a partial
/// restore. Exposed collections are unmodifiable.
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
  /// default.
  ///
  /// Restoration enforces reachability under the submit/advance/review
  /// transitions, not just field validity: the first-pass queue must equal the
  /// authored ordered item IDs; the submitted set must match the queued prefix
  /// at [position] (including the current item iff answered); first-pass
  /// outcomes and attempt count must exactly match the submitted prefix; review
  /// states require full first-pass coverage, an ordered mistake-only queue,
  /// correct outcomes outside the queue, wrong outcomes for unsubmitted queued
  /// items, and feasible round/attempt counts; and [lastCorrect] must agree
  /// with the most recent identifiable queued submission.
  ///
  /// Any unknown key type, corrupted value, or unreachable state throws
  /// [FormatException] and nothing is restored.
  factory LessonSectionSession.fromJson(
    Map<String, dynamic> json, {
    required List<String> itemIds,
    required int contentRevision,
  }) {
    final version = _strictInt(json, 'version');
    if (version != kLessonSectionSessionVersion) {
      throw FormatException(
          'Unsupported session version $version (expected '
          '$kLessonSectionSessionVersion).',
          json);
    }

    final sessionId = json['sessionId'];
    if (sessionId is! String || sessionId.isEmpty) {
      throw FormatException(
          'sessionId must be a nonempty string, found: '
          '$sessionId',
          json);
    }

    final savedRevision = _strictInt(json, 'contentRevision');
    if (savedRevision < 1) {
      throw FormatException(
          'contentRevision must be positive, found: $savedRevision', json);
    }
    if (savedRevision != contentRevision) {
      throw FormatException(
          'Saved contentRevision $savedRevision does not match the section '
          'contentRevision $contentRevision.',
          json);
    }

    final provided = _validatedItemIds('itemIds (section content)', itemIds);
    final savedIds = _uniqueIdList(json, 'itemIds');
    if (!_sameOrder(provided, savedIds)) {
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
            'submittedThisRound contains an id outside the queue: $id', json);
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
      throw FormatException(
          'attemptCount must be >= 0, found: $attemptCount', json);
    }

    final phaseName = json['phase'];
    final LessonSectionPhase phase;
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
    final Object? answered = json['answered'];
    if (answered is! bool) {
      throw FormatException('answered must be a bool, found: $answered', json);
    }

    final latestAnswers = _validatedLatestAnswers(json, idSet);
    final policy = _validatedPolicy(json);

    // Reachability invariants, enforced under the submit/advance/review
    // machine rather than as independent field checks.
    final n = provided.length;
    final latestSet = latestAnswers.keys.toSet();

    if (round == 1) {
      // The first pass always queues every item, in authored order.
      if (!_sameOrder(provided, queue)) {
        throw FormatException(
            'A first-pass round must queue every item in authored order, '
            'found: $queue.',
            json);
      }
      // A first pass has exactly one outcome per submitted item and none for
      // items not yet reached.
      if (latestSet.length != submittedSet.length ||
          !submittedSet.containsAll(latestSet)) {
        throw FormatException(
            'First-pass outcomes must exactly cover the submitted items '
            '(${submittedSet.length}); found ${latestSet.length}.',
            json);
      }
      if (attemptCount != submitted.length) {
        throw FormatException(
            'First-pass attemptCount must equal the submitted count '
            '(${submitted.length}), found: $attemptCount.',
            json);
      }
    } else {
      // A review round requires every item to have a first-pass outcome.
      if (latestSet.length != n || !idSet.containsAll(latestSet)) {
        throw FormatException(
            'A review round requires full first-pass coverage '
            '($n items); found ${latestSet.length}.',
            json);
      }
      // The review queue holds only unresolved (currently wrong) items in
      // original order: nothing outside the queue may be wrong, and no queued
      // item that has not been re-submitted yet may already be correct.
      var indexInProvided = 0;
      for (final id in queue) {
        while (indexInProvided < provided.length &&
            provided[indexInProvided] != id) {
          indexInProvided += 1;
        }
        if (indexInProvided >= provided.length) {
          throw FormatException(
              'The review queue is not in the original item order: $queue.',
              json);
        }
        indexInProvided += 1;
        if (!submittedSet.contains(id) && latestAnswers[id] != false) {
          throw FormatException(
              'Review-queued item $id is not submitted this round and its '
              'latest outcome is not wrong.',
              json);
        }
      }
      for (final id in provided) {
        if (!queueSet.contains(id) && latestAnswers[id] != true) {
          throw FormatException(
              'Item $id is outside the review queue but its latest outcome '
              'is not correct.',
              json);
        }
      }
      final int min = n + (round - 2) * queue.length + submitted.length;
      final int max = n * (round - 1) + submitted.length;
      if (attemptCount < min || attemptCount > max) {
        throw FormatException(
            'Review attemptCount $attemptCount is infeasible; expected '
            '$min through $max.',
            json);
      }
    }

    if (phase == LessonSectionPhase.exercise) {
      if (position >= queue.length) {
        throw FormatException(
            'position $position has no current item in an exercise queue of '
            '${queue.length}.',
            json);
      }
    } else {
      if (position != queue.length) {
        throw FormatException(
            'position must equal the queue length at the debrief, found: '
            '$position.',
            json);
      }
    }

    // The submitted set must be exactly the ordered queued prefix: the items
    // already passed, plus the current item iff it has been submitted.
    final int expectedCount =
        position + (phase == LessonSectionPhase.exercise && answered ? 1 : 0);
    if (submitted.length != expectedCount) {
      throw FormatException(
          'submittedThisRound has ${submitted.length} entries but '
          '$expectedCount are required at this phase/position.',
          json);
    }
    final List<String> expectedPrefix =
        List.of(queue.sublist(0, expectedCount));
    if (!_sameOrder(expectedPrefix, submitted)) {
      throw FormatException(
          'submittedThisRound must match the ordered queue prefix '
          '$expectedPrefix; found: $submitted.',
          json);
    }
    for (final id in submitted) {
      if (!latestAnswers.containsKey(id)) {
        throw FormatException(
            'Submitted item $id has no outcome in latestAnswers.', json);
      }
    }
    if (phase == LessonSectionPhase.debrief) {
      if (answered) {
        throw FormatException(
            'answered must be false at the debrief, found: $answered.', json);
      }
    }
    if (lastCorrect != null && latestAnswers.isEmpty) {
      throw FormatException(
          'lastCorrect must be null before any outcome is recorded, found: '
          '$lastCorrect.',
          json);
    }

    // lastCorrect must agree with the most recent identifiable submission:
    // the current item when submitted, the preceding queued item after an
    // advance, or the queue's final item at the debrief. A fresh round whose
    // current item is unsubmitted retains the previous round's outcome
    // (or null on a fresh first pass), which cannot be pinned down from the
    // snapshot alone.
    if (phase == LessonSectionPhase.debrief) {
      final bool expectCorrect = latestAnswers[queue[queue.length - 1]]!;
      if (lastCorrect != expectCorrect) {
        throw FormatException(
            'lastCorrect must equal the queue\'s final outcome '
            '($expectCorrect), found: $lastCorrect.',
            json);
      }
    } else if (answered) {
      final bool expectCorrect = latestAnswers[queue[position]]!;
      if (lastCorrect != expectCorrect) {
        throw FormatException(
            'lastCorrect must equal the current item outcome of '
            '${queue[position]} ($expectCorrect), found: $lastCorrect.',
            json);
      }
    } else if (position > 0) {
      final bool expectCorrect = latestAnswers[queue[position - 1]]!;
      if (lastCorrect != expectCorrect) {
        throw FormatException(
            'lastCorrect must equal the preceding queued outcome of '
            '${queue[position - 1]} ($expectCorrect), found: $lastCorrect.',
            json);
      }
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
        _submittedThisRound = List.of(submittedThisRound),
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
  List<String> _submittedThisRound;
  bool? _lastCorrect;
  Map<String, bool> _latestAnswers;

  /// The section item IDs in authored order (unmodifiable).
  List<String> get itemIds => _itemIds;

  /// The current round's item queue in order (unmodifiable).
  List<String> get queue => List.unmodifiable(_queue);

  /// Zero-based index of the current item within [queue].
  int get position => _position;

  /// Current round number; the first pass is round 1.
  int get round => _round;

  /// Total item outcomes recorded across every round so far.
  int get attemptCount => _attemptCount;

  /// Session/attempt identity carried in the snapshot.
  ///
  /// Owner scoping (e.g., which authenticated account a saved attempt belongs
  /// to) is a persistence concern enforced by the store, not by this type.
  String get sessionId => _sessionId;

  /// Section content revision this session was started against.
  int get contentRevision => _contentRevision;

  /// The completion policy in force for this session.
  LessonPolicy get policy => _policy;

  /// Current phase: exercise or debrief.
  LessonSectionPhase get phase => _phase;

  /// True only when the current exercise item has been submitted this round.
  ///
  /// False for an unsubmitted item and for the debrief. A historical outcome
  /// for the item in [latestAnswers] does not make it true.
  bool get answered =>
      _phase == LessonSectionPhase.exercise &&
      _position < _queue.length &&
      _submittedThisRound.contains(_queue[_position]);

  /// Last recorded outcome, or null before the first submission.
  bool? get lastCorrect => _lastCorrect;

  /// The item currently being attempted, or null in the debrief.
  String? get currentItemId =>
      _phase == LessonSectionPhase.exercise ? _queue[_position] : null;

  /// Latest outcome per item ID (unmodifiable).
  Map<String, bool> get latestAnswers => Map.unmodifiable(_latestAnswers);

  /// Items whose latest outcome is wrong, in original item order
  /// (unmodifiable copy).
  List<String> get unresolvedItemIds => List.unmodifiable(
      _itemIds.where((String id) => _latestAnswers[id] == false));

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
      _policy.isPassing(correct: correctCount, total: _itemIds.length);

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
      throw StateError('Item $id was already submitted in this round; use '
          'advance().');
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
    _submittedThisRound = <String>[];
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
      'phase': _phase == LessonSectionPhase.exercise ? 'exercise' : 'debrief',
      'submittedThisRound': List.of(_submittedThisRound),
      'lastCorrect': _lastCorrect,
      'answered': answered,
      'latestAnswers': Map.of(_latestAnswers),
      'policy': _policy.toJson(),
    };
  }

  static bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  static int _strictInt(Map<String, dynamic> json, String key) {
    final Object? raw = json[key];
    if (raw is! int) {
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
      throw ArgumentError.value(
          itemIds, name, 'Must contain at least one item.');
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

  static Map<String, bool> _validatedLatestAnswers(
      Map<String, dynamic> json, Set<String> idSet) {
    final Object? latestRaw = json['latestAnswers'];
    if (latestRaw is! Map) {
      throw FormatException(
          'latestAnswers must be a map, found: $latestRaw', json);
    }
    if (latestRaw.keys.any((Object? key) => key is! String)) {
      throw FormatException(
          'latestAnswers keys must be nonempty strings.', json);
    }
    final Map<String, bool> latestAnswers = <String, bool>{};
    for (final MapEntry<Object?, Object?> entry in latestRaw.entries) {
      final String key = entry.key as String;
      final Object? value = entry.value;
      if (key.isEmpty || !idSet.contains(key)) {
        throw FormatException(
            'latestAnswers contains an unknown item id: $key', json);
      }
      // bool values must be exact bools; reject 1/0, strings, etc.
      if (value is! bool) {
        throw FormatException(
            'latestAnswers[$key] must be a bool, found: $value', json);
      }
      latestAnswers[key] = value;
    }
    return latestAnswers;
  }

  static LessonPolicy _validatedPolicy(Map<String, dynamic> json) {
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
    return policy;
  }
}

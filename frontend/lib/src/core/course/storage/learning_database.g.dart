// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_database.dart';

// ignore_for_file: type=lint
class $LearningScopesTable extends LearningScopes
    with TableInfo<$LearningScopesTable, LearningScope> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningScopesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerKindMeta = const VerificationMeta(
    'ownerKind',
  );
  @override
  late final GeneratedColumn<String> ownerKind = GeneratedColumn<String>(
    'owner_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyMeta = const VerificationMeta('family');
  @override
  late final GeneratedColumn<String> family = GeneratedColumn<String>(
    'family',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commitOrdinalMeta = const VerificationMeta(
    'commitOrdinal',
  );
  @override
  late final GeneratedColumn<int> commitOrdinal = GeneratedColumn<int>(
    'commit_ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _availabilityStateMeta = const VerificationMeta(
    'availabilityState',
  );
  @override
  late final GeneratedColumn<String> availabilityState =
      GeneratedColumn<String>(
        'availability_state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerKind,
    ownerId,
    courseId,
    family,
    schemaVersion,
    revision,
    commitOrdinal,
    availabilityState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_scopes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningScope> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('owner_kind')) {
      context.handle(
        _ownerKindMeta,
        ownerKind.isAcceptableOrUnknown(data['owner_kind']!, _ownerKindMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerKindMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('family')) {
      context.handle(
        _familyMeta,
        family.isAcceptableOrUnknown(data['family']!, _familyMeta),
      );
    } else if (isInserting) {
      context.missing(_familyMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('commit_ordinal')) {
      context.handle(
        _commitOrdinalMeta,
        commitOrdinal.isAcceptableOrUnknown(
          data['commit_ordinal']!,
          _commitOrdinalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commitOrdinalMeta);
    }
    if (data.containsKey('availability_state')) {
      context.handle(
        _availabilityStateMeta,
        availabilityState.isAcceptableOrUnknown(
          data['availability_state']!,
          _availabilityStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_availabilityStateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LearningScope map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningScope(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      ),
      ownerKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_kind'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      family: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      commitOrdinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}commit_ordinal'],
      )!,
      availabilityState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}availability_state'],
      )!,
    );
  }

  @override
  $LearningScopesTable createAlias(String alias) {
    return $LearningScopesTable(attachedDatabase, alias);
  }
}

class LearningScope extends DataClass implements Insertable<LearningScope> {
  final int? id;
  final String ownerKind;
  final String ownerId;
  final String courseId;
  final String family;
  final int schemaVersion;
  final int revision;
  final int commitOrdinal;
  final String availabilityState;
  const LearningScope({
    this.id,
    required this.ownerKind,
    required this.ownerId,
    required this.courseId,
    required this.family,
    required this.schemaVersion,
    required this.revision,
    required this.commitOrdinal,
    required this.availabilityState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<int>(id);
    }
    map['owner_kind'] = Variable<String>(ownerKind);
    map['owner_id'] = Variable<String>(ownerId);
    map['course_id'] = Variable<String>(courseId);
    map['family'] = Variable<String>(family);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['revision'] = Variable<int>(revision);
    map['commit_ordinal'] = Variable<int>(commitOrdinal);
    map['availability_state'] = Variable<String>(availabilityState);
    return map;
  }

  LearningScopesCompanion toCompanion(bool nullToAbsent) {
    return LearningScopesCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      ownerKind: Value(ownerKind),
      ownerId: Value(ownerId),
      courseId: Value(courseId),
      family: Value(family),
      schemaVersion: Value(schemaVersion),
      revision: Value(revision),
      commitOrdinal: Value(commitOrdinal),
      availabilityState: Value(availabilityState),
    );
  }

  factory LearningScope.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningScope(
      id: serializer.fromJson<int?>(json['id']),
      ownerKind: serializer.fromJson<String>(json['ownerKind']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      courseId: serializer.fromJson<String>(json['courseId']),
      family: serializer.fromJson<String>(json['family']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      revision: serializer.fromJson<int>(json['revision']),
      commitOrdinal: serializer.fromJson<int>(json['commitOrdinal']),
      availabilityState: serializer.fromJson<String>(json['availabilityState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int?>(id),
      'ownerKind': serializer.toJson<String>(ownerKind),
      'ownerId': serializer.toJson<String>(ownerId),
      'courseId': serializer.toJson<String>(courseId),
      'family': serializer.toJson<String>(family),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'revision': serializer.toJson<int>(revision),
      'commitOrdinal': serializer.toJson<int>(commitOrdinal),
      'availabilityState': serializer.toJson<String>(availabilityState),
    };
  }

  LearningScope copyWith({
    Value<int?> id = const Value.absent(),
    String? ownerKind,
    String? ownerId,
    String? courseId,
    String? family,
    int? schemaVersion,
    int? revision,
    int? commitOrdinal,
    String? availabilityState,
  }) => LearningScope(
    id: id.present ? id.value : this.id,
    ownerKind: ownerKind ?? this.ownerKind,
    ownerId: ownerId ?? this.ownerId,
    courseId: courseId ?? this.courseId,
    family: family ?? this.family,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    revision: revision ?? this.revision,
    commitOrdinal: commitOrdinal ?? this.commitOrdinal,
    availabilityState: availabilityState ?? this.availabilityState,
  );
  LearningScope copyWithCompanion(LearningScopesCompanion data) {
    return LearningScope(
      id: data.id.present ? data.id.value : this.id,
      ownerKind: data.ownerKind.present ? data.ownerKind.value : this.ownerKind,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      family: data.family.present ? data.family.value : this.family,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      revision: data.revision.present ? data.revision.value : this.revision,
      commitOrdinal: data.commitOrdinal.present
          ? data.commitOrdinal.value
          : this.commitOrdinal,
      availabilityState: data.availabilityState.present
          ? data.availabilityState.value
          : this.availabilityState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningScope(')
          ..write('id: $id, ')
          ..write('ownerKind: $ownerKind, ')
          ..write('ownerId: $ownerId, ')
          ..write('courseId: $courseId, ')
          ..write('family: $family, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('revision: $revision, ')
          ..write('commitOrdinal: $commitOrdinal, ')
          ..write('availabilityState: $availabilityState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerKind,
    ownerId,
    courseId,
    family,
    schemaVersion,
    revision,
    commitOrdinal,
    availabilityState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningScope &&
          other.id == this.id &&
          other.ownerKind == this.ownerKind &&
          other.ownerId == this.ownerId &&
          other.courseId == this.courseId &&
          other.family == this.family &&
          other.schemaVersion == this.schemaVersion &&
          other.revision == this.revision &&
          other.commitOrdinal == this.commitOrdinal &&
          other.availabilityState == this.availabilityState);
}

class LearningScopesCompanion extends UpdateCompanion<LearningScope> {
  final Value<int?> id;
  final Value<String> ownerKind;
  final Value<String> ownerId;
  final Value<String> courseId;
  final Value<String> family;
  final Value<int> schemaVersion;
  final Value<int> revision;
  final Value<int> commitOrdinal;
  final Value<String> availabilityState;
  const LearningScopesCompanion({
    this.id = const Value.absent(),
    this.ownerKind = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.family = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.revision = const Value.absent(),
    this.commitOrdinal = const Value.absent(),
    this.availabilityState = const Value.absent(),
  });
  LearningScopesCompanion.insert({
    this.id = const Value.absent(),
    required String ownerKind,
    required String ownerId,
    required String courseId,
    required String family,
    required int schemaVersion,
    required int revision,
    required int commitOrdinal,
    required String availabilityState,
  }) : ownerKind = Value(ownerKind),
       ownerId = Value(ownerId),
       courseId = Value(courseId),
       family = Value(family),
       schemaVersion = Value(schemaVersion),
       revision = Value(revision),
       commitOrdinal = Value(commitOrdinal),
       availabilityState = Value(availabilityState);
  static Insertable<LearningScope> custom({
    Expression<int>? id,
    Expression<String>? ownerKind,
    Expression<String>? ownerId,
    Expression<String>? courseId,
    Expression<String>? family,
    Expression<int>? schemaVersion,
    Expression<int>? revision,
    Expression<int>? commitOrdinal,
    Expression<String>? availabilityState,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerKind != null) 'owner_kind': ownerKind,
      if (ownerId != null) 'owner_id': ownerId,
      if (courseId != null) 'course_id': courseId,
      if (family != null) 'family': family,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (revision != null) 'revision': revision,
      if (commitOrdinal != null) 'commit_ordinal': commitOrdinal,
      if (availabilityState != null) 'availability_state': availabilityState,
    });
  }

  LearningScopesCompanion copyWith({
    Value<int?>? id,
    Value<String>? ownerKind,
    Value<String>? ownerId,
    Value<String>? courseId,
    Value<String>? family,
    Value<int>? schemaVersion,
    Value<int>? revision,
    Value<int>? commitOrdinal,
    Value<String>? availabilityState,
  }) {
    return LearningScopesCompanion(
      id: id ?? this.id,
      ownerKind: ownerKind ?? this.ownerKind,
      ownerId: ownerId ?? this.ownerId,
      courseId: courseId ?? this.courseId,
      family: family ?? this.family,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      revision: revision ?? this.revision,
      commitOrdinal: commitOrdinal ?? this.commitOrdinal,
      availabilityState: availabilityState ?? this.availabilityState,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ownerKind.present) {
      map['owner_kind'] = Variable<String>(ownerKind.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (family.present) {
      map['family'] = Variable<String>(family.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (commitOrdinal.present) {
      map['commit_ordinal'] = Variable<int>(commitOrdinal.value);
    }
    if (availabilityState.present) {
      map['availability_state'] = Variable<String>(availabilityState.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningScopesCompanion(')
          ..write('id: $id, ')
          ..write('ownerKind: $ownerKind, ')
          ..write('ownerId: $ownerId, ')
          ..write('courseId: $courseId, ')
          ..write('family: $family, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('revision: $revision, ')
          ..write('commitOrdinal: $commitOrdinal, ')
          ..write('availabilityState: $availabilityState')
          ..write(')'))
        .toString();
  }
}

class $LearningContentBindingsTable extends LearningContentBindings
    with TableInfo<$LearningContentBindingsTable, LearningContentBinding> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningContentBindingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentRevisionMeta = const VerificationMeta(
    'contentRevision',
  );
  @override
  late final GeneratedColumn<int> contentRevision = GeneratedColumn<int>(
    'content_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _policyKindMeta = const VerificationMeta(
    'policyKind',
  );
  @override
  late final GeneratedColumn<String> policyKind = GeneratedColumn<String>(
    'policy_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _policyRevisionMeta = const VerificationMeta(
    'policyRevision',
  );
  @override
  late final GeneratedColumn<int> policyRevision = GeneratedColumn<int>(
    'policy_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _catalogueFingerprintMeta =
      const VerificationMeta('catalogueFingerprint');
  @override
  late final GeneratedColumn<String> catalogueFingerprint =
      GeneratedColumn<String>(
        'catalogue_fingerprint',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sectionFingerprintMeta =
      const VerificationMeta('sectionFingerprint');
  @override
  late final GeneratedColumn<String> sectionFingerprint =
      GeneratedColumn<String>(
        'section_fingerprint',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _annotationHashMeta = const VerificationMeta(
    'annotationHash',
  );
  @override
  late final GeneratedColumn<String> annotationHash = GeneratedColumn<String>(
    'annotation_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotationRevisionMeta =
      const VerificationMeta('annotationRevision');
  @override
  late final GeneratedColumn<int> annotationRevision = GeneratedColumn<int>(
    'annotation_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scopeId,
    activityId,
    contentRevision,
    policyKind,
    policyRevision,
    catalogueFingerprint,
    sectionFingerprint,
    annotationHash,
    annotationRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_content_bindings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningContentBinding> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('content_revision')) {
      context.handle(
        _contentRevisionMeta,
        contentRevision.isAcceptableOrUnknown(
          data['content_revision']!,
          _contentRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentRevisionMeta);
    }
    if (data.containsKey('policy_kind')) {
      context.handle(
        _policyKindMeta,
        policyKind.isAcceptableOrUnknown(data['policy_kind']!, _policyKindMeta),
      );
    }
    if (data.containsKey('policy_revision')) {
      context.handle(
        _policyRevisionMeta,
        policyRevision.isAcceptableOrUnknown(
          data['policy_revision']!,
          _policyRevisionMeta,
        ),
      );
    }
    if (data.containsKey('catalogue_fingerprint')) {
      context.handle(
        _catalogueFingerprintMeta,
        catalogueFingerprint.isAcceptableOrUnknown(
          data['catalogue_fingerprint']!,
          _catalogueFingerprintMeta,
        ),
      );
    }
    if (data.containsKey('section_fingerprint')) {
      context.handle(
        _sectionFingerprintMeta,
        sectionFingerprint.isAcceptableOrUnknown(
          data['section_fingerprint']!,
          _sectionFingerprintMeta,
        ),
      );
    }
    if (data.containsKey('annotation_hash')) {
      context.handle(
        _annotationHashMeta,
        annotationHash.isAcceptableOrUnknown(
          data['annotation_hash']!,
          _annotationHashMeta,
        ),
      );
    }
    if (data.containsKey('annotation_revision')) {
      context.handle(
        _annotationRevisionMeta,
        annotationRevision.isAcceptableOrUnknown(
          data['annotation_revision']!,
          _annotationRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LearningContentBinding map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningContentBinding(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      ),
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      contentRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_revision'],
      )!,
      policyKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}policy_kind'],
      ),
      policyRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}policy_revision'],
      ),
      catalogueFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catalogue_fingerprint'],
      ),
      sectionFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_fingerprint'],
      ),
      annotationHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}annotation_hash'],
      ),
      annotationRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}annotation_revision'],
      ),
    );
  }

  @override
  $LearningContentBindingsTable createAlias(String alias) {
    return $LearningContentBindingsTable(attachedDatabase, alias);
  }
}

class LearningContentBinding extends DataClass
    implements Insertable<LearningContentBinding> {
  final int? id;
  final int scopeId;
  final String activityId;
  final int contentRevision;
  final String? policyKind;
  final int? policyRevision;
  final String? catalogueFingerprint;
  final String? sectionFingerprint;
  final String? annotationHash;
  final int? annotationRevision;
  const LearningContentBinding({
    this.id,
    required this.scopeId,
    required this.activityId,
    required this.contentRevision,
    this.policyKind,
    this.policyRevision,
    this.catalogueFingerprint,
    this.sectionFingerprint,
    this.annotationHash,
    this.annotationRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<int>(id);
    }
    map['scope_id'] = Variable<int>(scopeId);
    map['activity_id'] = Variable<String>(activityId);
    map['content_revision'] = Variable<int>(contentRevision);
    if (!nullToAbsent || policyKind != null) {
      map['policy_kind'] = Variable<String>(policyKind);
    }
    if (!nullToAbsent || policyRevision != null) {
      map['policy_revision'] = Variable<int>(policyRevision);
    }
    if (!nullToAbsent || catalogueFingerprint != null) {
      map['catalogue_fingerprint'] = Variable<String>(catalogueFingerprint);
    }
    if (!nullToAbsent || sectionFingerprint != null) {
      map['section_fingerprint'] = Variable<String>(sectionFingerprint);
    }
    if (!nullToAbsent || annotationHash != null) {
      map['annotation_hash'] = Variable<String>(annotationHash);
    }
    if (!nullToAbsent || annotationRevision != null) {
      map['annotation_revision'] = Variable<int>(annotationRevision);
    }
    return map;
  }

  LearningContentBindingsCompanion toCompanion(bool nullToAbsent) {
    return LearningContentBindingsCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      scopeId: Value(scopeId),
      activityId: Value(activityId),
      contentRevision: Value(contentRevision),
      policyKind: policyKind == null && nullToAbsent
          ? const Value.absent()
          : Value(policyKind),
      policyRevision: policyRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(policyRevision),
      catalogueFingerprint: catalogueFingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(catalogueFingerprint),
      sectionFingerprint: sectionFingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionFingerprint),
      annotationHash: annotationHash == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationHash),
      annotationRevision: annotationRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationRevision),
    );
  }

  factory LearningContentBinding.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningContentBinding(
      id: serializer.fromJson<int?>(json['id']),
      scopeId: serializer.fromJson<int>(json['scopeId']),
      activityId: serializer.fromJson<String>(json['activityId']),
      contentRevision: serializer.fromJson<int>(json['contentRevision']),
      policyKind: serializer.fromJson<String?>(json['policyKind']),
      policyRevision: serializer.fromJson<int?>(json['policyRevision']),
      catalogueFingerprint: serializer.fromJson<String?>(
        json['catalogueFingerprint'],
      ),
      sectionFingerprint: serializer.fromJson<String?>(
        json['sectionFingerprint'],
      ),
      annotationHash: serializer.fromJson<String?>(json['annotationHash']),
      annotationRevision: serializer.fromJson<int?>(json['annotationRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int?>(id),
      'scopeId': serializer.toJson<int>(scopeId),
      'activityId': serializer.toJson<String>(activityId),
      'contentRevision': serializer.toJson<int>(contentRevision),
      'policyKind': serializer.toJson<String?>(policyKind),
      'policyRevision': serializer.toJson<int?>(policyRevision),
      'catalogueFingerprint': serializer.toJson<String?>(catalogueFingerprint),
      'sectionFingerprint': serializer.toJson<String?>(sectionFingerprint),
      'annotationHash': serializer.toJson<String?>(annotationHash),
      'annotationRevision': serializer.toJson<int?>(annotationRevision),
    };
  }

  LearningContentBinding copyWith({
    Value<int?> id = const Value.absent(),
    int? scopeId,
    String? activityId,
    int? contentRevision,
    Value<String?> policyKind = const Value.absent(),
    Value<int?> policyRevision = const Value.absent(),
    Value<String?> catalogueFingerprint = const Value.absent(),
    Value<String?> sectionFingerprint = const Value.absent(),
    Value<String?> annotationHash = const Value.absent(),
    Value<int?> annotationRevision = const Value.absent(),
  }) => LearningContentBinding(
    id: id.present ? id.value : this.id,
    scopeId: scopeId ?? this.scopeId,
    activityId: activityId ?? this.activityId,
    contentRevision: contentRevision ?? this.contentRevision,
    policyKind: policyKind.present ? policyKind.value : this.policyKind,
    policyRevision: policyRevision.present
        ? policyRevision.value
        : this.policyRevision,
    catalogueFingerprint: catalogueFingerprint.present
        ? catalogueFingerprint.value
        : this.catalogueFingerprint,
    sectionFingerprint: sectionFingerprint.present
        ? sectionFingerprint.value
        : this.sectionFingerprint,
    annotationHash: annotationHash.present
        ? annotationHash.value
        : this.annotationHash,
    annotationRevision: annotationRevision.present
        ? annotationRevision.value
        : this.annotationRevision,
  );
  LearningContentBinding copyWithCompanion(
    LearningContentBindingsCompanion data,
  ) {
    return LearningContentBinding(
      id: data.id.present ? data.id.value : this.id,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      contentRevision: data.contentRevision.present
          ? data.contentRevision.value
          : this.contentRevision,
      policyKind: data.policyKind.present
          ? data.policyKind.value
          : this.policyKind,
      policyRevision: data.policyRevision.present
          ? data.policyRevision.value
          : this.policyRevision,
      catalogueFingerprint: data.catalogueFingerprint.present
          ? data.catalogueFingerprint.value
          : this.catalogueFingerprint,
      sectionFingerprint: data.sectionFingerprint.present
          ? data.sectionFingerprint.value
          : this.sectionFingerprint,
      annotationHash: data.annotationHash.present
          ? data.annotationHash.value
          : this.annotationHash,
      annotationRevision: data.annotationRevision.present
          ? data.annotationRevision.value
          : this.annotationRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningContentBinding(')
          ..write('id: $id, ')
          ..write('scopeId: $scopeId, ')
          ..write('activityId: $activityId, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('policyKind: $policyKind, ')
          ..write('policyRevision: $policyRevision, ')
          ..write('catalogueFingerprint: $catalogueFingerprint, ')
          ..write('sectionFingerprint: $sectionFingerprint, ')
          ..write('annotationHash: $annotationHash, ')
          ..write('annotationRevision: $annotationRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scopeId,
    activityId,
    contentRevision,
    policyKind,
    policyRevision,
    catalogueFingerprint,
    sectionFingerprint,
    annotationHash,
    annotationRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningContentBinding &&
          other.id == this.id &&
          other.scopeId == this.scopeId &&
          other.activityId == this.activityId &&
          other.contentRevision == this.contentRevision &&
          other.policyKind == this.policyKind &&
          other.policyRevision == this.policyRevision &&
          other.catalogueFingerprint == this.catalogueFingerprint &&
          other.sectionFingerprint == this.sectionFingerprint &&
          other.annotationHash == this.annotationHash &&
          other.annotationRevision == this.annotationRevision);
}

class LearningContentBindingsCompanion
    extends UpdateCompanion<LearningContentBinding> {
  final Value<int?> id;
  final Value<int> scopeId;
  final Value<String> activityId;
  final Value<int> contentRevision;
  final Value<String?> policyKind;
  final Value<int?> policyRevision;
  final Value<String?> catalogueFingerprint;
  final Value<String?> sectionFingerprint;
  final Value<String?> annotationHash;
  final Value<int?> annotationRevision;
  const LearningContentBindingsCompanion({
    this.id = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.activityId = const Value.absent(),
    this.contentRevision = const Value.absent(),
    this.policyKind = const Value.absent(),
    this.policyRevision = const Value.absent(),
    this.catalogueFingerprint = const Value.absent(),
    this.sectionFingerprint = const Value.absent(),
    this.annotationHash = const Value.absent(),
    this.annotationRevision = const Value.absent(),
  });
  LearningContentBindingsCompanion.insert({
    this.id = const Value.absent(),
    required int scopeId,
    required String activityId,
    required int contentRevision,
    this.policyKind = const Value.absent(),
    this.policyRevision = const Value.absent(),
    this.catalogueFingerprint = const Value.absent(),
    this.sectionFingerprint = const Value.absent(),
    this.annotationHash = const Value.absent(),
    this.annotationRevision = const Value.absent(),
  }) : scopeId = Value(scopeId),
       activityId = Value(activityId),
       contentRevision = Value(contentRevision);
  static Insertable<LearningContentBinding> custom({
    Expression<int>? id,
    Expression<int>? scopeId,
    Expression<String>? activityId,
    Expression<int>? contentRevision,
    Expression<String>? policyKind,
    Expression<int>? policyRevision,
    Expression<String>? catalogueFingerprint,
    Expression<String>? sectionFingerprint,
    Expression<String>? annotationHash,
    Expression<int>? annotationRevision,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scopeId != null) 'scope_id': scopeId,
      if (activityId != null) 'activity_id': activityId,
      if (contentRevision != null) 'content_revision': contentRevision,
      if (policyKind != null) 'policy_kind': policyKind,
      if (policyRevision != null) 'policy_revision': policyRevision,
      if (catalogueFingerprint != null)
        'catalogue_fingerprint': catalogueFingerprint,
      if (sectionFingerprint != null) 'section_fingerprint': sectionFingerprint,
      if (annotationHash != null) 'annotation_hash': annotationHash,
      if (annotationRevision != null) 'annotation_revision': annotationRevision,
    });
  }

  LearningContentBindingsCompanion copyWith({
    Value<int?>? id,
    Value<int>? scopeId,
    Value<String>? activityId,
    Value<int>? contentRevision,
    Value<String?>? policyKind,
    Value<int?>? policyRevision,
    Value<String?>? catalogueFingerprint,
    Value<String?>? sectionFingerprint,
    Value<String?>? annotationHash,
    Value<int?>? annotationRevision,
  }) {
    return LearningContentBindingsCompanion(
      id: id ?? this.id,
      scopeId: scopeId ?? this.scopeId,
      activityId: activityId ?? this.activityId,
      contentRevision: contentRevision ?? this.contentRevision,
      policyKind: policyKind ?? this.policyKind,
      policyRevision: policyRevision ?? this.policyRevision,
      catalogueFingerprint: catalogueFingerprint ?? this.catalogueFingerprint,
      sectionFingerprint: sectionFingerprint ?? this.sectionFingerprint,
      annotationHash: annotationHash ?? this.annotationHash,
      annotationRevision: annotationRevision ?? this.annotationRevision,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (contentRevision.present) {
      map['content_revision'] = Variable<int>(contentRevision.value);
    }
    if (policyKind.present) {
      map['policy_kind'] = Variable<String>(policyKind.value);
    }
    if (policyRevision.present) {
      map['policy_revision'] = Variable<int>(policyRevision.value);
    }
    if (catalogueFingerprint.present) {
      map['catalogue_fingerprint'] = Variable<String>(
        catalogueFingerprint.value,
      );
    }
    if (sectionFingerprint.present) {
      map['section_fingerprint'] = Variable<String>(sectionFingerprint.value);
    }
    if (annotationHash.present) {
      map['annotation_hash'] = Variable<String>(annotationHash.value);
    }
    if (annotationRevision.present) {
      map['annotation_revision'] = Variable<int>(annotationRevision.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningContentBindingsCompanion(')
          ..write('id: $id, ')
          ..write('scopeId: $scopeId, ')
          ..write('activityId: $activityId, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('policyKind: $policyKind, ')
          ..write('policyRevision: $policyRevision, ')
          ..write('catalogueFingerprint: $catalogueFingerprint, ')
          ..write('sectionFingerprint: $sectionFingerprint, ')
          ..write('annotationHash: $annotationHash, ')
          ..write('annotationRevision: $annotationRevision')
          ..write(')'))
        .toString();
  }
}

class $LearningRunsTable extends LearningRuns
    with TableInfo<$LearningRunsTable, LearningRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityKindMeta = const VerificationMeta(
    'activityKind',
  );
  @override
  late final GeneratedColumn<String> activityKind = GeneratedColumn<String>(
    'activity_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runGenerationMeta = const VerificationMeta(
    'runGeneration',
  );
  @override
  late final GeneratedColumn<int> runGeneration = GeneratedColumn<int>(
    'run_generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorRevisionMeta = const VerificationMeta(
    'cursorRevision',
  );
  @override
  late final GeneratedColumn<int> cursorRevision = GeneratedColumn<int>(
    'cursor_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentBindingIdMeta = const VerificationMeta(
    'contentBindingId',
  );
  @override
  late final GeneratedColumn<int> contentBindingId = GeneratedColumn<int>(
    'content_binding_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_content_bindings (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _runModeMeta = const VerificationMeta(
    'runMode',
  );
  @override
  late final GeneratedColumn<String> runMode = GeneratedColumn<String>(
    'run_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedMeta = const VerificationMeta(
    'finished',
  );
  @override
  late final GeneratedColumn<int> finished = GeneratedColumn<int>(
    'finished',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _policyRevisionMeta = const VerificationMeta(
    'policyRevision',
  );
  @override
  late final GeneratedColumn<int> policyRevision = GeneratedColumn<int>(
    'policy_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thresholdPercentMeta = const VerificationMeta(
    'thresholdPercent',
  );
  @override
  late final GeneratedColumn<int> thresholdPercent = GeneratedColumn<int>(
    'threshold_percent',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _runStartRoundMeta = const VerificationMeta(
    'runStartRound',
  );
  @override
  late final GeneratedColumn<int> runStartRound = GeneratedColumn<int>(
    'run_start_round',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkpointJsonMeta = const VerificationMeta(
    'checkpointJson',
  );
  @override
  late final GeneratedColumn<String> checkpointJson = GeneratedColumn<String>(
    'checkpoint_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latestReceiptTokenMeta =
      const VerificationMeta('latestReceiptToken');
  @override
  late final GeneratedColumn<String> latestReceiptToken =
      GeneratedColumn<String>(
        'latest_receipt_token',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _latestReceiptPayloadMeta =
      const VerificationMeta('latestReceiptPayload');
  @override
  late final GeneratedColumn<String> latestReceiptPayload =
      GeneratedColumn<String>(
        'latest_receipt_payload',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _latestReceiptBeforeGenerationMeta =
      const VerificationMeta('latestReceiptBeforeGeneration');
  @override
  late final GeneratedColumn<int> latestReceiptBeforeGeneration =
      GeneratedColumn<int>(
        'latest_receipt_before_generation',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _latestReceiptBeforeSequenceMeta =
      const VerificationMeta('latestReceiptBeforeSequence');
  @override
  late final GeneratedColumn<int> latestReceiptBeforeSequence =
      GeneratedColumn<int>(
        'latest_receipt_before_sequence',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _latestReceiptBeforeCursorRevisionMeta =
      const VerificationMeta('latestReceiptBeforeCursorRevision');
  @override
  late final GeneratedColumn<int> latestReceiptBeforeCursorRevision =
      GeneratedColumn<int>(
        'latest_receipt_before_cursor_revision',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _latestReceiptCommitOrdinalMeta =
      const VerificationMeta('latestReceiptCommitOrdinal');
  @override
  late final GeneratedColumn<int> latestReceiptCommitOrdinal =
      GeneratedColumn<int>(
        'latest_receipt_commit_ordinal',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    activityId,
    activityKind,
    runGeneration,
    sequence,
    cursorRevision,
    contentBindingId,
    runMode,
    finished,
    sessionId,
    policyRevision,
    thresholdPercent,
    runStartRound,
    checkpointJson,
    latestReceiptToken,
    latestReceiptPayload,
    latestReceiptBeforeGeneration,
    latestReceiptBeforeSequence,
    latestReceiptBeforeCursorRevision,
    latestReceiptCommitOrdinal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningRun> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('activity_kind')) {
      context.handle(
        _activityKindMeta,
        activityKind.isAcceptableOrUnknown(
          data['activity_kind']!,
          _activityKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityKindMeta);
    }
    if (data.containsKey('run_generation')) {
      context.handle(
        _runGenerationMeta,
        runGeneration.isAcceptableOrUnknown(
          data['run_generation']!,
          _runGenerationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_runGenerationMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('cursor_revision')) {
      context.handle(
        _cursorRevisionMeta,
        cursorRevision.isAcceptableOrUnknown(
          data['cursor_revision']!,
          _cursorRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cursorRevisionMeta);
    }
    if (data.containsKey('content_binding_id')) {
      context.handle(
        _contentBindingIdMeta,
        contentBindingId.isAcceptableOrUnknown(
          data['content_binding_id']!,
          _contentBindingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentBindingIdMeta);
    }
    if (data.containsKey('run_mode')) {
      context.handle(
        _runModeMeta,
        runMode.isAcceptableOrUnknown(data['run_mode']!, _runModeMeta),
      );
    }
    if (data.containsKey('finished')) {
      context.handle(
        _finishedMeta,
        finished.isAcceptableOrUnknown(data['finished']!, _finishedMeta),
      );
    } else if (isInserting) {
      context.missing(_finishedMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('policy_revision')) {
      context.handle(
        _policyRevisionMeta,
        policyRevision.isAcceptableOrUnknown(
          data['policy_revision']!,
          _policyRevisionMeta,
        ),
      );
    }
    if (data.containsKey('threshold_percent')) {
      context.handle(
        _thresholdPercentMeta,
        thresholdPercent.isAcceptableOrUnknown(
          data['threshold_percent']!,
          _thresholdPercentMeta,
        ),
      );
    }
    if (data.containsKey('run_start_round')) {
      context.handle(
        _runStartRoundMeta,
        runStartRound.isAcceptableOrUnknown(
          data['run_start_round']!,
          _runStartRoundMeta,
        ),
      );
    }
    if (data.containsKey('checkpoint_json')) {
      context.handle(
        _checkpointJsonMeta,
        checkpointJson.isAcceptableOrUnknown(
          data['checkpoint_json']!,
          _checkpointJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_checkpointJsonMeta);
    }
    if (data.containsKey('latest_receipt_token')) {
      context.handle(
        _latestReceiptTokenMeta,
        latestReceiptToken.isAcceptableOrUnknown(
          data['latest_receipt_token']!,
          _latestReceiptTokenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_latestReceiptTokenMeta);
    }
    if (data.containsKey('latest_receipt_payload')) {
      context.handle(
        _latestReceiptPayloadMeta,
        latestReceiptPayload.isAcceptableOrUnknown(
          data['latest_receipt_payload']!,
          _latestReceiptPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_latestReceiptPayloadMeta);
    }
    if (data.containsKey('latest_receipt_before_generation')) {
      context.handle(
        _latestReceiptBeforeGenerationMeta,
        latestReceiptBeforeGeneration.isAcceptableOrUnknown(
          data['latest_receipt_before_generation']!,
          _latestReceiptBeforeGenerationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_latestReceiptBeforeGenerationMeta);
    }
    if (data.containsKey('latest_receipt_before_sequence')) {
      context.handle(
        _latestReceiptBeforeSequenceMeta,
        latestReceiptBeforeSequence.isAcceptableOrUnknown(
          data['latest_receipt_before_sequence']!,
          _latestReceiptBeforeSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_latestReceiptBeforeSequenceMeta);
    }
    if (data.containsKey('latest_receipt_before_cursor_revision')) {
      context.handle(
        _latestReceiptBeforeCursorRevisionMeta,
        latestReceiptBeforeCursorRevision.isAcceptableOrUnknown(
          data['latest_receipt_before_cursor_revision']!,
          _latestReceiptBeforeCursorRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_latestReceiptBeforeCursorRevisionMeta);
    }
    if (data.containsKey('latest_receipt_commit_ordinal')) {
      context.handle(
        _latestReceiptCommitOrdinalMeta,
        latestReceiptCommitOrdinal.isAcceptableOrUnknown(
          data['latest_receipt_commit_ordinal']!,
          _latestReceiptCommitOrdinalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_latestReceiptCommitOrdinalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  LearningRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningRun(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      activityKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_kind'],
      )!,
      runGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}run_generation'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      cursorRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cursor_revision'],
      )!,
      contentBindingId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_binding_id'],
      )!,
      runMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_mode'],
      ),
      finished: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finished'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      policyRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}policy_revision'],
      ),
      thresholdPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}threshold_percent'],
      ),
      runStartRound: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}run_start_round'],
      ),
      checkpointJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checkpoint_json'],
      )!,
      latestReceiptToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latest_receipt_token'],
      )!,
      latestReceiptPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latest_receipt_payload'],
      )!,
      latestReceiptBeforeGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latest_receipt_before_generation'],
      )!,
      latestReceiptBeforeSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latest_receipt_before_sequence'],
      )!,
      latestReceiptBeforeCursorRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latest_receipt_before_cursor_revision'],
      )!,
      latestReceiptCommitOrdinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latest_receipt_commit_ordinal'],
      )!,
    );
  }

  @override
  $LearningRunsTable createAlias(String alias) {
    return $LearningRunsTable(attachedDatabase, alias);
  }
}

class LearningRun extends DataClass implements Insertable<LearningRun> {
  final int scopeId;
  final String activityId;
  final String activityKind;
  final int runGeneration;
  final int sequence;
  final int cursorRevision;
  final int contentBindingId;
  final String? runMode;
  final int finished;
  final String? sessionId;
  final int? policyRevision;
  final int? thresholdPercent;
  final int? runStartRound;
  final String checkpointJson;
  final String latestReceiptToken;
  final String latestReceiptPayload;
  final int latestReceiptBeforeGeneration;
  final int latestReceiptBeforeSequence;
  final int latestReceiptBeforeCursorRevision;
  final int latestReceiptCommitOrdinal;
  const LearningRun({
    required this.scopeId,
    required this.activityId,
    required this.activityKind,
    required this.runGeneration,
    required this.sequence,
    required this.cursorRevision,
    required this.contentBindingId,
    this.runMode,
    required this.finished,
    this.sessionId,
    this.policyRevision,
    this.thresholdPercent,
    this.runStartRound,
    required this.checkpointJson,
    required this.latestReceiptToken,
    required this.latestReceiptPayload,
    required this.latestReceiptBeforeGeneration,
    required this.latestReceiptBeforeSequence,
    required this.latestReceiptBeforeCursorRevision,
    required this.latestReceiptCommitOrdinal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['activity_id'] = Variable<String>(activityId);
    map['activity_kind'] = Variable<String>(activityKind);
    map['run_generation'] = Variable<int>(runGeneration);
    map['sequence'] = Variable<int>(sequence);
    map['cursor_revision'] = Variable<int>(cursorRevision);
    map['content_binding_id'] = Variable<int>(contentBindingId);
    if (!nullToAbsent || runMode != null) {
      map['run_mode'] = Variable<String>(runMode);
    }
    map['finished'] = Variable<int>(finished);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    if (!nullToAbsent || policyRevision != null) {
      map['policy_revision'] = Variable<int>(policyRevision);
    }
    if (!nullToAbsent || thresholdPercent != null) {
      map['threshold_percent'] = Variable<int>(thresholdPercent);
    }
    if (!nullToAbsent || runStartRound != null) {
      map['run_start_round'] = Variable<int>(runStartRound);
    }
    map['checkpoint_json'] = Variable<String>(checkpointJson);
    map['latest_receipt_token'] = Variable<String>(latestReceiptToken);
    map['latest_receipt_payload'] = Variable<String>(latestReceiptPayload);
    map['latest_receipt_before_generation'] = Variable<int>(
      latestReceiptBeforeGeneration,
    );
    map['latest_receipt_before_sequence'] = Variable<int>(
      latestReceiptBeforeSequence,
    );
    map['latest_receipt_before_cursor_revision'] = Variable<int>(
      latestReceiptBeforeCursorRevision,
    );
    map['latest_receipt_commit_ordinal'] = Variable<int>(
      latestReceiptCommitOrdinal,
    );
    return map;
  }

  LearningRunsCompanion toCompanion(bool nullToAbsent) {
    return LearningRunsCompanion(
      scopeId: Value(scopeId),
      activityId: Value(activityId),
      activityKind: Value(activityKind),
      runGeneration: Value(runGeneration),
      sequence: Value(sequence),
      cursorRevision: Value(cursorRevision),
      contentBindingId: Value(contentBindingId),
      runMode: runMode == null && nullToAbsent
          ? const Value.absent()
          : Value(runMode),
      finished: Value(finished),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      policyRevision: policyRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(policyRevision),
      thresholdPercent: thresholdPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(thresholdPercent),
      runStartRound: runStartRound == null && nullToAbsent
          ? const Value.absent()
          : Value(runStartRound),
      checkpointJson: Value(checkpointJson),
      latestReceiptToken: Value(latestReceiptToken),
      latestReceiptPayload: Value(latestReceiptPayload),
      latestReceiptBeforeGeneration: Value(latestReceiptBeforeGeneration),
      latestReceiptBeforeSequence: Value(latestReceiptBeforeSequence),
      latestReceiptBeforeCursorRevision: Value(
        latestReceiptBeforeCursorRevision,
      ),
      latestReceiptCommitOrdinal: Value(latestReceiptCommitOrdinal),
    );
  }

  factory LearningRun.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningRun(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      activityId: serializer.fromJson<String>(json['activityId']),
      activityKind: serializer.fromJson<String>(json['activityKind']),
      runGeneration: serializer.fromJson<int>(json['runGeneration']),
      sequence: serializer.fromJson<int>(json['sequence']),
      cursorRevision: serializer.fromJson<int>(json['cursorRevision']),
      contentBindingId: serializer.fromJson<int>(json['contentBindingId']),
      runMode: serializer.fromJson<String?>(json['runMode']),
      finished: serializer.fromJson<int>(json['finished']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      policyRevision: serializer.fromJson<int?>(json['policyRevision']),
      thresholdPercent: serializer.fromJson<int?>(json['thresholdPercent']),
      runStartRound: serializer.fromJson<int?>(json['runStartRound']),
      checkpointJson: serializer.fromJson<String>(json['checkpointJson']),
      latestReceiptToken: serializer.fromJson<String>(
        json['latestReceiptToken'],
      ),
      latestReceiptPayload: serializer.fromJson<String>(
        json['latestReceiptPayload'],
      ),
      latestReceiptBeforeGeneration: serializer.fromJson<int>(
        json['latestReceiptBeforeGeneration'],
      ),
      latestReceiptBeforeSequence: serializer.fromJson<int>(
        json['latestReceiptBeforeSequence'],
      ),
      latestReceiptBeforeCursorRevision: serializer.fromJson<int>(
        json['latestReceiptBeforeCursorRevision'],
      ),
      latestReceiptCommitOrdinal: serializer.fromJson<int>(
        json['latestReceiptCommitOrdinal'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'activityId': serializer.toJson<String>(activityId),
      'activityKind': serializer.toJson<String>(activityKind),
      'runGeneration': serializer.toJson<int>(runGeneration),
      'sequence': serializer.toJson<int>(sequence),
      'cursorRevision': serializer.toJson<int>(cursorRevision),
      'contentBindingId': serializer.toJson<int>(contentBindingId),
      'runMode': serializer.toJson<String?>(runMode),
      'finished': serializer.toJson<int>(finished),
      'sessionId': serializer.toJson<String?>(sessionId),
      'policyRevision': serializer.toJson<int?>(policyRevision),
      'thresholdPercent': serializer.toJson<int?>(thresholdPercent),
      'runStartRound': serializer.toJson<int?>(runStartRound),
      'checkpointJson': serializer.toJson<String>(checkpointJson),
      'latestReceiptToken': serializer.toJson<String>(latestReceiptToken),
      'latestReceiptPayload': serializer.toJson<String>(latestReceiptPayload),
      'latestReceiptBeforeGeneration': serializer.toJson<int>(
        latestReceiptBeforeGeneration,
      ),
      'latestReceiptBeforeSequence': serializer.toJson<int>(
        latestReceiptBeforeSequence,
      ),
      'latestReceiptBeforeCursorRevision': serializer.toJson<int>(
        latestReceiptBeforeCursorRevision,
      ),
      'latestReceiptCommitOrdinal': serializer.toJson<int>(
        latestReceiptCommitOrdinal,
      ),
    };
  }

  LearningRun copyWith({
    int? scopeId,
    String? activityId,
    String? activityKind,
    int? runGeneration,
    int? sequence,
    int? cursorRevision,
    int? contentBindingId,
    Value<String?> runMode = const Value.absent(),
    int? finished,
    Value<String?> sessionId = const Value.absent(),
    Value<int?> policyRevision = const Value.absent(),
    Value<int?> thresholdPercent = const Value.absent(),
    Value<int?> runStartRound = const Value.absent(),
    String? checkpointJson,
    String? latestReceiptToken,
    String? latestReceiptPayload,
    int? latestReceiptBeforeGeneration,
    int? latestReceiptBeforeSequence,
    int? latestReceiptBeforeCursorRevision,
    int? latestReceiptCommitOrdinal,
  }) => LearningRun(
    scopeId: scopeId ?? this.scopeId,
    activityId: activityId ?? this.activityId,
    activityKind: activityKind ?? this.activityKind,
    runGeneration: runGeneration ?? this.runGeneration,
    sequence: sequence ?? this.sequence,
    cursorRevision: cursorRevision ?? this.cursorRevision,
    contentBindingId: contentBindingId ?? this.contentBindingId,
    runMode: runMode.present ? runMode.value : this.runMode,
    finished: finished ?? this.finished,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    policyRevision: policyRevision.present
        ? policyRevision.value
        : this.policyRevision,
    thresholdPercent: thresholdPercent.present
        ? thresholdPercent.value
        : this.thresholdPercent,
    runStartRound: runStartRound.present
        ? runStartRound.value
        : this.runStartRound,
    checkpointJson: checkpointJson ?? this.checkpointJson,
    latestReceiptToken: latestReceiptToken ?? this.latestReceiptToken,
    latestReceiptPayload: latestReceiptPayload ?? this.latestReceiptPayload,
    latestReceiptBeforeGeneration:
        latestReceiptBeforeGeneration ?? this.latestReceiptBeforeGeneration,
    latestReceiptBeforeSequence:
        latestReceiptBeforeSequence ?? this.latestReceiptBeforeSequence,
    latestReceiptBeforeCursorRevision:
        latestReceiptBeforeCursorRevision ??
        this.latestReceiptBeforeCursorRevision,
    latestReceiptCommitOrdinal:
        latestReceiptCommitOrdinal ?? this.latestReceiptCommitOrdinal,
  );
  LearningRun copyWithCompanion(LearningRunsCompanion data) {
    return LearningRun(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      activityKind: data.activityKind.present
          ? data.activityKind.value
          : this.activityKind,
      runGeneration: data.runGeneration.present
          ? data.runGeneration.value
          : this.runGeneration,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      cursorRevision: data.cursorRevision.present
          ? data.cursorRevision.value
          : this.cursorRevision,
      contentBindingId: data.contentBindingId.present
          ? data.contentBindingId.value
          : this.contentBindingId,
      runMode: data.runMode.present ? data.runMode.value : this.runMode,
      finished: data.finished.present ? data.finished.value : this.finished,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      policyRevision: data.policyRevision.present
          ? data.policyRevision.value
          : this.policyRevision,
      thresholdPercent: data.thresholdPercent.present
          ? data.thresholdPercent.value
          : this.thresholdPercent,
      runStartRound: data.runStartRound.present
          ? data.runStartRound.value
          : this.runStartRound,
      checkpointJson: data.checkpointJson.present
          ? data.checkpointJson.value
          : this.checkpointJson,
      latestReceiptToken: data.latestReceiptToken.present
          ? data.latestReceiptToken.value
          : this.latestReceiptToken,
      latestReceiptPayload: data.latestReceiptPayload.present
          ? data.latestReceiptPayload.value
          : this.latestReceiptPayload,
      latestReceiptBeforeGeneration: data.latestReceiptBeforeGeneration.present
          ? data.latestReceiptBeforeGeneration.value
          : this.latestReceiptBeforeGeneration,
      latestReceiptBeforeSequence: data.latestReceiptBeforeSequence.present
          ? data.latestReceiptBeforeSequence.value
          : this.latestReceiptBeforeSequence,
      latestReceiptBeforeCursorRevision:
          data.latestReceiptBeforeCursorRevision.present
          ? data.latestReceiptBeforeCursorRevision.value
          : this.latestReceiptBeforeCursorRevision,
      latestReceiptCommitOrdinal: data.latestReceiptCommitOrdinal.present
          ? data.latestReceiptCommitOrdinal.value
          : this.latestReceiptCommitOrdinal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningRun(')
          ..write('scopeId: $scopeId, ')
          ..write('activityId: $activityId, ')
          ..write('activityKind: $activityKind, ')
          ..write('runGeneration: $runGeneration, ')
          ..write('sequence: $sequence, ')
          ..write('cursorRevision: $cursorRevision, ')
          ..write('contentBindingId: $contentBindingId, ')
          ..write('runMode: $runMode, ')
          ..write('finished: $finished, ')
          ..write('sessionId: $sessionId, ')
          ..write('policyRevision: $policyRevision, ')
          ..write('thresholdPercent: $thresholdPercent, ')
          ..write('runStartRound: $runStartRound, ')
          ..write('checkpointJson: $checkpointJson, ')
          ..write('latestReceiptToken: $latestReceiptToken, ')
          ..write('latestReceiptPayload: $latestReceiptPayload, ')
          ..write(
            'latestReceiptBeforeGeneration: $latestReceiptBeforeGeneration, ',
          )
          ..write('latestReceiptBeforeSequence: $latestReceiptBeforeSequence, ')
          ..write(
            'latestReceiptBeforeCursorRevision: $latestReceiptBeforeCursorRevision, ',
          )
          ..write('latestReceiptCommitOrdinal: $latestReceiptCommitOrdinal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    activityId,
    activityKind,
    runGeneration,
    sequence,
    cursorRevision,
    contentBindingId,
    runMode,
    finished,
    sessionId,
    policyRevision,
    thresholdPercent,
    runStartRound,
    checkpointJson,
    latestReceiptToken,
    latestReceiptPayload,
    latestReceiptBeforeGeneration,
    latestReceiptBeforeSequence,
    latestReceiptBeforeCursorRevision,
    latestReceiptCommitOrdinal,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningRun &&
          other.scopeId == this.scopeId &&
          other.activityId == this.activityId &&
          other.activityKind == this.activityKind &&
          other.runGeneration == this.runGeneration &&
          other.sequence == this.sequence &&
          other.cursorRevision == this.cursorRevision &&
          other.contentBindingId == this.contentBindingId &&
          other.runMode == this.runMode &&
          other.finished == this.finished &&
          other.sessionId == this.sessionId &&
          other.policyRevision == this.policyRevision &&
          other.thresholdPercent == this.thresholdPercent &&
          other.runStartRound == this.runStartRound &&
          other.checkpointJson == this.checkpointJson &&
          other.latestReceiptToken == this.latestReceiptToken &&
          other.latestReceiptPayload == this.latestReceiptPayload &&
          other.latestReceiptBeforeGeneration ==
              this.latestReceiptBeforeGeneration &&
          other.latestReceiptBeforeSequence ==
              this.latestReceiptBeforeSequence &&
          other.latestReceiptBeforeCursorRevision ==
              this.latestReceiptBeforeCursorRevision &&
          other.latestReceiptCommitOrdinal == this.latestReceiptCommitOrdinal);
}

class LearningRunsCompanion extends UpdateCompanion<LearningRun> {
  final Value<int> scopeId;
  final Value<String> activityId;
  final Value<String> activityKind;
  final Value<int> runGeneration;
  final Value<int> sequence;
  final Value<int> cursorRevision;
  final Value<int> contentBindingId;
  final Value<String?> runMode;
  final Value<int> finished;
  final Value<String?> sessionId;
  final Value<int?> policyRevision;
  final Value<int?> thresholdPercent;
  final Value<int?> runStartRound;
  final Value<String> checkpointJson;
  final Value<String> latestReceiptToken;
  final Value<String> latestReceiptPayload;
  final Value<int> latestReceiptBeforeGeneration;
  final Value<int> latestReceiptBeforeSequence;
  final Value<int> latestReceiptBeforeCursorRevision;
  final Value<int> latestReceiptCommitOrdinal;
  final Value<int> rowid;
  const LearningRunsCompanion({
    this.scopeId = const Value.absent(),
    this.activityId = const Value.absent(),
    this.activityKind = const Value.absent(),
    this.runGeneration = const Value.absent(),
    this.sequence = const Value.absent(),
    this.cursorRevision = const Value.absent(),
    this.contentBindingId = const Value.absent(),
    this.runMode = const Value.absent(),
    this.finished = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.policyRevision = const Value.absent(),
    this.thresholdPercent = const Value.absent(),
    this.runStartRound = const Value.absent(),
    this.checkpointJson = const Value.absent(),
    this.latestReceiptToken = const Value.absent(),
    this.latestReceiptPayload = const Value.absent(),
    this.latestReceiptBeforeGeneration = const Value.absent(),
    this.latestReceiptBeforeSequence = const Value.absent(),
    this.latestReceiptBeforeCursorRevision = const Value.absent(),
    this.latestReceiptCommitOrdinal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningRunsCompanion.insert({
    required int scopeId,
    required String activityId,
    required String activityKind,
    required int runGeneration,
    required int sequence,
    required int cursorRevision,
    required int contentBindingId,
    this.runMode = const Value.absent(),
    required int finished,
    this.sessionId = const Value.absent(),
    this.policyRevision = const Value.absent(),
    this.thresholdPercent = const Value.absent(),
    this.runStartRound = const Value.absent(),
    required String checkpointJson,
    required String latestReceiptToken,
    required String latestReceiptPayload,
    required int latestReceiptBeforeGeneration,
    required int latestReceiptBeforeSequence,
    required int latestReceiptBeforeCursorRevision,
    required int latestReceiptCommitOrdinal,
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       activityId = Value(activityId),
       activityKind = Value(activityKind),
       runGeneration = Value(runGeneration),
       sequence = Value(sequence),
       cursorRevision = Value(cursorRevision),
       contentBindingId = Value(contentBindingId),
       finished = Value(finished),
       checkpointJson = Value(checkpointJson),
       latestReceiptToken = Value(latestReceiptToken),
       latestReceiptPayload = Value(latestReceiptPayload),
       latestReceiptBeforeGeneration = Value(latestReceiptBeforeGeneration),
       latestReceiptBeforeSequence = Value(latestReceiptBeforeSequence),
       latestReceiptBeforeCursorRevision = Value(
         latestReceiptBeforeCursorRevision,
       ),
       latestReceiptCommitOrdinal = Value(latestReceiptCommitOrdinal);
  static Insertable<LearningRun> custom({
    Expression<int>? scopeId,
    Expression<String>? activityId,
    Expression<String>? activityKind,
    Expression<int>? runGeneration,
    Expression<int>? sequence,
    Expression<int>? cursorRevision,
    Expression<int>? contentBindingId,
    Expression<String>? runMode,
    Expression<int>? finished,
    Expression<String>? sessionId,
    Expression<int>? policyRevision,
    Expression<int>? thresholdPercent,
    Expression<int>? runStartRound,
    Expression<String>? checkpointJson,
    Expression<String>? latestReceiptToken,
    Expression<String>? latestReceiptPayload,
    Expression<int>? latestReceiptBeforeGeneration,
    Expression<int>? latestReceiptBeforeSequence,
    Expression<int>? latestReceiptBeforeCursorRevision,
    Expression<int>? latestReceiptCommitOrdinal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (activityId != null) 'activity_id': activityId,
      if (activityKind != null) 'activity_kind': activityKind,
      if (runGeneration != null) 'run_generation': runGeneration,
      if (sequence != null) 'sequence': sequence,
      if (cursorRevision != null) 'cursor_revision': cursorRevision,
      if (contentBindingId != null) 'content_binding_id': contentBindingId,
      if (runMode != null) 'run_mode': runMode,
      if (finished != null) 'finished': finished,
      if (sessionId != null) 'session_id': sessionId,
      if (policyRevision != null) 'policy_revision': policyRevision,
      if (thresholdPercent != null) 'threshold_percent': thresholdPercent,
      if (runStartRound != null) 'run_start_round': runStartRound,
      if (checkpointJson != null) 'checkpoint_json': checkpointJson,
      if (latestReceiptToken != null)
        'latest_receipt_token': latestReceiptToken,
      if (latestReceiptPayload != null)
        'latest_receipt_payload': latestReceiptPayload,
      if (latestReceiptBeforeGeneration != null)
        'latest_receipt_before_generation': latestReceiptBeforeGeneration,
      if (latestReceiptBeforeSequence != null)
        'latest_receipt_before_sequence': latestReceiptBeforeSequence,
      if (latestReceiptBeforeCursorRevision != null)
        'latest_receipt_before_cursor_revision':
            latestReceiptBeforeCursorRevision,
      if (latestReceiptCommitOrdinal != null)
        'latest_receipt_commit_ordinal': latestReceiptCommitOrdinal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningRunsCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? activityId,
    Value<String>? activityKind,
    Value<int>? runGeneration,
    Value<int>? sequence,
    Value<int>? cursorRevision,
    Value<int>? contentBindingId,
    Value<String?>? runMode,
    Value<int>? finished,
    Value<String?>? sessionId,
    Value<int?>? policyRevision,
    Value<int?>? thresholdPercent,
    Value<int?>? runStartRound,
    Value<String>? checkpointJson,
    Value<String>? latestReceiptToken,
    Value<String>? latestReceiptPayload,
    Value<int>? latestReceiptBeforeGeneration,
    Value<int>? latestReceiptBeforeSequence,
    Value<int>? latestReceiptBeforeCursorRevision,
    Value<int>? latestReceiptCommitOrdinal,
    Value<int>? rowid,
  }) {
    return LearningRunsCompanion(
      scopeId: scopeId ?? this.scopeId,
      activityId: activityId ?? this.activityId,
      activityKind: activityKind ?? this.activityKind,
      runGeneration: runGeneration ?? this.runGeneration,
      sequence: sequence ?? this.sequence,
      cursorRevision: cursorRevision ?? this.cursorRevision,
      contentBindingId: contentBindingId ?? this.contentBindingId,
      runMode: runMode ?? this.runMode,
      finished: finished ?? this.finished,
      sessionId: sessionId ?? this.sessionId,
      policyRevision: policyRevision ?? this.policyRevision,
      thresholdPercent: thresholdPercent ?? this.thresholdPercent,
      runStartRound: runStartRound ?? this.runStartRound,
      checkpointJson: checkpointJson ?? this.checkpointJson,
      latestReceiptToken: latestReceiptToken ?? this.latestReceiptToken,
      latestReceiptPayload: latestReceiptPayload ?? this.latestReceiptPayload,
      latestReceiptBeforeGeneration:
          latestReceiptBeforeGeneration ?? this.latestReceiptBeforeGeneration,
      latestReceiptBeforeSequence:
          latestReceiptBeforeSequence ?? this.latestReceiptBeforeSequence,
      latestReceiptBeforeCursorRevision:
          latestReceiptBeforeCursorRevision ??
          this.latestReceiptBeforeCursorRevision,
      latestReceiptCommitOrdinal:
          latestReceiptCommitOrdinal ?? this.latestReceiptCommitOrdinal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (activityKind.present) {
      map['activity_kind'] = Variable<String>(activityKind.value);
    }
    if (runGeneration.present) {
      map['run_generation'] = Variable<int>(runGeneration.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (cursorRevision.present) {
      map['cursor_revision'] = Variable<int>(cursorRevision.value);
    }
    if (contentBindingId.present) {
      map['content_binding_id'] = Variable<int>(contentBindingId.value);
    }
    if (runMode.present) {
      map['run_mode'] = Variable<String>(runMode.value);
    }
    if (finished.present) {
      map['finished'] = Variable<int>(finished.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (policyRevision.present) {
      map['policy_revision'] = Variable<int>(policyRevision.value);
    }
    if (thresholdPercent.present) {
      map['threshold_percent'] = Variable<int>(thresholdPercent.value);
    }
    if (runStartRound.present) {
      map['run_start_round'] = Variable<int>(runStartRound.value);
    }
    if (checkpointJson.present) {
      map['checkpoint_json'] = Variable<String>(checkpointJson.value);
    }
    if (latestReceiptToken.present) {
      map['latest_receipt_token'] = Variable<String>(latestReceiptToken.value);
    }
    if (latestReceiptPayload.present) {
      map['latest_receipt_payload'] = Variable<String>(
        latestReceiptPayload.value,
      );
    }
    if (latestReceiptBeforeGeneration.present) {
      map['latest_receipt_before_generation'] = Variable<int>(
        latestReceiptBeforeGeneration.value,
      );
    }
    if (latestReceiptBeforeSequence.present) {
      map['latest_receipt_before_sequence'] = Variable<int>(
        latestReceiptBeforeSequence.value,
      );
    }
    if (latestReceiptBeforeCursorRevision.present) {
      map['latest_receipt_before_cursor_revision'] = Variable<int>(
        latestReceiptBeforeCursorRevision.value,
      );
    }
    if (latestReceiptCommitOrdinal.present) {
      map['latest_receipt_commit_ordinal'] = Variable<int>(
        latestReceiptCommitOrdinal.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningRunsCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('activityId: $activityId, ')
          ..write('activityKind: $activityKind, ')
          ..write('runGeneration: $runGeneration, ')
          ..write('sequence: $sequence, ')
          ..write('cursorRevision: $cursorRevision, ')
          ..write('contentBindingId: $contentBindingId, ')
          ..write('runMode: $runMode, ')
          ..write('finished: $finished, ')
          ..write('sessionId: $sessionId, ')
          ..write('policyRevision: $policyRevision, ')
          ..write('thresholdPercent: $thresholdPercent, ')
          ..write('runStartRound: $runStartRound, ')
          ..write('checkpointJson: $checkpointJson, ')
          ..write('latestReceiptToken: $latestReceiptToken, ')
          ..write('latestReceiptPayload: $latestReceiptPayload, ')
          ..write(
            'latestReceiptBeforeGeneration: $latestReceiptBeforeGeneration, ',
          )
          ..write('latestReceiptBeforeSequence: $latestReceiptBeforeSequence, ')
          ..write(
            'latestReceiptBeforeCursorRevision: $latestReceiptBeforeCursorRevision, ',
          )
          ..write('latestReceiptCommitOrdinal: $latestReceiptCommitOrdinal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningAttemptsTable extends LearningAttempts
    with TableInfo<$LearningAttemptsTable, LearningAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runGenerationMeta = const VerificationMeta(
    'runGeneration',
  );
  @override
  late final GeneratedColumn<int> runGeneration = GeneratedColumn<int>(
    'run_generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandSequenceMeta = const VerificationMeta(
    'commandSequence',
  );
  @override
  late final GeneratedColumn<int> commandSequence = GeneratedColumn<int>(
    'command_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batchIndexMeta = const VerificationMeta(
    'batchIndex',
  );
  @override
  late final GeneratedColumn<int> batchIndex = GeneratedColumn<int>(
    'batch_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemOccurrenceMeta = const VerificationMeta(
    'itemOccurrence',
  );
  @override
  late final GeneratedColumn<int> itemOccurrence = GeneratedColumn<int>(
    'item_occurrence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentRevisionMeta = const VerificationMeta(
    'contentRevision',
  );
  @override
  late final GeneratedColumn<int> contentRevision = GeneratedColumn<int>(
    'content_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commitOrdinalMeta = const VerificationMeta(
    'commitOrdinal',
  );
  @override
  late final GeneratedColumn<int> commitOrdinal = GeneratedColumn<int>(
    'commit_ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answeredAtUsMeta = const VerificationMeta(
    'answeredAtUs',
  );
  @override
  late final GeneratedColumn<int> answeredAtUs = GeneratedColumn<int>(
    'answered_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _committedAtUsMeta = const VerificationMeta(
    'committedAtUs',
  );
  @override
  late final GeneratedColumn<int> committedAtUs = GeneratedColumn<int>(
    'committed_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerKindMeta = const VerificationMeta(
    'answerKind',
  );
  @override
  late final GeneratedColumn<String> answerKind = GeneratedColumn<String>(
    'answer_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<int> correct = GeneratedColumn<int>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skillMeta = const VerificationMeta('skill');
  @override
  late final GeneratedColumn<String> skill = GeneratedColumn<String>(
    'skill',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _presentationMeta = const VerificationMeta(
    'presentation',
  );
  @override
  late final GeneratedColumn<String> presentation = GeneratedColumn<String>(
    'presentation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assistanceMaskMeta = const VerificationMeta(
    'assistanceMask',
  );
  @override
  late final GeneratedColumn<int> assistanceMask = GeneratedColumn<int>(
    'assistance_mask',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentStateMeta = const VerificationMeta(
    'contentState',
  );
  @override
  late final GeneratedColumn<String> contentState = GeneratedColumn<String>(
    'content_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioSourceMeta = const VerificationMeta(
    'audioSource',
  );
  @override
  late final GeneratedColumn<String> audioSource = GeneratedColumn<String>(
    'audio_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roundMeta = const VerificationMeta('round');
  @override
  late final GeneratedColumn<int> round = GeneratedColumn<int>(
    'round',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _afterDebriefMeta = const VerificationMeta(
    'afterDebrief',
  );
  @override
  late final GeneratedColumn<int> afterDebrief = GeneratedColumn<int>(
    'after_debrief',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _teachingExposedMeta = const VerificationMeta(
    'teachingExposed',
  );
  @override
  late final GeneratedColumn<int> teachingExposed = GeneratedColumn<int>(
    'teaching_exposed',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _selectedRelationMeta = const VerificationMeta(
    'selectedRelation',
  );
  @override
  late final GeneratedColumn<String> selectedRelation = GeneratedColumn<String>(
    'selected_relation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expectedRelationMeta = const VerificationMeta(
    'expectedRelation',
  );
  @override
  late final GeneratedColumn<String> expectedRelation = GeneratedColumn<String>(
    'expected_relation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentenceIdMeta = const VerificationMeta(
    'sentenceId',
  );
  @override
  late final GeneratedColumn<String> sentenceId = GeneratedColumn<String>(
    'sentence_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotationHashMeta = const VerificationMeta(
    'annotationHash',
  );
  @override
  late final GeneratedColumn<String> annotationHash = GeneratedColumn<String>(
    'annotation_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotationRevisionMeta =
      const VerificationMeta('annotationRevision');
  @override
  late final GeneratedColumn<int> annotationRevision = GeneratedColumn<int>(
    'annotation_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    attemptId,
    activityId,
    runGeneration,
    commandSequence,
    batchIndex,
    itemId,
    itemOccurrence,
    contentRevision,
    commitOrdinal,
    answeredAtUs,
    committedAtUs,
    answerKind,
    correct,
    skill,
    origin,
    presentation,
    assistanceMask,
    contentState,
    audioSource,
    round,
    afterDebrief,
    teachingExposed,
    selectedRelation,
    expectedRelation,
    sectionId,
    sentenceId,
    annotationHash,
    annotationRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningAttempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('run_generation')) {
      context.handle(
        _runGenerationMeta,
        runGeneration.isAcceptableOrUnknown(
          data['run_generation']!,
          _runGenerationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_runGenerationMeta);
    }
    if (data.containsKey('command_sequence')) {
      context.handle(
        _commandSequenceMeta,
        commandSequence.isAcceptableOrUnknown(
          data['command_sequence']!,
          _commandSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commandSequenceMeta);
    }
    if (data.containsKey('batch_index')) {
      context.handle(
        _batchIndexMeta,
        batchIndex.isAcceptableOrUnknown(data['batch_index']!, _batchIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_batchIndexMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('item_occurrence')) {
      context.handle(
        _itemOccurrenceMeta,
        itemOccurrence.isAcceptableOrUnknown(
          data['item_occurrence']!,
          _itemOccurrenceMeta,
        ),
      );
    }
    if (data.containsKey('content_revision')) {
      context.handle(
        _contentRevisionMeta,
        contentRevision.isAcceptableOrUnknown(
          data['content_revision']!,
          _contentRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentRevisionMeta);
    }
    if (data.containsKey('commit_ordinal')) {
      context.handle(
        _commitOrdinalMeta,
        commitOrdinal.isAcceptableOrUnknown(
          data['commit_ordinal']!,
          _commitOrdinalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commitOrdinalMeta);
    }
    if (data.containsKey('answered_at_us')) {
      context.handle(
        _answeredAtUsMeta,
        answeredAtUs.isAcceptableOrUnknown(
          data['answered_at_us']!,
          _answeredAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_answeredAtUsMeta);
    }
    if (data.containsKey('committed_at_us')) {
      context.handle(
        _committedAtUsMeta,
        committedAtUs.isAcceptableOrUnknown(
          data['committed_at_us']!,
          _committedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_committedAtUsMeta);
    }
    if (data.containsKey('answer_kind')) {
      context.handle(
        _answerKindMeta,
        answerKind.isAcceptableOrUnknown(data['answer_kind']!, _answerKindMeta),
      );
    } else if (isInserting) {
      context.missing(_answerKindMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('skill')) {
      context.handle(
        _skillMeta,
        skill.isAcceptableOrUnknown(data['skill']!, _skillMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('presentation')) {
      context.handle(
        _presentationMeta,
        presentation.isAcceptableOrUnknown(
          data['presentation']!,
          _presentationMeta,
        ),
      );
    }
    if (data.containsKey('assistance_mask')) {
      context.handle(
        _assistanceMaskMeta,
        assistanceMask.isAcceptableOrUnknown(
          data['assistance_mask']!,
          _assistanceMaskMeta,
        ),
      );
    }
    if (data.containsKey('content_state')) {
      context.handle(
        _contentStateMeta,
        contentState.isAcceptableOrUnknown(
          data['content_state']!,
          _contentStateMeta,
        ),
      );
    }
    if (data.containsKey('audio_source')) {
      context.handle(
        _audioSourceMeta,
        audioSource.isAcceptableOrUnknown(
          data['audio_source']!,
          _audioSourceMeta,
        ),
      );
    }
    if (data.containsKey('round')) {
      context.handle(
        _roundMeta,
        round.isAcceptableOrUnknown(data['round']!, _roundMeta),
      );
    }
    if (data.containsKey('after_debrief')) {
      context.handle(
        _afterDebriefMeta,
        afterDebrief.isAcceptableOrUnknown(
          data['after_debrief']!,
          _afterDebriefMeta,
        ),
      );
    }
    if (data.containsKey('teaching_exposed')) {
      context.handle(
        _teachingExposedMeta,
        teachingExposed.isAcceptableOrUnknown(
          data['teaching_exposed']!,
          _teachingExposedMeta,
        ),
      );
    }
    if (data.containsKey('selected_relation')) {
      context.handle(
        _selectedRelationMeta,
        selectedRelation.isAcceptableOrUnknown(
          data['selected_relation']!,
          _selectedRelationMeta,
        ),
      );
    }
    if (data.containsKey('expected_relation')) {
      context.handle(
        _expectedRelationMeta,
        expectedRelation.isAcceptableOrUnknown(
          data['expected_relation']!,
          _expectedRelationMeta,
        ),
      );
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    }
    if (data.containsKey('sentence_id')) {
      context.handle(
        _sentenceIdMeta,
        sentenceId.isAcceptableOrUnknown(data['sentence_id']!, _sentenceIdMeta),
      );
    }
    if (data.containsKey('annotation_hash')) {
      context.handle(
        _annotationHashMeta,
        annotationHash.isAcceptableOrUnknown(
          data['annotation_hash']!,
          _annotationHashMeta,
        ),
      );
    }
    if (data.containsKey('annotation_revision')) {
      context.handle(
        _annotationRevisionMeta,
        annotationRevision.isAcceptableOrUnknown(
          data['annotation_revision']!,
          _annotationRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  LearningAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningAttempt(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      runGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}run_generation'],
      )!,
      commandSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}command_sequence'],
      )!,
      batchIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}batch_index'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      itemOccurrence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_occurrence'],
      ),
      contentRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_revision'],
      )!,
      commitOrdinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}commit_ordinal'],
      )!,
      answeredAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}answered_at_us'],
      )!,
      committedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}committed_at_us'],
      )!,
      answerKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer_kind'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct'],
      )!,
      skill: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      presentation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}presentation'],
      ),
      assistanceMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}assistance_mask'],
      ),
      contentState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_state'],
      ),
      audioSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_source'],
      ),
      round: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round'],
      ),
      afterDebrief: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}after_debrief'],
      ),
      teachingExposed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}teaching_exposed'],
      ),
      selectedRelation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_relation'],
      ),
      expectedRelation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expected_relation'],
      ),
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      ),
      sentenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentence_id'],
      ),
      annotationHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}annotation_hash'],
      ),
      annotationRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}annotation_revision'],
      ),
    );
  }

  @override
  $LearningAttemptsTable createAlias(String alias) {
    return $LearningAttemptsTable(attachedDatabase, alias);
  }
}

class LearningAttempt extends DataClass implements Insertable<LearningAttempt> {
  final int scopeId;
  final String attemptId;
  final String activityId;
  final int runGeneration;
  final int commandSequence;
  final int batchIndex;
  final String? itemId;
  final int? itemOccurrence;
  final int contentRevision;
  final int commitOrdinal;
  final int answeredAtUs;
  final int committedAtUs;
  final String answerKind;
  final int correct;
  final String? skill;
  final String? origin;
  final String? presentation;
  final int? assistanceMask;
  final String? contentState;
  final String? audioSource;
  final int? round;
  final int? afterDebrief;
  final int? teachingExposed;
  final String? selectedRelation;
  final String? expectedRelation;
  final String? sectionId;
  final String? sentenceId;
  final String? annotationHash;
  final int? annotationRevision;
  const LearningAttempt({
    required this.scopeId,
    required this.attemptId,
    required this.activityId,
    required this.runGeneration,
    required this.commandSequence,
    required this.batchIndex,
    this.itemId,
    this.itemOccurrence,
    required this.contentRevision,
    required this.commitOrdinal,
    required this.answeredAtUs,
    required this.committedAtUs,
    required this.answerKind,
    required this.correct,
    this.skill,
    this.origin,
    this.presentation,
    this.assistanceMask,
    this.contentState,
    this.audioSource,
    this.round,
    this.afterDebrief,
    this.teachingExposed,
    this.selectedRelation,
    this.expectedRelation,
    this.sectionId,
    this.sentenceId,
    this.annotationHash,
    this.annotationRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['attempt_id'] = Variable<String>(attemptId);
    map['activity_id'] = Variable<String>(activityId);
    map['run_generation'] = Variable<int>(runGeneration);
    map['command_sequence'] = Variable<int>(commandSequence);
    map['batch_index'] = Variable<int>(batchIndex);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    if (!nullToAbsent || itemOccurrence != null) {
      map['item_occurrence'] = Variable<int>(itemOccurrence);
    }
    map['content_revision'] = Variable<int>(contentRevision);
    map['commit_ordinal'] = Variable<int>(commitOrdinal);
    map['answered_at_us'] = Variable<int>(answeredAtUs);
    map['committed_at_us'] = Variable<int>(committedAtUs);
    map['answer_kind'] = Variable<String>(answerKind);
    map['correct'] = Variable<int>(correct);
    if (!nullToAbsent || skill != null) {
      map['skill'] = Variable<String>(skill);
    }
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    if (!nullToAbsent || presentation != null) {
      map['presentation'] = Variable<String>(presentation);
    }
    if (!nullToAbsent || assistanceMask != null) {
      map['assistance_mask'] = Variable<int>(assistanceMask);
    }
    if (!nullToAbsent || contentState != null) {
      map['content_state'] = Variable<String>(contentState);
    }
    if (!nullToAbsent || audioSource != null) {
      map['audio_source'] = Variable<String>(audioSource);
    }
    if (!nullToAbsent || round != null) {
      map['round'] = Variable<int>(round);
    }
    if (!nullToAbsent || afterDebrief != null) {
      map['after_debrief'] = Variable<int>(afterDebrief);
    }
    if (!nullToAbsent || teachingExposed != null) {
      map['teaching_exposed'] = Variable<int>(teachingExposed);
    }
    if (!nullToAbsent || selectedRelation != null) {
      map['selected_relation'] = Variable<String>(selectedRelation);
    }
    if (!nullToAbsent || expectedRelation != null) {
      map['expected_relation'] = Variable<String>(expectedRelation);
    }
    if (!nullToAbsent || sectionId != null) {
      map['section_id'] = Variable<String>(sectionId);
    }
    if (!nullToAbsent || sentenceId != null) {
      map['sentence_id'] = Variable<String>(sentenceId);
    }
    if (!nullToAbsent || annotationHash != null) {
      map['annotation_hash'] = Variable<String>(annotationHash);
    }
    if (!nullToAbsent || annotationRevision != null) {
      map['annotation_revision'] = Variable<int>(annotationRevision);
    }
    return map;
  }

  LearningAttemptsCompanion toCompanion(bool nullToAbsent) {
    return LearningAttemptsCompanion(
      scopeId: Value(scopeId),
      attemptId: Value(attemptId),
      activityId: Value(activityId),
      runGeneration: Value(runGeneration),
      commandSequence: Value(commandSequence),
      batchIndex: Value(batchIndex),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      itemOccurrence: itemOccurrence == null && nullToAbsent
          ? const Value.absent()
          : Value(itemOccurrence),
      contentRevision: Value(contentRevision),
      commitOrdinal: Value(commitOrdinal),
      answeredAtUs: Value(answeredAtUs),
      committedAtUs: Value(committedAtUs),
      answerKind: Value(answerKind),
      correct: Value(correct),
      skill: skill == null && nullToAbsent
          ? const Value.absent()
          : Value(skill),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      presentation: presentation == null && nullToAbsent
          ? const Value.absent()
          : Value(presentation),
      assistanceMask: assistanceMask == null && nullToAbsent
          ? const Value.absent()
          : Value(assistanceMask),
      contentState: contentState == null && nullToAbsent
          ? const Value.absent()
          : Value(contentState),
      audioSource: audioSource == null && nullToAbsent
          ? const Value.absent()
          : Value(audioSource),
      round: round == null && nullToAbsent
          ? const Value.absent()
          : Value(round),
      afterDebrief: afterDebrief == null && nullToAbsent
          ? const Value.absent()
          : Value(afterDebrief),
      teachingExposed: teachingExposed == null && nullToAbsent
          ? const Value.absent()
          : Value(teachingExposed),
      selectedRelation: selectedRelation == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedRelation),
      expectedRelation: expectedRelation == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedRelation),
      sectionId: sectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionId),
      sentenceId: sentenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sentenceId),
      annotationHash: annotationHash == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationHash),
      annotationRevision: annotationRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationRevision),
    );
  }

  factory LearningAttempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningAttempt(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      attemptId: serializer.fromJson<String>(json['attemptId']),
      activityId: serializer.fromJson<String>(json['activityId']),
      runGeneration: serializer.fromJson<int>(json['runGeneration']),
      commandSequence: serializer.fromJson<int>(json['commandSequence']),
      batchIndex: serializer.fromJson<int>(json['batchIndex']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      itemOccurrence: serializer.fromJson<int?>(json['itemOccurrence']),
      contentRevision: serializer.fromJson<int>(json['contentRevision']),
      commitOrdinal: serializer.fromJson<int>(json['commitOrdinal']),
      answeredAtUs: serializer.fromJson<int>(json['answeredAtUs']),
      committedAtUs: serializer.fromJson<int>(json['committedAtUs']),
      answerKind: serializer.fromJson<String>(json['answerKind']),
      correct: serializer.fromJson<int>(json['correct']),
      skill: serializer.fromJson<String?>(json['skill']),
      origin: serializer.fromJson<String?>(json['origin']),
      presentation: serializer.fromJson<String?>(json['presentation']),
      assistanceMask: serializer.fromJson<int?>(json['assistanceMask']),
      contentState: serializer.fromJson<String?>(json['contentState']),
      audioSource: serializer.fromJson<String?>(json['audioSource']),
      round: serializer.fromJson<int?>(json['round']),
      afterDebrief: serializer.fromJson<int?>(json['afterDebrief']),
      teachingExposed: serializer.fromJson<int?>(json['teachingExposed']),
      selectedRelation: serializer.fromJson<String?>(json['selectedRelation']),
      expectedRelation: serializer.fromJson<String?>(json['expectedRelation']),
      sectionId: serializer.fromJson<String?>(json['sectionId']),
      sentenceId: serializer.fromJson<String?>(json['sentenceId']),
      annotationHash: serializer.fromJson<String?>(json['annotationHash']),
      annotationRevision: serializer.fromJson<int?>(json['annotationRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'attemptId': serializer.toJson<String>(attemptId),
      'activityId': serializer.toJson<String>(activityId),
      'runGeneration': serializer.toJson<int>(runGeneration),
      'commandSequence': serializer.toJson<int>(commandSequence),
      'batchIndex': serializer.toJson<int>(batchIndex),
      'itemId': serializer.toJson<String?>(itemId),
      'itemOccurrence': serializer.toJson<int?>(itemOccurrence),
      'contentRevision': serializer.toJson<int>(contentRevision),
      'commitOrdinal': serializer.toJson<int>(commitOrdinal),
      'answeredAtUs': serializer.toJson<int>(answeredAtUs),
      'committedAtUs': serializer.toJson<int>(committedAtUs),
      'answerKind': serializer.toJson<String>(answerKind),
      'correct': serializer.toJson<int>(correct),
      'skill': serializer.toJson<String?>(skill),
      'origin': serializer.toJson<String?>(origin),
      'presentation': serializer.toJson<String?>(presentation),
      'assistanceMask': serializer.toJson<int?>(assistanceMask),
      'contentState': serializer.toJson<String?>(contentState),
      'audioSource': serializer.toJson<String?>(audioSource),
      'round': serializer.toJson<int?>(round),
      'afterDebrief': serializer.toJson<int?>(afterDebrief),
      'teachingExposed': serializer.toJson<int?>(teachingExposed),
      'selectedRelation': serializer.toJson<String?>(selectedRelation),
      'expectedRelation': serializer.toJson<String?>(expectedRelation),
      'sectionId': serializer.toJson<String?>(sectionId),
      'sentenceId': serializer.toJson<String?>(sentenceId),
      'annotationHash': serializer.toJson<String?>(annotationHash),
      'annotationRevision': serializer.toJson<int?>(annotationRevision),
    };
  }

  LearningAttempt copyWith({
    int? scopeId,
    String? attemptId,
    String? activityId,
    int? runGeneration,
    int? commandSequence,
    int? batchIndex,
    Value<String?> itemId = const Value.absent(),
    Value<int?> itemOccurrence = const Value.absent(),
    int? contentRevision,
    int? commitOrdinal,
    int? answeredAtUs,
    int? committedAtUs,
    String? answerKind,
    int? correct,
    Value<String?> skill = const Value.absent(),
    Value<String?> origin = const Value.absent(),
    Value<String?> presentation = const Value.absent(),
    Value<int?> assistanceMask = const Value.absent(),
    Value<String?> contentState = const Value.absent(),
    Value<String?> audioSource = const Value.absent(),
    Value<int?> round = const Value.absent(),
    Value<int?> afterDebrief = const Value.absent(),
    Value<int?> teachingExposed = const Value.absent(),
    Value<String?> selectedRelation = const Value.absent(),
    Value<String?> expectedRelation = const Value.absent(),
    Value<String?> sectionId = const Value.absent(),
    Value<String?> sentenceId = const Value.absent(),
    Value<String?> annotationHash = const Value.absent(),
    Value<int?> annotationRevision = const Value.absent(),
  }) => LearningAttempt(
    scopeId: scopeId ?? this.scopeId,
    attemptId: attemptId ?? this.attemptId,
    activityId: activityId ?? this.activityId,
    runGeneration: runGeneration ?? this.runGeneration,
    commandSequence: commandSequence ?? this.commandSequence,
    batchIndex: batchIndex ?? this.batchIndex,
    itemId: itemId.present ? itemId.value : this.itemId,
    itemOccurrence: itemOccurrence.present
        ? itemOccurrence.value
        : this.itemOccurrence,
    contentRevision: contentRevision ?? this.contentRevision,
    commitOrdinal: commitOrdinal ?? this.commitOrdinal,
    answeredAtUs: answeredAtUs ?? this.answeredAtUs,
    committedAtUs: committedAtUs ?? this.committedAtUs,
    answerKind: answerKind ?? this.answerKind,
    correct: correct ?? this.correct,
    skill: skill.present ? skill.value : this.skill,
    origin: origin.present ? origin.value : this.origin,
    presentation: presentation.present ? presentation.value : this.presentation,
    assistanceMask: assistanceMask.present
        ? assistanceMask.value
        : this.assistanceMask,
    contentState: contentState.present ? contentState.value : this.contentState,
    audioSource: audioSource.present ? audioSource.value : this.audioSource,
    round: round.present ? round.value : this.round,
    afterDebrief: afterDebrief.present ? afterDebrief.value : this.afterDebrief,
    teachingExposed: teachingExposed.present
        ? teachingExposed.value
        : this.teachingExposed,
    selectedRelation: selectedRelation.present
        ? selectedRelation.value
        : this.selectedRelation,
    expectedRelation: expectedRelation.present
        ? expectedRelation.value
        : this.expectedRelation,
    sectionId: sectionId.present ? sectionId.value : this.sectionId,
    sentenceId: sentenceId.present ? sentenceId.value : this.sentenceId,
    annotationHash: annotationHash.present
        ? annotationHash.value
        : this.annotationHash,
    annotationRevision: annotationRevision.present
        ? annotationRevision.value
        : this.annotationRevision,
  );
  LearningAttempt copyWithCompanion(LearningAttemptsCompanion data) {
    return LearningAttempt(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      runGeneration: data.runGeneration.present
          ? data.runGeneration.value
          : this.runGeneration,
      commandSequence: data.commandSequence.present
          ? data.commandSequence.value
          : this.commandSequence,
      batchIndex: data.batchIndex.present
          ? data.batchIndex.value
          : this.batchIndex,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      itemOccurrence: data.itemOccurrence.present
          ? data.itemOccurrence.value
          : this.itemOccurrence,
      contentRevision: data.contentRevision.present
          ? data.contentRevision.value
          : this.contentRevision,
      commitOrdinal: data.commitOrdinal.present
          ? data.commitOrdinal.value
          : this.commitOrdinal,
      answeredAtUs: data.answeredAtUs.present
          ? data.answeredAtUs.value
          : this.answeredAtUs,
      committedAtUs: data.committedAtUs.present
          ? data.committedAtUs.value
          : this.committedAtUs,
      answerKind: data.answerKind.present
          ? data.answerKind.value
          : this.answerKind,
      correct: data.correct.present ? data.correct.value : this.correct,
      skill: data.skill.present ? data.skill.value : this.skill,
      origin: data.origin.present ? data.origin.value : this.origin,
      presentation: data.presentation.present
          ? data.presentation.value
          : this.presentation,
      assistanceMask: data.assistanceMask.present
          ? data.assistanceMask.value
          : this.assistanceMask,
      contentState: data.contentState.present
          ? data.contentState.value
          : this.contentState,
      audioSource: data.audioSource.present
          ? data.audioSource.value
          : this.audioSource,
      round: data.round.present ? data.round.value : this.round,
      afterDebrief: data.afterDebrief.present
          ? data.afterDebrief.value
          : this.afterDebrief,
      teachingExposed: data.teachingExposed.present
          ? data.teachingExposed.value
          : this.teachingExposed,
      selectedRelation: data.selectedRelation.present
          ? data.selectedRelation.value
          : this.selectedRelation,
      expectedRelation: data.expectedRelation.present
          ? data.expectedRelation.value
          : this.expectedRelation,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      sentenceId: data.sentenceId.present
          ? data.sentenceId.value
          : this.sentenceId,
      annotationHash: data.annotationHash.present
          ? data.annotationHash.value
          : this.annotationHash,
      annotationRevision: data.annotationRevision.present
          ? data.annotationRevision.value
          : this.annotationRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningAttempt(')
          ..write('scopeId: $scopeId, ')
          ..write('attemptId: $attemptId, ')
          ..write('activityId: $activityId, ')
          ..write('runGeneration: $runGeneration, ')
          ..write('commandSequence: $commandSequence, ')
          ..write('batchIndex: $batchIndex, ')
          ..write('itemId: $itemId, ')
          ..write('itemOccurrence: $itemOccurrence, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('commitOrdinal: $commitOrdinal, ')
          ..write('answeredAtUs: $answeredAtUs, ')
          ..write('committedAtUs: $committedAtUs, ')
          ..write('answerKind: $answerKind, ')
          ..write('correct: $correct, ')
          ..write('skill: $skill, ')
          ..write('origin: $origin, ')
          ..write('presentation: $presentation, ')
          ..write('assistanceMask: $assistanceMask, ')
          ..write('contentState: $contentState, ')
          ..write('audioSource: $audioSource, ')
          ..write('round: $round, ')
          ..write('afterDebrief: $afterDebrief, ')
          ..write('teachingExposed: $teachingExposed, ')
          ..write('selectedRelation: $selectedRelation, ')
          ..write('expectedRelation: $expectedRelation, ')
          ..write('sectionId: $sectionId, ')
          ..write('sentenceId: $sentenceId, ')
          ..write('annotationHash: $annotationHash, ')
          ..write('annotationRevision: $annotationRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    scopeId,
    attemptId,
    activityId,
    runGeneration,
    commandSequence,
    batchIndex,
    itemId,
    itemOccurrence,
    contentRevision,
    commitOrdinal,
    answeredAtUs,
    committedAtUs,
    answerKind,
    correct,
    skill,
    origin,
    presentation,
    assistanceMask,
    contentState,
    audioSource,
    round,
    afterDebrief,
    teachingExposed,
    selectedRelation,
    expectedRelation,
    sectionId,
    sentenceId,
    annotationHash,
    annotationRevision,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningAttempt &&
          other.scopeId == this.scopeId &&
          other.attemptId == this.attemptId &&
          other.activityId == this.activityId &&
          other.runGeneration == this.runGeneration &&
          other.commandSequence == this.commandSequence &&
          other.batchIndex == this.batchIndex &&
          other.itemId == this.itemId &&
          other.itemOccurrence == this.itemOccurrence &&
          other.contentRevision == this.contentRevision &&
          other.commitOrdinal == this.commitOrdinal &&
          other.answeredAtUs == this.answeredAtUs &&
          other.committedAtUs == this.committedAtUs &&
          other.answerKind == this.answerKind &&
          other.correct == this.correct &&
          other.skill == this.skill &&
          other.origin == this.origin &&
          other.presentation == this.presentation &&
          other.assistanceMask == this.assistanceMask &&
          other.contentState == this.contentState &&
          other.audioSource == this.audioSource &&
          other.round == this.round &&
          other.afterDebrief == this.afterDebrief &&
          other.teachingExposed == this.teachingExposed &&
          other.selectedRelation == this.selectedRelation &&
          other.expectedRelation == this.expectedRelation &&
          other.sectionId == this.sectionId &&
          other.sentenceId == this.sentenceId &&
          other.annotationHash == this.annotationHash &&
          other.annotationRevision == this.annotationRevision);
}

class LearningAttemptsCompanion extends UpdateCompanion<LearningAttempt> {
  final Value<int> scopeId;
  final Value<String> attemptId;
  final Value<String> activityId;
  final Value<int> runGeneration;
  final Value<int> commandSequence;
  final Value<int> batchIndex;
  final Value<String?> itemId;
  final Value<int?> itemOccurrence;
  final Value<int> contentRevision;
  final Value<int> commitOrdinal;
  final Value<int> answeredAtUs;
  final Value<int> committedAtUs;
  final Value<String> answerKind;
  final Value<int> correct;
  final Value<String?> skill;
  final Value<String?> origin;
  final Value<String?> presentation;
  final Value<int?> assistanceMask;
  final Value<String?> contentState;
  final Value<String?> audioSource;
  final Value<int?> round;
  final Value<int?> afterDebrief;
  final Value<int?> teachingExposed;
  final Value<String?> selectedRelation;
  final Value<String?> expectedRelation;
  final Value<String?> sectionId;
  final Value<String?> sentenceId;
  final Value<String?> annotationHash;
  final Value<int?> annotationRevision;
  final Value<int> rowid;
  const LearningAttemptsCompanion({
    this.scopeId = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.activityId = const Value.absent(),
    this.runGeneration = const Value.absent(),
    this.commandSequence = const Value.absent(),
    this.batchIndex = const Value.absent(),
    this.itemId = const Value.absent(),
    this.itemOccurrence = const Value.absent(),
    this.contentRevision = const Value.absent(),
    this.commitOrdinal = const Value.absent(),
    this.answeredAtUs = const Value.absent(),
    this.committedAtUs = const Value.absent(),
    this.answerKind = const Value.absent(),
    this.correct = const Value.absent(),
    this.skill = const Value.absent(),
    this.origin = const Value.absent(),
    this.presentation = const Value.absent(),
    this.assistanceMask = const Value.absent(),
    this.contentState = const Value.absent(),
    this.audioSource = const Value.absent(),
    this.round = const Value.absent(),
    this.afterDebrief = const Value.absent(),
    this.teachingExposed = const Value.absent(),
    this.selectedRelation = const Value.absent(),
    this.expectedRelation = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.sentenceId = const Value.absent(),
    this.annotationHash = const Value.absent(),
    this.annotationRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningAttemptsCompanion.insert({
    required int scopeId,
    required String attemptId,
    required String activityId,
    required int runGeneration,
    required int commandSequence,
    required int batchIndex,
    this.itemId = const Value.absent(),
    this.itemOccurrence = const Value.absent(),
    required int contentRevision,
    required int commitOrdinal,
    required int answeredAtUs,
    required int committedAtUs,
    required String answerKind,
    required int correct,
    this.skill = const Value.absent(),
    this.origin = const Value.absent(),
    this.presentation = const Value.absent(),
    this.assistanceMask = const Value.absent(),
    this.contentState = const Value.absent(),
    this.audioSource = const Value.absent(),
    this.round = const Value.absent(),
    this.afterDebrief = const Value.absent(),
    this.teachingExposed = const Value.absent(),
    this.selectedRelation = const Value.absent(),
    this.expectedRelation = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.sentenceId = const Value.absent(),
    this.annotationHash = const Value.absent(),
    this.annotationRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       attemptId = Value(attemptId),
       activityId = Value(activityId),
       runGeneration = Value(runGeneration),
       commandSequence = Value(commandSequence),
       batchIndex = Value(batchIndex),
       contentRevision = Value(contentRevision),
       commitOrdinal = Value(commitOrdinal),
       answeredAtUs = Value(answeredAtUs),
       committedAtUs = Value(committedAtUs),
       answerKind = Value(answerKind),
       correct = Value(correct);
  static Insertable<LearningAttempt> custom({
    Expression<int>? scopeId,
    Expression<String>? attemptId,
    Expression<String>? activityId,
    Expression<int>? runGeneration,
    Expression<int>? commandSequence,
    Expression<int>? batchIndex,
    Expression<String>? itemId,
    Expression<int>? itemOccurrence,
    Expression<int>? contentRevision,
    Expression<int>? commitOrdinal,
    Expression<int>? answeredAtUs,
    Expression<int>? committedAtUs,
    Expression<String>? answerKind,
    Expression<int>? correct,
    Expression<String>? skill,
    Expression<String>? origin,
    Expression<String>? presentation,
    Expression<int>? assistanceMask,
    Expression<String>? contentState,
    Expression<String>? audioSource,
    Expression<int>? round,
    Expression<int>? afterDebrief,
    Expression<int>? teachingExposed,
    Expression<String>? selectedRelation,
    Expression<String>? expectedRelation,
    Expression<String>? sectionId,
    Expression<String>? sentenceId,
    Expression<String>? annotationHash,
    Expression<int>? annotationRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (attemptId != null) 'attempt_id': attemptId,
      if (activityId != null) 'activity_id': activityId,
      if (runGeneration != null) 'run_generation': runGeneration,
      if (commandSequence != null) 'command_sequence': commandSequence,
      if (batchIndex != null) 'batch_index': batchIndex,
      if (itemId != null) 'item_id': itemId,
      if (itemOccurrence != null) 'item_occurrence': itemOccurrence,
      if (contentRevision != null) 'content_revision': contentRevision,
      if (commitOrdinal != null) 'commit_ordinal': commitOrdinal,
      if (answeredAtUs != null) 'answered_at_us': answeredAtUs,
      if (committedAtUs != null) 'committed_at_us': committedAtUs,
      if (answerKind != null) 'answer_kind': answerKind,
      if (correct != null) 'correct': correct,
      if (skill != null) 'skill': skill,
      if (origin != null) 'origin': origin,
      if (presentation != null) 'presentation': presentation,
      if (assistanceMask != null) 'assistance_mask': assistanceMask,
      if (contentState != null) 'content_state': contentState,
      if (audioSource != null) 'audio_source': audioSource,
      if (round != null) 'round': round,
      if (afterDebrief != null) 'after_debrief': afterDebrief,
      if (teachingExposed != null) 'teaching_exposed': teachingExposed,
      if (selectedRelation != null) 'selected_relation': selectedRelation,
      if (expectedRelation != null) 'expected_relation': expectedRelation,
      if (sectionId != null) 'section_id': sectionId,
      if (sentenceId != null) 'sentence_id': sentenceId,
      if (annotationHash != null) 'annotation_hash': annotationHash,
      if (annotationRevision != null) 'annotation_revision': annotationRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningAttemptsCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? attemptId,
    Value<String>? activityId,
    Value<int>? runGeneration,
    Value<int>? commandSequence,
    Value<int>? batchIndex,
    Value<String?>? itemId,
    Value<int?>? itemOccurrence,
    Value<int>? contentRevision,
    Value<int>? commitOrdinal,
    Value<int>? answeredAtUs,
    Value<int>? committedAtUs,
    Value<String>? answerKind,
    Value<int>? correct,
    Value<String?>? skill,
    Value<String?>? origin,
    Value<String?>? presentation,
    Value<int?>? assistanceMask,
    Value<String?>? contentState,
    Value<String?>? audioSource,
    Value<int?>? round,
    Value<int?>? afterDebrief,
    Value<int?>? teachingExposed,
    Value<String?>? selectedRelation,
    Value<String?>? expectedRelation,
    Value<String?>? sectionId,
    Value<String?>? sentenceId,
    Value<String?>? annotationHash,
    Value<int?>? annotationRevision,
    Value<int>? rowid,
  }) {
    return LearningAttemptsCompanion(
      scopeId: scopeId ?? this.scopeId,
      attemptId: attemptId ?? this.attemptId,
      activityId: activityId ?? this.activityId,
      runGeneration: runGeneration ?? this.runGeneration,
      commandSequence: commandSequence ?? this.commandSequence,
      batchIndex: batchIndex ?? this.batchIndex,
      itemId: itemId ?? this.itemId,
      itemOccurrence: itemOccurrence ?? this.itemOccurrence,
      contentRevision: contentRevision ?? this.contentRevision,
      commitOrdinal: commitOrdinal ?? this.commitOrdinal,
      answeredAtUs: answeredAtUs ?? this.answeredAtUs,
      committedAtUs: committedAtUs ?? this.committedAtUs,
      answerKind: answerKind ?? this.answerKind,
      correct: correct ?? this.correct,
      skill: skill ?? this.skill,
      origin: origin ?? this.origin,
      presentation: presentation ?? this.presentation,
      assistanceMask: assistanceMask ?? this.assistanceMask,
      contentState: contentState ?? this.contentState,
      audioSource: audioSource ?? this.audioSource,
      round: round ?? this.round,
      afterDebrief: afterDebrief ?? this.afterDebrief,
      teachingExposed: teachingExposed ?? this.teachingExposed,
      selectedRelation: selectedRelation ?? this.selectedRelation,
      expectedRelation: expectedRelation ?? this.expectedRelation,
      sectionId: sectionId ?? this.sectionId,
      sentenceId: sentenceId ?? this.sentenceId,
      annotationHash: annotationHash ?? this.annotationHash,
      annotationRevision: annotationRevision ?? this.annotationRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (runGeneration.present) {
      map['run_generation'] = Variable<int>(runGeneration.value);
    }
    if (commandSequence.present) {
      map['command_sequence'] = Variable<int>(commandSequence.value);
    }
    if (batchIndex.present) {
      map['batch_index'] = Variable<int>(batchIndex.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (itemOccurrence.present) {
      map['item_occurrence'] = Variable<int>(itemOccurrence.value);
    }
    if (contentRevision.present) {
      map['content_revision'] = Variable<int>(contentRevision.value);
    }
    if (commitOrdinal.present) {
      map['commit_ordinal'] = Variable<int>(commitOrdinal.value);
    }
    if (answeredAtUs.present) {
      map['answered_at_us'] = Variable<int>(answeredAtUs.value);
    }
    if (committedAtUs.present) {
      map['committed_at_us'] = Variable<int>(committedAtUs.value);
    }
    if (answerKind.present) {
      map['answer_kind'] = Variable<String>(answerKind.value);
    }
    if (correct.present) {
      map['correct'] = Variable<int>(correct.value);
    }
    if (skill.present) {
      map['skill'] = Variable<String>(skill.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (presentation.present) {
      map['presentation'] = Variable<String>(presentation.value);
    }
    if (assistanceMask.present) {
      map['assistance_mask'] = Variable<int>(assistanceMask.value);
    }
    if (contentState.present) {
      map['content_state'] = Variable<String>(contentState.value);
    }
    if (audioSource.present) {
      map['audio_source'] = Variable<String>(audioSource.value);
    }
    if (round.present) {
      map['round'] = Variable<int>(round.value);
    }
    if (afterDebrief.present) {
      map['after_debrief'] = Variable<int>(afterDebrief.value);
    }
    if (teachingExposed.present) {
      map['teaching_exposed'] = Variable<int>(teachingExposed.value);
    }
    if (selectedRelation.present) {
      map['selected_relation'] = Variable<String>(selectedRelation.value);
    }
    if (expectedRelation.present) {
      map['expected_relation'] = Variable<String>(expectedRelation.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (sentenceId.present) {
      map['sentence_id'] = Variable<String>(sentenceId.value);
    }
    if (annotationHash.present) {
      map['annotation_hash'] = Variable<String>(annotationHash.value);
    }
    if (annotationRevision.present) {
      map['annotation_revision'] = Variable<int>(annotationRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningAttemptsCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('attemptId: $attemptId, ')
          ..write('activityId: $activityId, ')
          ..write('runGeneration: $runGeneration, ')
          ..write('commandSequence: $commandSequence, ')
          ..write('batchIndex: $batchIndex, ')
          ..write('itemId: $itemId, ')
          ..write('itemOccurrence: $itemOccurrence, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('commitOrdinal: $commitOrdinal, ')
          ..write('answeredAtUs: $answeredAtUs, ')
          ..write('committedAtUs: $committedAtUs, ')
          ..write('answerKind: $answerKind, ')
          ..write('correct: $correct, ')
          ..write('skill: $skill, ')
          ..write('origin: $origin, ')
          ..write('presentation: $presentation, ')
          ..write('assistanceMask: $assistanceMask, ')
          ..write('contentState: $contentState, ')
          ..write('audioSource: $audioSource, ')
          ..write('round: $round, ')
          ..write('afterDebrief: $afterDebrief, ')
          ..write('teachingExposed: $teachingExposed, ')
          ..write('selectedRelation: $selectedRelation, ')
          ..write('expectedRelation: $expectedRelation, ')
          ..write('sectionId: $sectionId, ')
          ..write('sentenceId: $sentenceId, ')
          ..write('annotationHash: $annotationHash, ')
          ..write('annotationRevision: $annotationRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningAttemptValuesTable extends LearningAttemptValues
    with TableInfo<$LearningAttemptValuesTable, LearningAttemptValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningAttemptValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueTypeMeta = const VerificationMeta(
    'valueType',
  );
  @override
  late final GeneratedColumn<String> valueType = GeneratedColumn<String>(
    'value_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textValueMeta = const VerificationMeta(
    'textValue',
  );
  @override
  late final GeneratedColumn<String> textValue = GeneratedColumn<String>(
    'text_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intValueMeta = const VerificationMeta(
    'intValue',
  );
  @override
  late final GeneratedColumn<int> intValue = GeneratedColumn<int>(
    'int_value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _boolValueMeta = const VerificationMeta(
    'boolValue',
  );
  @override
  late final GeneratedColumn<int> boolValue = GeneratedColumn<int>(
    'bool_value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    attemptId,
    field,
    ordinal,
    valueType,
    textValue,
    intValue,
    boolValue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_attempt_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningAttemptValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    if (data.containsKey('field')) {
      context.handle(
        _fieldMeta,
        field.isAcceptableOrUnknown(data['field']!, _fieldMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('value_type')) {
      context.handle(
        _valueTypeMeta,
        valueType.isAcceptableOrUnknown(data['value_type']!, _valueTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_valueTypeMeta);
    }
    if (data.containsKey('text_value')) {
      context.handle(
        _textValueMeta,
        textValue.isAcceptableOrUnknown(data['text_value']!, _textValueMeta),
      );
    }
    if (data.containsKey('int_value')) {
      context.handle(
        _intValueMeta,
        intValue.isAcceptableOrUnknown(data['int_value']!, _intValueMeta),
      );
    }
    if (data.containsKey('bool_value')) {
      context.handle(
        _boolValueMeta,
        boolValue.isAcceptableOrUnknown(data['bool_value']!, _boolValueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scopeId, attemptId, field, ordinal};
  @override
  LearningAttemptValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningAttemptValue(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      )!,
      field: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      valueType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_type'],
      )!,
      textValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_value'],
      ),
      intValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}int_value'],
      ),
      boolValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bool_value'],
      ),
    );
  }

  @override
  $LearningAttemptValuesTable createAlias(String alias) {
    return $LearningAttemptValuesTable(attachedDatabase, alias);
  }
}

class LearningAttemptValue extends DataClass
    implements Insertable<LearningAttemptValue> {
  final int scopeId;
  final String attemptId;
  final String field;
  final int ordinal;
  final String valueType;
  final String? textValue;
  final int? intValue;
  final int? boolValue;
  const LearningAttemptValue({
    required this.scopeId,
    required this.attemptId,
    required this.field,
    required this.ordinal,
    required this.valueType,
    this.textValue,
    this.intValue,
    this.boolValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['attempt_id'] = Variable<String>(attemptId);
    map['field'] = Variable<String>(field);
    map['ordinal'] = Variable<int>(ordinal);
    map['value_type'] = Variable<String>(valueType);
    if (!nullToAbsent || textValue != null) {
      map['text_value'] = Variable<String>(textValue);
    }
    if (!nullToAbsent || intValue != null) {
      map['int_value'] = Variable<int>(intValue);
    }
    if (!nullToAbsent || boolValue != null) {
      map['bool_value'] = Variable<int>(boolValue);
    }
    return map;
  }

  LearningAttemptValuesCompanion toCompanion(bool nullToAbsent) {
    return LearningAttemptValuesCompanion(
      scopeId: Value(scopeId),
      attemptId: Value(attemptId),
      field: Value(field),
      ordinal: Value(ordinal),
      valueType: Value(valueType),
      textValue: textValue == null && nullToAbsent
          ? const Value.absent()
          : Value(textValue),
      intValue: intValue == null && nullToAbsent
          ? const Value.absent()
          : Value(intValue),
      boolValue: boolValue == null && nullToAbsent
          ? const Value.absent()
          : Value(boolValue),
    );
  }

  factory LearningAttemptValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningAttemptValue(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      attemptId: serializer.fromJson<String>(json['attemptId']),
      field: serializer.fromJson<String>(json['field']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      valueType: serializer.fromJson<String>(json['valueType']),
      textValue: serializer.fromJson<String?>(json['textValue']),
      intValue: serializer.fromJson<int?>(json['intValue']),
      boolValue: serializer.fromJson<int?>(json['boolValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'attemptId': serializer.toJson<String>(attemptId),
      'field': serializer.toJson<String>(field),
      'ordinal': serializer.toJson<int>(ordinal),
      'valueType': serializer.toJson<String>(valueType),
      'textValue': serializer.toJson<String?>(textValue),
      'intValue': serializer.toJson<int?>(intValue),
      'boolValue': serializer.toJson<int?>(boolValue),
    };
  }

  LearningAttemptValue copyWith({
    int? scopeId,
    String? attemptId,
    String? field,
    int? ordinal,
    String? valueType,
    Value<String?> textValue = const Value.absent(),
    Value<int?> intValue = const Value.absent(),
    Value<int?> boolValue = const Value.absent(),
  }) => LearningAttemptValue(
    scopeId: scopeId ?? this.scopeId,
    attemptId: attemptId ?? this.attemptId,
    field: field ?? this.field,
    ordinal: ordinal ?? this.ordinal,
    valueType: valueType ?? this.valueType,
    textValue: textValue.present ? textValue.value : this.textValue,
    intValue: intValue.present ? intValue.value : this.intValue,
    boolValue: boolValue.present ? boolValue.value : this.boolValue,
  );
  LearningAttemptValue copyWithCompanion(LearningAttemptValuesCompanion data) {
    return LearningAttemptValue(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      field: data.field.present ? data.field.value : this.field,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      valueType: data.valueType.present ? data.valueType.value : this.valueType,
      textValue: data.textValue.present ? data.textValue.value : this.textValue,
      intValue: data.intValue.present ? data.intValue.value : this.intValue,
      boolValue: data.boolValue.present ? data.boolValue.value : this.boolValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningAttemptValue(')
          ..write('scopeId: $scopeId, ')
          ..write('attemptId: $attemptId, ')
          ..write('field: $field, ')
          ..write('ordinal: $ordinal, ')
          ..write('valueType: $valueType, ')
          ..write('textValue: $textValue, ')
          ..write('intValue: $intValue, ')
          ..write('boolValue: $boolValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    attemptId,
    field,
    ordinal,
    valueType,
    textValue,
    intValue,
    boolValue,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningAttemptValue &&
          other.scopeId == this.scopeId &&
          other.attemptId == this.attemptId &&
          other.field == this.field &&
          other.ordinal == this.ordinal &&
          other.valueType == this.valueType &&
          other.textValue == this.textValue &&
          other.intValue == this.intValue &&
          other.boolValue == this.boolValue);
}

class LearningAttemptValuesCompanion
    extends UpdateCompanion<LearningAttemptValue> {
  final Value<int> scopeId;
  final Value<String> attemptId;
  final Value<String> field;
  final Value<int> ordinal;
  final Value<String> valueType;
  final Value<String?> textValue;
  final Value<int?> intValue;
  final Value<int?> boolValue;
  final Value<int> rowid;
  const LearningAttemptValuesCompanion({
    this.scopeId = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.field = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.valueType = const Value.absent(),
    this.textValue = const Value.absent(),
    this.intValue = const Value.absent(),
    this.boolValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningAttemptValuesCompanion.insert({
    required int scopeId,
    required String attemptId,
    required String field,
    required int ordinal,
    required String valueType,
    this.textValue = const Value.absent(),
    this.intValue = const Value.absent(),
    this.boolValue = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       attemptId = Value(attemptId),
       field = Value(field),
       ordinal = Value(ordinal),
       valueType = Value(valueType);
  static Insertable<LearningAttemptValue> custom({
    Expression<int>? scopeId,
    Expression<String>? attemptId,
    Expression<String>? field,
    Expression<int>? ordinal,
    Expression<String>? valueType,
    Expression<String>? textValue,
    Expression<int>? intValue,
    Expression<int>? boolValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (attemptId != null) 'attempt_id': attemptId,
      if (field != null) 'field': field,
      if (ordinal != null) 'ordinal': ordinal,
      if (valueType != null) 'value_type': valueType,
      if (textValue != null) 'text_value': textValue,
      if (intValue != null) 'int_value': intValue,
      if (boolValue != null) 'bool_value': boolValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningAttemptValuesCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? attemptId,
    Value<String>? field,
    Value<int>? ordinal,
    Value<String>? valueType,
    Value<String?>? textValue,
    Value<int?>? intValue,
    Value<int?>? boolValue,
    Value<int>? rowid,
  }) {
    return LearningAttemptValuesCompanion(
      scopeId: scopeId ?? this.scopeId,
      attemptId: attemptId ?? this.attemptId,
      field: field ?? this.field,
      ordinal: ordinal ?? this.ordinal,
      valueType: valueType ?? this.valueType,
      textValue: textValue ?? this.textValue,
      intValue: intValue ?? this.intValue,
      boolValue: boolValue ?? this.boolValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (valueType.present) {
      map['value_type'] = Variable<String>(valueType.value);
    }
    if (textValue.present) {
      map['text_value'] = Variable<String>(textValue.value);
    }
    if (intValue.present) {
      map['int_value'] = Variable<int>(intValue.value);
    }
    if (boolValue.present) {
      map['bool_value'] = Variable<int>(boolValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningAttemptValuesCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('attemptId: $attemptId, ')
          ..write('field: $field, ')
          ..write('ordinal: $ordinal, ')
          ..write('valueType: $valueType, ')
          ..write('textValue: $textValue, ')
          ..write('intValue: $intValue, ')
          ..write('boolValue: $boolValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningAttemptEvidenceTable extends LearningAttemptEvidence
    with TableInfo<$LearningAttemptEvidenceTable, LearningAttemptEvidenceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningAttemptEvidenceTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceIndexMeta = const VerificationMeta(
    'evidenceIndex',
  );
  @override
  late final GeneratedColumn<int> evidenceIndex = GeneratedColumn<int>(
    'evidence_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceKindMeta = const VerificationMeta(
    'evidenceKind',
  );
  @override
  late final GeneratedColumn<String> evidenceKind = GeneratedColumn<String>(
    'evidence_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceIdMeta = const VerificationMeta(
    'referenceId',
  );
  @override
  late final GeneratedColumn<String> referenceId = GeneratedColumn<String>(
    'reference_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _runGenerationMeta = const VerificationMeta(
    'runGeneration',
  );
  @override
  late final GeneratedColumn<int> runGeneration = GeneratedColumn<int>(
    'run_generation',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roundMeta = const VerificationMeta('round');
  @override
  late final GeneratedColumn<int> round = GeneratedColumn<int>(
    'round',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pairIdMeta = const VerificationMeta('pairId');
  @override
  late final GeneratedColumn<String> pairId = GeneratedColumn<String>(
    'pair_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uiGenerationMeta = const VerificationMeta(
    'uiGeneration',
  );
  @override
  late final GeneratedColumn<int> uiGeneration = GeneratedColumn<int>(
    'ui_generation',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentenceIdMeta = const VerificationMeta(
    'sentenceId',
  );
  @override
  late final GeneratedColumn<String> sentenceId = GeneratedColumn<String>(
    'sentence_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioRefIdMeta = const VerificationMeta(
    'audioRefId',
  );
  @override
  late final GeneratedColumn<String> audioRefId = GeneratedColumn<String>(
    'audio_ref_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotationHashMeta = const VerificationMeta(
    'annotationHash',
  );
  @override
  late final GeneratedColumn<String> annotationHash = GeneratedColumn<String>(
    'annotation_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotationRevisionMeta =
      const VerificationMeta('annotationRevision');
  @override
  late final GeneratedColumn<int> annotationRevision = GeneratedColumn<int>(
    'annotation_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentRevisionMeta = const VerificationMeta(
    'contentRevision',
  );
  @override
  late final GeneratedColumn<int> contentRevision = GeneratedColumn<int>(
    'content_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    attemptId,
    evidenceIndex,
    evidenceKind,
    slot,
    referenceId,
    outcome,
    source,
    activityId,
    runGeneration,
    round,
    pairId,
    uiGeneration,
    sectionId,
    itemId,
    sentenceId,
    audioRefId,
    annotationHash,
    annotationRevision,
    contentRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_attempt_evidence';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningAttemptEvidenceData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    if (data.containsKey('evidence_index')) {
      context.handle(
        _evidenceIndexMeta,
        evidenceIndex.isAcceptableOrUnknown(
          data['evidence_index']!,
          _evidenceIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_evidenceIndexMeta);
    }
    if (data.containsKey('evidence_kind')) {
      context.handle(
        _evidenceKindMeta,
        evidenceKind.isAcceptableOrUnknown(
          data['evidence_kind']!,
          _evidenceKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_evidenceKindMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    }
    if (data.containsKey('reference_id')) {
      context.handle(
        _referenceIdMeta,
        referenceId.isAcceptableOrUnknown(
          data['reference_id']!,
          _referenceIdMeta,
        ),
      );
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    }
    if (data.containsKey('run_generation')) {
      context.handle(
        _runGenerationMeta,
        runGeneration.isAcceptableOrUnknown(
          data['run_generation']!,
          _runGenerationMeta,
        ),
      );
    }
    if (data.containsKey('round')) {
      context.handle(
        _roundMeta,
        round.isAcceptableOrUnknown(data['round']!, _roundMeta),
      );
    }
    if (data.containsKey('pair_id')) {
      context.handle(
        _pairIdMeta,
        pairId.isAcceptableOrUnknown(data['pair_id']!, _pairIdMeta),
      );
    }
    if (data.containsKey('ui_generation')) {
      context.handle(
        _uiGenerationMeta,
        uiGeneration.isAcceptableOrUnknown(
          data['ui_generation']!,
          _uiGenerationMeta,
        ),
      );
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('sentence_id')) {
      context.handle(
        _sentenceIdMeta,
        sentenceId.isAcceptableOrUnknown(data['sentence_id']!, _sentenceIdMeta),
      );
    }
    if (data.containsKey('audio_ref_id')) {
      context.handle(
        _audioRefIdMeta,
        audioRefId.isAcceptableOrUnknown(
          data['audio_ref_id']!,
          _audioRefIdMeta,
        ),
      );
    }
    if (data.containsKey('annotation_hash')) {
      context.handle(
        _annotationHashMeta,
        annotationHash.isAcceptableOrUnknown(
          data['annotation_hash']!,
          _annotationHashMeta,
        ),
      );
    }
    if (data.containsKey('annotation_revision')) {
      context.handle(
        _annotationRevisionMeta,
        annotationRevision.isAcceptableOrUnknown(
          data['annotation_revision']!,
          _annotationRevisionMeta,
        ),
      );
    }
    if (data.containsKey('content_revision')) {
      context.handle(
        _contentRevisionMeta,
        contentRevision.isAcceptableOrUnknown(
          data['content_revision']!,
          _contentRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scopeId, attemptId, evidenceIndex};
  @override
  LearningAttemptEvidenceData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningAttemptEvidenceData(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      )!,
      evidenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}evidence_index'],
      )!,
      evidenceKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_kind'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      ),
      referenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_id'],
      ),
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      ),
      runGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}run_generation'],
      ),
      round: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round'],
      ),
      pairId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pair_id'],
      ),
      uiGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ui_generation'],
      ),
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      ),
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      sentenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentence_id'],
      ),
      audioRefId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_ref_id'],
      ),
      annotationHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}annotation_hash'],
      ),
      annotationRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}annotation_revision'],
      ),
      contentRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_revision'],
      ),
    );
  }

  @override
  $LearningAttemptEvidenceTable createAlias(String alias) {
    return $LearningAttemptEvidenceTable(attachedDatabase, alias);
  }
}

class LearningAttemptEvidenceData extends DataClass
    implements Insertable<LearningAttemptEvidenceData> {
  final int scopeId;
  final String attemptId;
  final int evidenceIndex;
  final String evidenceKind;
  final String? slot;
  final String? referenceId;
  final String? outcome;
  final String? source;
  final String? activityId;
  final int? runGeneration;
  final int? round;
  final String? pairId;
  final int? uiGeneration;
  final String? sectionId;
  final String? itemId;
  final String? sentenceId;
  final String? audioRefId;
  final String? annotationHash;
  final int? annotationRevision;
  final int? contentRevision;
  const LearningAttemptEvidenceData({
    required this.scopeId,
    required this.attemptId,
    required this.evidenceIndex,
    required this.evidenceKind,
    this.slot,
    this.referenceId,
    this.outcome,
    this.source,
    this.activityId,
    this.runGeneration,
    this.round,
    this.pairId,
    this.uiGeneration,
    this.sectionId,
    this.itemId,
    this.sentenceId,
    this.audioRefId,
    this.annotationHash,
    this.annotationRevision,
    this.contentRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['attempt_id'] = Variable<String>(attemptId);
    map['evidence_index'] = Variable<int>(evidenceIndex);
    map['evidence_kind'] = Variable<String>(evidenceKind);
    if (!nullToAbsent || slot != null) {
      map['slot'] = Variable<String>(slot);
    }
    if (!nullToAbsent || referenceId != null) {
      map['reference_id'] = Variable<String>(referenceId);
    }
    if (!nullToAbsent || outcome != null) {
      map['outcome'] = Variable<String>(outcome);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || activityId != null) {
      map['activity_id'] = Variable<String>(activityId);
    }
    if (!nullToAbsent || runGeneration != null) {
      map['run_generation'] = Variable<int>(runGeneration);
    }
    if (!nullToAbsent || round != null) {
      map['round'] = Variable<int>(round);
    }
    if (!nullToAbsent || pairId != null) {
      map['pair_id'] = Variable<String>(pairId);
    }
    if (!nullToAbsent || uiGeneration != null) {
      map['ui_generation'] = Variable<int>(uiGeneration);
    }
    if (!nullToAbsent || sectionId != null) {
      map['section_id'] = Variable<String>(sectionId);
    }
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    if (!nullToAbsent || sentenceId != null) {
      map['sentence_id'] = Variable<String>(sentenceId);
    }
    if (!nullToAbsent || audioRefId != null) {
      map['audio_ref_id'] = Variable<String>(audioRefId);
    }
    if (!nullToAbsent || annotationHash != null) {
      map['annotation_hash'] = Variable<String>(annotationHash);
    }
    if (!nullToAbsent || annotationRevision != null) {
      map['annotation_revision'] = Variable<int>(annotationRevision);
    }
    if (!nullToAbsent || contentRevision != null) {
      map['content_revision'] = Variable<int>(contentRevision);
    }
    return map;
  }

  LearningAttemptEvidenceCompanion toCompanion(bool nullToAbsent) {
    return LearningAttemptEvidenceCompanion(
      scopeId: Value(scopeId),
      attemptId: Value(attemptId),
      evidenceIndex: Value(evidenceIndex),
      evidenceKind: Value(evidenceKind),
      slot: slot == null && nullToAbsent ? const Value.absent() : Value(slot),
      referenceId: referenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceId),
      outcome: outcome == null && nullToAbsent
          ? const Value.absent()
          : Value(outcome),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      activityId: activityId == null && nullToAbsent
          ? const Value.absent()
          : Value(activityId),
      runGeneration: runGeneration == null && nullToAbsent
          ? const Value.absent()
          : Value(runGeneration),
      round: round == null && nullToAbsent
          ? const Value.absent()
          : Value(round),
      pairId: pairId == null && nullToAbsent
          ? const Value.absent()
          : Value(pairId),
      uiGeneration: uiGeneration == null && nullToAbsent
          ? const Value.absent()
          : Value(uiGeneration),
      sectionId: sectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionId),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      sentenceId: sentenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sentenceId),
      audioRefId: audioRefId == null && nullToAbsent
          ? const Value.absent()
          : Value(audioRefId),
      annotationHash: annotationHash == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationHash),
      annotationRevision: annotationRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationRevision),
      contentRevision: contentRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(contentRevision),
    );
  }

  factory LearningAttemptEvidenceData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningAttemptEvidenceData(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      attemptId: serializer.fromJson<String>(json['attemptId']),
      evidenceIndex: serializer.fromJson<int>(json['evidenceIndex']),
      evidenceKind: serializer.fromJson<String>(json['evidenceKind']),
      slot: serializer.fromJson<String?>(json['slot']),
      referenceId: serializer.fromJson<String?>(json['referenceId']),
      outcome: serializer.fromJson<String?>(json['outcome']),
      source: serializer.fromJson<String?>(json['source']),
      activityId: serializer.fromJson<String?>(json['activityId']),
      runGeneration: serializer.fromJson<int?>(json['runGeneration']),
      round: serializer.fromJson<int?>(json['round']),
      pairId: serializer.fromJson<String?>(json['pairId']),
      uiGeneration: serializer.fromJson<int?>(json['uiGeneration']),
      sectionId: serializer.fromJson<String?>(json['sectionId']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      sentenceId: serializer.fromJson<String?>(json['sentenceId']),
      audioRefId: serializer.fromJson<String?>(json['audioRefId']),
      annotationHash: serializer.fromJson<String?>(json['annotationHash']),
      annotationRevision: serializer.fromJson<int?>(json['annotationRevision']),
      contentRevision: serializer.fromJson<int?>(json['contentRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'attemptId': serializer.toJson<String>(attemptId),
      'evidenceIndex': serializer.toJson<int>(evidenceIndex),
      'evidenceKind': serializer.toJson<String>(evidenceKind),
      'slot': serializer.toJson<String?>(slot),
      'referenceId': serializer.toJson<String?>(referenceId),
      'outcome': serializer.toJson<String?>(outcome),
      'source': serializer.toJson<String?>(source),
      'activityId': serializer.toJson<String?>(activityId),
      'runGeneration': serializer.toJson<int?>(runGeneration),
      'round': serializer.toJson<int?>(round),
      'pairId': serializer.toJson<String?>(pairId),
      'uiGeneration': serializer.toJson<int?>(uiGeneration),
      'sectionId': serializer.toJson<String?>(sectionId),
      'itemId': serializer.toJson<String?>(itemId),
      'sentenceId': serializer.toJson<String?>(sentenceId),
      'audioRefId': serializer.toJson<String?>(audioRefId),
      'annotationHash': serializer.toJson<String?>(annotationHash),
      'annotationRevision': serializer.toJson<int?>(annotationRevision),
      'contentRevision': serializer.toJson<int?>(contentRevision),
    };
  }

  LearningAttemptEvidenceData copyWith({
    int? scopeId,
    String? attemptId,
    int? evidenceIndex,
    String? evidenceKind,
    Value<String?> slot = const Value.absent(),
    Value<String?> referenceId = const Value.absent(),
    Value<String?> outcome = const Value.absent(),
    Value<String?> source = const Value.absent(),
    Value<String?> activityId = const Value.absent(),
    Value<int?> runGeneration = const Value.absent(),
    Value<int?> round = const Value.absent(),
    Value<String?> pairId = const Value.absent(),
    Value<int?> uiGeneration = const Value.absent(),
    Value<String?> sectionId = const Value.absent(),
    Value<String?> itemId = const Value.absent(),
    Value<String?> sentenceId = const Value.absent(),
    Value<String?> audioRefId = const Value.absent(),
    Value<String?> annotationHash = const Value.absent(),
    Value<int?> annotationRevision = const Value.absent(),
    Value<int?> contentRevision = const Value.absent(),
  }) => LearningAttemptEvidenceData(
    scopeId: scopeId ?? this.scopeId,
    attemptId: attemptId ?? this.attemptId,
    evidenceIndex: evidenceIndex ?? this.evidenceIndex,
    evidenceKind: evidenceKind ?? this.evidenceKind,
    slot: slot.present ? slot.value : this.slot,
    referenceId: referenceId.present ? referenceId.value : this.referenceId,
    outcome: outcome.present ? outcome.value : this.outcome,
    source: source.present ? source.value : this.source,
    activityId: activityId.present ? activityId.value : this.activityId,
    runGeneration: runGeneration.present
        ? runGeneration.value
        : this.runGeneration,
    round: round.present ? round.value : this.round,
    pairId: pairId.present ? pairId.value : this.pairId,
    uiGeneration: uiGeneration.present ? uiGeneration.value : this.uiGeneration,
    sectionId: sectionId.present ? sectionId.value : this.sectionId,
    itemId: itemId.present ? itemId.value : this.itemId,
    sentenceId: sentenceId.present ? sentenceId.value : this.sentenceId,
    audioRefId: audioRefId.present ? audioRefId.value : this.audioRefId,
    annotationHash: annotationHash.present
        ? annotationHash.value
        : this.annotationHash,
    annotationRevision: annotationRevision.present
        ? annotationRevision.value
        : this.annotationRevision,
    contentRevision: contentRevision.present
        ? contentRevision.value
        : this.contentRevision,
  );
  LearningAttemptEvidenceData copyWithCompanion(
    LearningAttemptEvidenceCompanion data,
  ) {
    return LearningAttemptEvidenceData(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      evidenceIndex: data.evidenceIndex.present
          ? data.evidenceIndex.value
          : this.evidenceIndex,
      evidenceKind: data.evidenceKind.present
          ? data.evidenceKind.value
          : this.evidenceKind,
      slot: data.slot.present ? data.slot.value : this.slot,
      referenceId: data.referenceId.present
          ? data.referenceId.value
          : this.referenceId,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      source: data.source.present ? data.source.value : this.source,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      runGeneration: data.runGeneration.present
          ? data.runGeneration.value
          : this.runGeneration,
      round: data.round.present ? data.round.value : this.round,
      pairId: data.pairId.present ? data.pairId.value : this.pairId,
      uiGeneration: data.uiGeneration.present
          ? data.uiGeneration.value
          : this.uiGeneration,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      sentenceId: data.sentenceId.present
          ? data.sentenceId.value
          : this.sentenceId,
      audioRefId: data.audioRefId.present
          ? data.audioRefId.value
          : this.audioRefId,
      annotationHash: data.annotationHash.present
          ? data.annotationHash.value
          : this.annotationHash,
      annotationRevision: data.annotationRevision.present
          ? data.annotationRevision.value
          : this.annotationRevision,
      contentRevision: data.contentRevision.present
          ? data.contentRevision.value
          : this.contentRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningAttemptEvidenceData(')
          ..write('scopeId: $scopeId, ')
          ..write('attemptId: $attemptId, ')
          ..write('evidenceIndex: $evidenceIndex, ')
          ..write('evidenceKind: $evidenceKind, ')
          ..write('slot: $slot, ')
          ..write('referenceId: $referenceId, ')
          ..write('outcome: $outcome, ')
          ..write('source: $source, ')
          ..write('activityId: $activityId, ')
          ..write('runGeneration: $runGeneration, ')
          ..write('round: $round, ')
          ..write('pairId: $pairId, ')
          ..write('uiGeneration: $uiGeneration, ')
          ..write('sectionId: $sectionId, ')
          ..write('itemId: $itemId, ')
          ..write('sentenceId: $sentenceId, ')
          ..write('audioRefId: $audioRefId, ')
          ..write('annotationHash: $annotationHash, ')
          ..write('annotationRevision: $annotationRevision, ')
          ..write('contentRevision: $contentRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    attemptId,
    evidenceIndex,
    evidenceKind,
    slot,
    referenceId,
    outcome,
    source,
    activityId,
    runGeneration,
    round,
    pairId,
    uiGeneration,
    sectionId,
    itemId,
    sentenceId,
    audioRefId,
    annotationHash,
    annotationRevision,
    contentRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningAttemptEvidenceData &&
          other.scopeId == this.scopeId &&
          other.attemptId == this.attemptId &&
          other.evidenceIndex == this.evidenceIndex &&
          other.evidenceKind == this.evidenceKind &&
          other.slot == this.slot &&
          other.referenceId == this.referenceId &&
          other.outcome == this.outcome &&
          other.source == this.source &&
          other.activityId == this.activityId &&
          other.runGeneration == this.runGeneration &&
          other.round == this.round &&
          other.pairId == this.pairId &&
          other.uiGeneration == this.uiGeneration &&
          other.sectionId == this.sectionId &&
          other.itemId == this.itemId &&
          other.sentenceId == this.sentenceId &&
          other.audioRefId == this.audioRefId &&
          other.annotationHash == this.annotationHash &&
          other.annotationRevision == this.annotationRevision &&
          other.contentRevision == this.contentRevision);
}

class LearningAttemptEvidenceCompanion
    extends UpdateCompanion<LearningAttemptEvidenceData> {
  final Value<int> scopeId;
  final Value<String> attemptId;
  final Value<int> evidenceIndex;
  final Value<String> evidenceKind;
  final Value<String?> slot;
  final Value<String?> referenceId;
  final Value<String?> outcome;
  final Value<String?> source;
  final Value<String?> activityId;
  final Value<int?> runGeneration;
  final Value<int?> round;
  final Value<String?> pairId;
  final Value<int?> uiGeneration;
  final Value<String?> sectionId;
  final Value<String?> itemId;
  final Value<String?> sentenceId;
  final Value<String?> audioRefId;
  final Value<String?> annotationHash;
  final Value<int?> annotationRevision;
  final Value<int?> contentRevision;
  final Value<int> rowid;
  const LearningAttemptEvidenceCompanion({
    this.scopeId = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.evidenceIndex = const Value.absent(),
    this.evidenceKind = const Value.absent(),
    this.slot = const Value.absent(),
    this.referenceId = const Value.absent(),
    this.outcome = const Value.absent(),
    this.source = const Value.absent(),
    this.activityId = const Value.absent(),
    this.runGeneration = const Value.absent(),
    this.round = const Value.absent(),
    this.pairId = const Value.absent(),
    this.uiGeneration = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.sentenceId = const Value.absent(),
    this.audioRefId = const Value.absent(),
    this.annotationHash = const Value.absent(),
    this.annotationRevision = const Value.absent(),
    this.contentRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningAttemptEvidenceCompanion.insert({
    required int scopeId,
    required String attemptId,
    required int evidenceIndex,
    required String evidenceKind,
    this.slot = const Value.absent(),
    this.referenceId = const Value.absent(),
    this.outcome = const Value.absent(),
    this.source = const Value.absent(),
    this.activityId = const Value.absent(),
    this.runGeneration = const Value.absent(),
    this.round = const Value.absent(),
    this.pairId = const Value.absent(),
    this.uiGeneration = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.sentenceId = const Value.absent(),
    this.audioRefId = const Value.absent(),
    this.annotationHash = const Value.absent(),
    this.annotationRevision = const Value.absent(),
    this.contentRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       attemptId = Value(attemptId),
       evidenceIndex = Value(evidenceIndex),
       evidenceKind = Value(evidenceKind);
  static Insertable<LearningAttemptEvidenceData> custom({
    Expression<int>? scopeId,
    Expression<String>? attemptId,
    Expression<int>? evidenceIndex,
    Expression<String>? evidenceKind,
    Expression<String>? slot,
    Expression<String>? referenceId,
    Expression<String>? outcome,
    Expression<String>? source,
    Expression<String>? activityId,
    Expression<int>? runGeneration,
    Expression<int>? round,
    Expression<String>? pairId,
    Expression<int>? uiGeneration,
    Expression<String>? sectionId,
    Expression<String>? itemId,
    Expression<String>? sentenceId,
    Expression<String>? audioRefId,
    Expression<String>? annotationHash,
    Expression<int>? annotationRevision,
    Expression<int>? contentRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (attemptId != null) 'attempt_id': attemptId,
      if (evidenceIndex != null) 'evidence_index': evidenceIndex,
      if (evidenceKind != null) 'evidence_kind': evidenceKind,
      if (slot != null) 'slot': slot,
      if (referenceId != null) 'reference_id': referenceId,
      if (outcome != null) 'outcome': outcome,
      if (source != null) 'source': source,
      if (activityId != null) 'activity_id': activityId,
      if (runGeneration != null) 'run_generation': runGeneration,
      if (round != null) 'round': round,
      if (pairId != null) 'pair_id': pairId,
      if (uiGeneration != null) 'ui_generation': uiGeneration,
      if (sectionId != null) 'section_id': sectionId,
      if (itemId != null) 'item_id': itemId,
      if (sentenceId != null) 'sentence_id': sentenceId,
      if (audioRefId != null) 'audio_ref_id': audioRefId,
      if (annotationHash != null) 'annotation_hash': annotationHash,
      if (annotationRevision != null) 'annotation_revision': annotationRevision,
      if (contentRevision != null) 'content_revision': contentRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningAttemptEvidenceCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? attemptId,
    Value<int>? evidenceIndex,
    Value<String>? evidenceKind,
    Value<String?>? slot,
    Value<String?>? referenceId,
    Value<String?>? outcome,
    Value<String?>? source,
    Value<String?>? activityId,
    Value<int?>? runGeneration,
    Value<int?>? round,
    Value<String?>? pairId,
    Value<int?>? uiGeneration,
    Value<String?>? sectionId,
    Value<String?>? itemId,
    Value<String?>? sentenceId,
    Value<String?>? audioRefId,
    Value<String?>? annotationHash,
    Value<int?>? annotationRevision,
    Value<int?>? contentRevision,
    Value<int>? rowid,
  }) {
    return LearningAttemptEvidenceCompanion(
      scopeId: scopeId ?? this.scopeId,
      attemptId: attemptId ?? this.attemptId,
      evidenceIndex: evidenceIndex ?? this.evidenceIndex,
      evidenceKind: evidenceKind ?? this.evidenceKind,
      slot: slot ?? this.slot,
      referenceId: referenceId ?? this.referenceId,
      outcome: outcome ?? this.outcome,
      source: source ?? this.source,
      activityId: activityId ?? this.activityId,
      runGeneration: runGeneration ?? this.runGeneration,
      round: round ?? this.round,
      pairId: pairId ?? this.pairId,
      uiGeneration: uiGeneration ?? this.uiGeneration,
      sectionId: sectionId ?? this.sectionId,
      itemId: itemId ?? this.itemId,
      sentenceId: sentenceId ?? this.sentenceId,
      audioRefId: audioRefId ?? this.audioRefId,
      annotationHash: annotationHash ?? this.annotationHash,
      annotationRevision: annotationRevision ?? this.annotationRevision,
      contentRevision: contentRevision ?? this.contentRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (evidenceIndex.present) {
      map['evidence_index'] = Variable<int>(evidenceIndex.value);
    }
    if (evidenceKind.present) {
      map['evidence_kind'] = Variable<String>(evidenceKind.value);
    }
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (referenceId.present) {
      map['reference_id'] = Variable<String>(referenceId.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (runGeneration.present) {
      map['run_generation'] = Variable<int>(runGeneration.value);
    }
    if (round.present) {
      map['round'] = Variable<int>(round.value);
    }
    if (pairId.present) {
      map['pair_id'] = Variable<String>(pairId.value);
    }
    if (uiGeneration.present) {
      map['ui_generation'] = Variable<int>(uiGeneration.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (sentenceId.present) {
      map['sentence_id'] = Variable<String>(sentenceId.value);
    }
    if (audioRefId.present) {
      map['audio_ref_id'] = Variable<String>(audioRefId.value);
    }
    if (annotationHash.present) {
      map['annotation_hash'] = Variable<String>(annotationHash.value);
    }
    if (annotationRevision.present) {
      map['annotation_revision'] = Variable<int>(annotationRevision.value);
    }
    if (contentRevision.present) {
      map['content_revision'] = Variable<int>(contentRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningAttemptEvidenceCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('attemptId: $attemptId, ')
          ..write('evidenceIndex: $evidenceIndex, ')
          ..write('evidenceKind: $evidenceKind, ')
          ..write('slot: $slot, ')
          ..write('referenceId: $referenceId, ')
          ..write('outcome: $outcome, ')
          ..write('source: $source, ')
          ..write('activityId: $activityId, ')
          ..write('runGeneration: $runGeneration, ')
          ..write('round: $round, ')
          ..write('pairId: $pairId, ')
          ..write('uiGeneration: $uiGeneration, ')
          ..write('sectionId: $sectionId, ')
          ..write('itemId: $itemId, ')
          ..write('sentenceId: $sentenceId, ')
          ..write('audioRefId: $audioRefId, ')
          ..write('annotationHash: $annotationHash, ')
          ..write('annotationRevision: $annotationRevision, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningCommandReceiptsTable extends LearningCommandReceipts
    with TableInfo<$LearningCommandReceiptsTable, LearningCommandReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningCommandReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
    'token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canonicalPayloadMeta = const VerificationMeta(
    'canonicalPayload',
  );
  @override
  late final GeneratedColumn<String> canonicalPayload = GeneratedColumn<String>(
    'canonical_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beforeGenerationMeta = const VerificationMeta(
    'beforeGeneration',
  );
  @override
  late final GeneratedColumn<int> beforeGeneration = GeneratedColumn<int>(
    'before_generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beforeSequenceMeta = const VerificationMeta(
    'beforeSequence',
  );
  @override
  late final GeneratedColumn<int> beforeSequence = GeneratedColumn<int>(
    'before_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beforeCursorRevisionMeta =
      const VerificationMeta('beforeCursorRevision');
  @override
  late final GeneratedColumn<int> beforeCursorRevision = GeneratedColumn<int>(
    'before_cursor_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _afterGenerationMeta = const VerificationMeta(
    'afterGeneration',
  );
  @override
  late final GeneratedColumn<int> afterGeneration = GeneratedColumn<int>(
    'after_generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _afterSequenceMeta = const VerificationMeta(
    'afterSequence',
  );
  @override
  late final GeneratedColumn<int> afterSequence = GeneratedColumn<int>(
    'after_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _afterCursorRevisionMeta =
      const VerificationMeta('afterCursorRevision');
  @override
  late final GeneratedColumn<int> afterCursorRevision = GeneratedColumn<int>(
    'after_cursor_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commitOrdinalMeta = const VerificationMeta(
    'commitOrdinal',
  );
  @override
  late final GeneratedColumn<int> commitOrdinal = GeneratedColumn<int>(
    'commit_ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultActivityIdMeta = const VerificationMeta(
    'resultActivityId',
  );
  @override
  late final GeneratedColumn<String> resultActivityId = GeneratedColumn<String>(
    'result_activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultGenerationMeta = const VerificationMeta(
    'resultGeneration',
  );
  @override
  late final GeneratedColumn<int> resultGeneration = GeneratedColumn<int>(
    'result_generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultSequenceMeta = const VerificationMeta(
    'resultSequence',
  );
  @override
  late final GeneratedColumn<int> resultSequence = GeneratedColumn<int>(
    'result_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultCursorRevisionMeta =
      const VerificationMeta('resultCursorRevision');
  @override
  late final GeneratedColumn<int> resultCursorRevision = GeneratedColumn<int>(
    'result_cursor_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    activityId,
    token,
    canonicalPayload,
    beforeGeneration,
    beforeSequence,
    beforeCursorRevision,
    afterGeneration,
    afterSequence,
    afterCursorRevision,
    commitOrdinal,
    resultActivityId,
    resultGeneration,
    resultSequence,
    resultCursorRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_command_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningCommandReceipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('token')) {
      context.handle(
        _tokenMeta,
        token.isAcceptableOrUnknown(data['token']!, _tokenMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenMeta);
    }
    if (data.containsKey('canonical_payload')) {
      context.handle(
        _canonicalPayloadMeta,
        canonicalPayload.isAcceptableOrUnknown(
          data['canonical_payload']!,
          _canonicalPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalPayloadMeta);
    }
    if (data.containsKey('before_generation')) {
      context.handle(
        _beforeGenerationMeta,
        beforeGeneration.isAcceptableOrUnknown(
          data['before_generation']!,
          _beforeGenerationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_beforeGenerationMeta);
    }
    if (data.containsKey('before_sequence')) {
      context.handle(
        _beforeSequenceMeta,
        beforeSequence.isAcceptableOrUnknown(
          data['before_sequence']!,
          _beforeSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_beforeSequenceMeta);
    }
    if (data.containsKey('before_cursor_revision')) {
      context.handle(
        _beforeCursorRevisionMeta,
        beforeCursorRevision.isAcceptableOrUnknown(
          data['before_cursor_revision']!,
          _beforeCursorRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_beforeCursorRevisionMeta);
    }
    if (data.containsKey('after_generation')) {
      context.handle(
        _afterGenerationMeta,
        afterGeneration.isAcceptableOrUnknown(
          data['after_generation']!,
          _afterGenerationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_afterGenerationMeta);
    }
    if (data.containsKey('after_sequence')) {
      context.handle(
        _afterSequenceMeta,
        afterSequence.isAcceptableOrUnknown(
          data['after_sequence']!,
          _afterSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_afterSequenceMeta);
    }
    if (data.containsKey('after_cursor_revision')) {
      context.handle(
        _afterCursorRevisionMeta,
        afterCursorRevision.isAcceptableOrUnknown(
          data['after_cursor_revision']!,
          _afterCursorRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_afterCursorRevisionMeta);
    }
    if (data.containsKey('commit_ordinal')) {
      context.handle(
        _commitOrdinalMeta,
        commitOrdinal.isAcceptableOrUnknown(
          data['commit_ordinal']!,
          _commitOrdinalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commitOrdinalMeta);
    }
    if (data.containsKey('result_activity_id')) {
      context.handle(
        _resultActivityIdMeta,
        resultActivityId.isAcceptableOrUnknown(
          data['result_activity_id']!,
          _resultActivityIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resultActivityIdMeta);
    }
    if (data.containsKey('result_generation')) {
      context.handle(
        _resultGenerationMeta,
        resultGeneration.isAcceptableOrUnknown(
          data['result_generation']!,
          _resultGenerationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resultGenerationMeta);
    }
    if (data.containsKey('result_sequence')) {
      context.handle(
        _resultSequenceMeta,
        resultSequence.isAcceptableOrUnknown(
          data['result_sequence']!,
          _resultSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resultSequenceMeta);
    }
    if (data.containsKey('result_cursor_revision')) {
      context.handle(
        _resultCursorRevisionMeta,
        resultCursorRevision.isAcceptableOrUnknown(
          data['result_cursor_revision']!,
          _resultCursorRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resultCursorRevisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  LearningCommandReceipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningCommandReceipt(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      token: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token'],
      )!,
      canonicalPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_payload'],
      )!,
      beforeGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}before_generation'],
      )!,
      beforeSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}before_sequence'],
      )!,
      beforeCursorRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}before_cursor_revision'],
      )!,
      afterGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}after_generation'],
      )!,
      afterSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}after_sequence'],
      )!,
      afterCursorRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}after_cursor_revision'],
      )!,
      commitOrdinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}commit_ordinal'],
      )!,
      resultActivityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_activity_id'],
      )!,
      resultGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}result_generation'],
      )!,
      resultSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}result_sequence'],
      )!,
      resultCursorRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}result_cursor_revision'],
      )!,
    );
  }

  @override
  $LearningCommandReceiptsTable createAlias(String alias) {
    return $LearningCommandReceiptsTable(attachedDatabase, alias);
  }
}

class LearningCommandReceipt extends DataClass
    implements Insertable<LearningCommandReceipt> {
  final int scopeId;
  final String activityId;
  final String token;
  final String canonicalPayload;
  final int beforeGeneration;
  final int beforeSequence;
  final int beforeCursorRevision;
  final int afterGeneration;
  final int afterSequence;
  final int afterCursorRevision;
  final int commitOrdinal;
  final String resultActivityId;
  final int resultGeneration;
  final int resultSequence;
  final int resultCursorRevision;
  const LearningCommandReceipt({
    required this.scopeId,
    required this.activityId,
    required this.token,
    required this.canonicalPayload,
    required this.beforeGeneration,
    required this.beforeSequence,
    required this.beforeCursorRevision,
    required this.afterGeneration,
    required this.afterSequence,
    required this.afterCursorRevision,
    required this.commitOrdinal,
    required this.resultActivityId,
    required this.resultGeneration,
    required this.resultSequence,
    required this.resultCursorRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['activity_id'] = Variable<String>(activityId);
    map['token'] = Variable<String>(token);
    map['canonical_payload'] = Variable<String>(canonicalPayload);
    map['before_generation'] = Variable<int>(beforeGeneration);
    map['before_sequence'] = Variable<int>(beforeSequence);
    map['before_cursor_revision'] = Variable<int>(beforeCursorRevision);
    map['after_generation'] = Variable<int>(afterGeneration);
    map['after_sequence'] = Variable<int>(afterSequence);
    map['after_cursor_revision'] = Variable<int>(afterCursorRevision);
    map['commit_ordinal'] = Variable<int>(commitOrdinal);
    map['result_activity_id'] = Variable<String>(resultActivityId);
    map['result_generation'] = Variable<int>(resultGeneration);
    map['result_sequence'] = Variable<int>(resultSequence);
    map['result_cursor_revision'] = Variable<int>(resultCursorRevision);
    return map;
  }

  LearningCommandReceiptsCompanion toCompanion(bool nullToAbsent) {
    return LearningCommandReceiptsCompanion(
      scopeId: Value(scopeId),
      activityId: Value(activityId),
      token: Value(token),
      canonicalPayload: Value(canonicalPayload),
      beforeGeneration: Value(beforeGeneration),
      beforeSequence: Value(beforeSequence),
      beforeCursorRevision: Value(beforeCursorRevision),
      afterGeneration: Value(afterGeneration),
      afterSequence: Value(afterSequence),
      afterCursorRevision: Value(afterCursorRevision),
      commitOrdinal: Value(commitOrdinal),
      resultActivityId: Value(resultActivityId),
      resultGeneration: Value(resultGeneration),
      resultSequence: Value(resultSequence),
      resultCursorRevision: Value(resultCursorRevision),
    );
  }

  factory LearningCommandReceipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningCommandReceipt(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      activityId: serializer.fromJson<String>(json['activityId']),
      token: serializer.fromJson<String>(json['token']),
      canonicalPayload: serializer.fromJson<String>(json['canonicalPayload']),
      beforeGeneration: serializer.fromJson<int>(json['beforeGeneration']),
      beforeSequence: serializer.fromJson<int>(json['beforeSequence']),
      beforeCursorRevision: serializer.fromJson<int>(
        json['beforeCursorRevision'],
      ),
      afterGeneration: serializer.fromJson<int>(json['afterGeneration']),
      afterSequence: serializer.fromJson<int>(json['afterSequence']),
      afterCursorRevision: serializer.fromJson<int>(
        json['afterCursorRevision'],
      ),
      commitOrdinal: serializer.fromJson<int>(json['commitOrdinal']),
      resultActivityId: serializer.fromJson<String>(json['resultActivityId']),
      resultGeneration: serializer.fromJson<int>(json['resultGeneration']),
      resultSequence: serializer.fromJson<int>(json['resultSequence']),
      resultCursorRevision: serializer.fromJson<int>(
        json['resultCursorRevision'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'activityId': serializer.toJson<String>(activityId),
      'token': serializer.toJson<String>(token),
      'canonicalPayload': serializer.toJson<String>(canonicalPayload),
      'beforeGeneration': serializer.toJson<int>(beforeGeneration),
      'beforeSequence': serializer.toJson<int>(beforeSequence),
      'beforeCursorRevision': serializer.toJson<int>(beforeCursorRevision),
      'afterGeneration': serializer.toJson<int>(afterGeneration),
      'afterSequence': serializer.toJson<int>(afterSequence),
      'afterCursorRevision': serializer.toJson<int>(afterCursorRevision),
      'commitOrdinal': serializer.toJson<int>(commitOrdinal),
      'resultActivityId': serializer.toJson<String>(resultActivityId),
      'resultGeneration': serializer.toJson<int>(resultGeneration),
      'resultSequence': serializer.toJson<int>(resultSequence),
      'resultCursorRevision': serializer.toJson<int>(resultCursorRevision),
    };
  }

  LearningCommandReceipt copyWith({
    int? scopeId,
    String? activityId,
    String? token,
    String? canonicalPayload,
    int? beforeGeneration,
    int? beforeSequence,
    int? beforeCursorRevision,
    int? afterGeneration,
    int? afterSequence,
    int? afterCursorRevision,
    int? commitOrdinal,
    String? resultActivityId,
    int? resultGeneration,
    int? resultSequence,
    int? resultCursorRevision,
  }) => LearningCommandReceipt(
    scopeId: scopeId ?? this.scopeId,
    activityId: activityId ?? this.activityId,
    token: token ?? this.token,
    canonicalPayload: canonicalPayload ?? this.canonicalPayload,
    beforeGeneration: beforeGeneration ?? this.beforeGeneration,
    beforeSequence: beforeSequence ?? this.beforeSequence,
    beforeCursorRevision: beforeCursorRevision ?? this.beforeCursorRevision,
    afterGeneration: afterGeneration ?? this.afterGeneration,
    afterSequence: afterSequence ?? this.afterSequence,
    afterCursorRevision: afterCursorRevision ?? this.afterCursorRevision,
    commitOrdinal: commitOrdinal ?? this.commitOrdinal,
    resultActivityId: resultActivityId ?? this.resultActivityId,
    resultGeneration: resultGeneration ?? this.resultGeneration,
    resultSequence: resultSequence ?? this.resultSequence,
    resultCursorRevision: resultCursorRevision ?? this.resultCursorRevision,
  );
  LearningCommandReceipt copyWithCompanion(
    LearningCommandReceiptsCompanion data,
  ) {
    return LearningCommandReceipt(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      token: data.token.present ? data.token.value : this.token,
      canonicalPayload: data.canonicalPayload.present
          ? data.canonicalPayload.value
          : this.canonicalPayload,
      beforeGeneration: data.beforeGeneration.present
          ? data.beforeGeneration.value
          : this.beforeGeneration,
      beforeSequence: data.beforeSequence.present
          ? data.beforeSequence.value
          : this.beforeSequence,
      beforeCursorRevision: data.beforeCursorRevision.present
          ? data.beforeCursorRevision.value
          : this.beforeCursorRevision,
      afterGeneration: data.afterGeneration.present
          ? data.afterGeneration.value
          : this.afterGeneration,
      afterSequence: data.afterSequence.present
          ? data.afterSequence.value
          : this.afterSequence,
      afterCursorRevision: data.afterCursorRevision.present
          ? data.afterCursorRevision.value
          : this.afterCursorRevision,
      commitOrdinal: data.commitOrdinal.present
          ? data.commitOrdinal.value
          : this.commitOrdinal,
      resultActivityId: data.resultActivityId.present
          ? data.resultActivityId.value
          : this.resultActivityId,
      resultGeneration: data.resultGeneration.present
          ? data.resultGeneration.value
          : this.resultGeneration,
      resultSequence: data.resultSequence.present
          ? data.resultSequence.value
          : this.resultSequence,
      resultCursorRevision: data.resultCursorRevision.present
          ? data.resultCursorRevision.value
          : this.resultCursorRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningCommandReceipt(')
          ..write('scopeId: $scopeId, ')
          ..write('activityId: $activityId, ')
          ..write('token: $token, ')
          ..write('canonicalPayload: $canonicalPayload, ')
          ..write('beforeGeneration: $beforeGeneration, ')
          ..write('beforeSequence: $beforeSequence, ')
          ..write('beforeCursorRevision: $beforeCursorRevision, ')
          ..write('afterGeneration: $afterGeneration, ')
          ..write('afterSequence: $afterSequence, ')
          ..write('afterCursorRevision: $afterCursorRevision, ')
          ..write('commitOrdinal: $commitOrdinal, ')
          ..write('resultActivityId: $resultActivityId, ')
          ..write('resultGeneration: $resultGeneration, ')
          ..write('resultSequence: $resultSequence, ')
          ..write('resultCursorRevision: $resultCursorRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    activityId,
    token,
    canonicalPayload,
    beforeGeneration,
    beforeSequence,
    beforeCursorRevision,
    afterGeneration,
    afterSequence,
    afterCursorRevision,
    commitOrdinal,
    resultActivityId,
    resultGeneration,
    resultSequence,
    resultCursorRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningCommandReceipt &&
          other.scopeId == this.scopeId &&
          other.activityId == this.activityId &&
          other.token == this.token &&
          other.canonicalPayload == this.canonicalPayload &&
          other.beforeGeneration == this.beforeGeneration &&
          other.beforeSequence == this.beforeSequence &&
          other.beforeCursorRevision == this.beforeCursorRevision &&
          other.afterGeneration == this.afterGeneration &&
          other.afterSequence == this.afterSequence &&
          other.afterCursorRevision == this.afterCursorRevision &&
          other.commitOrdinal == this.commitOrdinal &&
          other.resultActivityId == this.resultActivityId &&
          other.resultGeneration == this.resultGeneration &&
          other.resultSequence == this.resultSequence &&
          other.resultCursorRevision == this.resultCursorRevision);
}

class LearningCommandReceiptsCompanion
    extends UpdateCompanion<LearningCommandReceipt> {
  final Value<int> scopeId;
  final Value<String> activityId;
  final Value<String> token;
  final Value<String> canonicalPayload;
  final Value<int> beforeGeneration;
  final Value<int> beforeSequence;
  final Value<int> beforeCursorRevision;
  final Value<int> afterGeneration;
  final Value<int> afterSequence;
  final Value<int> afterCursorRevision;
  final Value<int> commitOrdinal;
  final Value<String> resultActivityId;
  final Value<int> resultGeneration;
  final Value<int> resultSequence;
  final Value<int> resultCursorRevision;
  final Value<int> rowid;
  const LearningCommandReceiptsCompanion({
    this.scopeId = const Value.absent(),
    this.activityId = const Value.absent(),
    this.token = const Value.absent(),
    this.canonicalPayload = const Value.absent(),
    this.beforeGeneration = const Value.absent(),
    this.beforeSequence = const Value.absent(),
    this.beforeCursorRevision = const Value.absent(),
    this.afterGeneration = const Value.absent(),
    this.afterSequence = const Value.absent(),
    this.afterCursorRevision = const Value.absent(),
    this.commitOrdinal = const Value.absent(),
    this.resultActivityId = const Value.absent(),
    this.resultGeneration = const Value.absent(),
    this.resultSequence = const Value.absent(),
    this.resultCursorRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningCommandReceiptsCompanion.insert({
    required int scopeId,
    required String activityId,
    required String token,
    required String canonicalPayload,
    required int beforeGeneration,
    required int beforeSequence,
    required int beforeCursorRevision,
    required int afterGeneration,
    required int afterSequence,
    required int afterCursorRevision,
    required int commitOrdinal,
    required String resultActivityId,
    required int resultGeneration,
    required int resultSequence,
    required int resultCursorRevision,
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       activityId = Value(activityId),
       token = Value(token),
       canonicalPayload = Value(canonicalPayload),
       beforeGeneration = Value(beforeGeneration),
       beforeSequence = Value(beforeSequence),
       beforeCursorRevision = Value(beforeCursorRevision),
       afterGeneration = Value(afterGeneration),
       afterSequence = Value(afterSequence),
       afterCursorRevision = Value(afterCursorRevision),
       commitOrdinal = Value(commitOrdinal),
       resultActivityId = Value(resultActivityId),
       resultGeneration = Value(resultGeneration),
       resultSequence = Value(resultSequence),
       resultCursorRevision = Value(resultCursorRevision);
  static Insertable<LearningCommandReceipt> custom({
    Expression<int>? scopeId,
    Expression<String>? activityId,
    Expression<String>? token,
    Expression<String>? canonicalPayload,
    Expression<int>? beforeGeneration,
    Expression<int>? beforeSequence,
    Expression<int>? beforeCursorRevision,
    Expression<int>? afterGeneration,
    Expression<int>? afterSequence,
    Expression<int>? afterCursorRevision,
    Expression<int>? commitOrdinal,
    Expression<String>? resultActivityId,
    Expression<int>? resultGeneration,
    Expression<int>? resultSequence,
    Expression<int>? resultCursorRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (activityId != null) 'activity_id': activityId,
      if (token != null) 'token': token,
      if (canonicalPayload != null) 'canonical_payload': canonicalPayload,
      if (beforeGeneration != null) 'before_generation': beforeGeneration,
      if (beforeSequence != null) 'before_sequence': beforeSequence,
      if (beforeCursorRevision != null)
        'before_cursor_revision': beforeCursorRevision,
      if (afterGeneration != null) 'after_generation': afterGeneration,
      if (afterSequence != null) 'after_sequence': afterSequence,
      if (afterCursorRevision != null)
        'after_cursor_revision': afterCursorRevision,
      if (commitOrdinal != null) 'commit_ordinal': commitOrdinal,
      if (resultActivityId != null) 'result_activity_id': resultActivityId,
      if (resultGeneration != null) 'result_generation': resultGeneration,
      if (resultSequence != null) 'result_sequence': resultSequence,
      if (resultCursorRevision != null)
        'result_cursor_revision': resultCursorRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningCommandReceiptsCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? activityId,
    Value<String>? token,
    Value<String>? canonicalPayload,
    Value<int>? beforeGeneration,
    Value<int>? beforeSequence,
    Value<int>? beforeCursorRevision,
    Value<int>? afterGeneration,
    Value<int>? afterSequence,
    Value<int>? afterCursorRevision,
    Value<int>? commitOrdinal,
    Value<String>? resultActivityId,
    Value<int>? resultGeneration,
    Value<int>? resultSequence,
    Value<int>? resultCursorRevision,
    Value<int>? rowid,
  }) {
    return LearningCommandReceiptsCompanion(
      scopeId: scopeId ?? this.scopeId,
      activityId: activityId ?? this.activityId,
      token: token ?? this.token,
      canonicalPayload: canonicalPayload ?? this.canonicalPayload,
      beforeGeneration: beforeGeneration ?? this.beforeGeneration,
      beforeSequence: beforeSequence ?? this.beforeSequence,
      beforeCursorRevision: beforeCursorRevision ?? this.beforeCursorRevision,
      afterGeneration: afterGeneration ?? this.afterGeneration,
      afterSequence: afterSequence ?? this.afterSequence,
      afterCursorRevision: afterCursorRevision ?? this.afterCursorRevision,
      commitOrdinal: commitOrdinal ?? this.commitOrdinal,
      resultActivityId: resultActivityId ?? this.resultActivityId,
      resultGeneration: resultGeneration ?? this.resultGeneration,
      resultSequence: resultSequence ?? this.resultSequence,
      resultCursorRevision: resultCursorRevision ?? this.resultCursorRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (canonicalPayload.present) {
      map['canonical_payload'] = Variable<String>(canonicalPayload.value);
    }
    if (beforeGeneration.present) {
      map['before_generation'] = Variable<int>(beforeGeneration.value);
    }
    if (beforeSequence.present) {
      map['before_sequence'] = Variable<int>(beforeSequence.value);
    }
    if (beforeCursorRevision.present) {
      map['before_cursor_revision'] = Variable<int>(beforeCursorRevision.value);
    }
    if (afterGeneration.present) {
      map['after_generation'] = Variable<int>(afterGeneration.value);
    }
    if (afterSequence.present) {
      map['after_sequence'] = Variable<int>(afterSequence.value);
    }
    if (afterCursorRevision.present) {
      map['after_cursor_revision'] = Variable<int>(afterCursorRevision.value);
    }
    if (commitOrdinal.present) {
      map['commit_ordinal'] = Variable<int>(commitOrdinal.value);
    }
    if (resultActivityId.present) {
      map['result_activity_id'] = Variable<String>(resultActivityId.value);
    }
    if (resultGeneration.present) {
      map['result_generation'] = Variable<int>(resultGeneration.value);
    }
    if (resultSequence.present) {
      map['result_sequence'] = Variable<int>(resultSequence.value);
    }
    if (resultCursorRevision.present) {
      map['result_cursor_revision'] = Variable<int>(resultCursorRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningCommandReceiptsCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('activityId: $activityId, ')
          ..write('token: $token, ')
          ..write('canonicalPayload: $canonicalPayload, ')
          ..write('beforeGeneration: $beforeGeneration, ')
          ..write('beforeSequence: $beforeSequence, ')
          ..write('beforeCursorRevision: $beforeCursorRevision, ')
          ..write('afterGeneration: $afterGeneration, ')
          ..write('afterSequence: $afterSequence, ')
          ..write('afterCursorRevision: $afterCursorRevision, ')
          ..write('commitOrdinal: $commitOrdinal, ')
          ..write('resultActivityId: $resultActivityId, ')
          ..write('resultGeneration: $resultGeneration, ')
          ..write('resultSequence: $resultSequence, ')
          ..write('resultCursorRevision: $resultCursorRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningMistakesTable extends LearningMistakes
    with TableInfo<$LearningMistakesTable, LearningMistake> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningMistakesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _familyMeta = const VerificationMeta('family');
  @override
  late final GeneratedColumn<String> family = GeneratedColumn<String>(
    'family',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetSoundMeta = const VerificationMeta(
    'targetSound',
  );
  @override
  late final GeneratedColumn<String> targetSound = GeneratedColumn<String>(
    'target_sound',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _skillMeta = const VerificationMeta('skill');
  @override
  late final GeneratedColumn<String> skill = GeneratedColumn<String>(
    'skill',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pairIdMeta = const VerificationMeta('pairId');
  @override
  late final GeneratedColumn<String> pairId = GeneratedColumn<String>(
    'pair_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentenceIdMeta = const VerificationMeta(
    'sentenceId',
  );
  @override
  late final GeneratedColumn<String> sentenceId = GeneratedColumn<String>(
    'sentence_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioRefIdMeta = const VerificationMeta(
    'audioRefId',
  );
  @override
  late final GeneratedColumn<String> audioRefId = GeneratedColumn<String>(
    'audio_ref_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotationHashMeta = const VerificationMeta(
    'annotationHash',
  );
  @override
  late final GeneratedColumn<String> annotationHash = GeneratedColumn<String>(
    'annotation_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotationRevisionMeta =
      const VerificationMeta('annotationRevision');
  @override
  late final GeneratedColumn<int> annotationRevision = GeneratedColumn<int>(
    'annotation_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentRevisionMeta = const VerificationMeta(
    'contentRevision',
  );
  @override
  late final GeneratedColumn<int> contentRevision = GeneratedColumn<int>(
    'content_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstWrongAttemptIdMeta =
      const VerificationMeta('firstWrongAttemptId');
  @override
  late final GeneratedColumn<String> firstWrongAttemptId =
      GeneratedColumn<String>(
        'first_wrong_attempt_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _latestWrongAttemptIdMeta =
      const VerificationMeta('latestWrongAttemptId');
  @override
  late final GeneratedColumn<String> latestWrongAttemptId =
      GeneratedColumn<String>(
        'latest_wrong_attempt_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _firstWrongAtUsMeta = const VerificationMeta(
    'firstWrongAtUs',
  );
  @override
  late final GeneratedColumn<int> firstWrongAtUs = GeneratedColumn<int>(
    'first_wrong_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latestWrongAtUsMeta = const VerificationMeta(
    'latestWrongAtUs',
  );
  @override
  late final GeneratedColumn<int> latestWrongAtUs = GeneratedColumn<int>(
    'latest_wrong_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failureCountMeta = const VerificationMeta(
    'failureCount',
  );
  @override
  late final GeneratedColumn<int> failureCount = GeneratedColumn<int>(
    'failure_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastRunGenerationMeta = const VerificationMeta(
    'lastRunGeneration',
  );
  @override
  late final GeneratedColumn<int> lastRunGeneration = GeneratedColumn<int>(
    'last_run_generation',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    family,
    activityId,
    itemId,
    targetSound,
    skill,
    pairId,
    sectionId,
    sentenceId,
    audioRefId,
    annotationHash,
    annotationRevision,
    contentRevision,
    firstWrongAttemptId,
    latestWrongAttemptId,
    firstWrongAtUs,
    latestWrongAtUs,
    failureCount,
    lastRunGeneration,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_mistakes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningMistake> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('family')) {
      context.handle(
        _familyMeta,
        family.isAcceptableOrUnknown(data['family']!, _familyMeta),
      );
    } else if (isInserting) {
      context.missing(_familyMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('target_sound')) {
      context.handle(
        _targetSoundMeta,
        targetSound.isAcceptableOrUnknown(
          data['target_sound']!,
          _targetSoundMeta,
        ),
      );
    }
    if (data.containsKey('skill')) {
      context.handle(
        _skillMeta,
        skill.isAcceptableOrUnknown(data['skill']!, _skillMeta),
      );
    }
    if (data.containsKey('pair_id')) {
      context.handle(
        _pairIdMeta,
        pairId.isAcceptableOrUnknown(data['pair_id']!, _pairIdMeta),
      );
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    }
    if (data.containsKey('sentence_id')) {
      context.handle(
        _sentenceIdMeta,
        sentenceId.isAcceptableOrUnknown(data['sentence_id']!, _sentenceIdMeta),
      );
    }
    if (data.containsKey('audio_ref_id')) {
      context.handle(
        _audioRefIdMeta,
        audioRefId.isAcceptableOrUnknown(
          data['audio_ref_id']!,
          _audioRefIdMeta,
        ),
      );
    }
    if (data.containsKey('annotation_hash')) {
      context.handle(
        _annotationHashMeta,
        annotationHash.isAcceptableOrUnknown(
          data['annotation_hash']!,
          _annotationHashMeta,
        ),
      );
    }
    if (data.containsKey('annotation_revision')) {
      context.handle(
        _annotationRevisionMeta,
        annotationRevision.isAcceptableOrUnknown(
          data['annotation_revision']!,
          _annotationRevisionMeta,
        ),
      );
    }
    if (data.containsKey('content_revision')) {
      context.handle(
        _contentRevisionMeta,
        contentRevision.isAcceptableOrUnknown(
          data['content_revision']!,
          _contentRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentRevisionMeta);
    }
    if (data.containsKey('first_wrong_attempt_id')) {
      context.handle(
        _firstWrongAttemptIdMeta,
        firstWrongAttemptId.isAcceptableOrUnknown(
          data['first_wrong_attempt_id']!,
          _firstWrongAttemptIdMeta,
        ),
      );
    }
    if (data.containsKey('latest_wrong_attempt_id')) {
      context.handle(
        _latestWrongAttemptIdMeta,
        latestWrongAttemptId.isAcceptableOrUnknown(
          data['latest_wrong_attempt_id']!,
          _latestWrongAttemptIdMeta,
        ),
      );
    }
    if (data.containsKey('first_wrong_at_us')) {
      context.handle(
        _firstWrongAtUsMeta,
        firstWrongAtUs.isAcceptableOrUnknown(
          data['first_wrong_at_us']!,
          _firstWrongAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstWrongAtUsMeta);
    }
    if (data.containsKey('latest_wrong_at_us')) {
      context.handle(
        _latestWrongAtUsMeta,
        latestWrongAtUs.isAcceptableOrUnknown(
          data['latest_wrong_at_us']!,
          _latestWrongAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_latestWrongAtUsMeta);
    }
    if (data.containsKey('failure_count')) {
      context.handle(
        _failureCountMeta,
        failureCount.isAcceptableOrUnknown(
          data['failure_count']!,
          _failureCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_failureCountMeta);
    }
    if (data.containsKey('last_run_generation')) {
      context.handle(
        _lastRunGenerationMeta,
        lastRunGeneration.isAcceptableOrUnknown(
          data['last_run_generation']!,
          _lastRunGenerationMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  LearningMistake map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningMistake(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      family: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      ),
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      targetSound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_sound'],
      ),
      skill: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill'],
      ),
      pairId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pair_id'],
      ),
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      ),
      sentenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentence_id'],
      ),
      audioRefId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_ref_id'],
      ),
      annotationHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}annotation_hash'],
      ),
      annotationRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}annotation_revision'],
      ),
      contentRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_revision'],
      )!,
      firstWrongAttemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_wrong_attempt_id'],
      ),
      latestWrongAttemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latest_wrong_attempt_id'],
      ),
      firstWrongAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_wrong_at_us'],
      )!,
      latestWrongAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latest_wrong_at_us'],
      )!,
      failureCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failure_count'],
      )!,
      lastRunGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_run_generation'],
      ),
    );
  }

  @override
  $LearningMistakesTable createAlias(String alias) {
    return $LearningMistakesTable(attachedDatabase, alias);
  }
}

class LearningMistake extends DataClass implements Insertable<LearningMistake> {
  final int scopeId;
  final String family;
  final String? activityId;
  final String? itemId;
  final String? targetSound;
  final String? skill;
  final String? pairId;
  final String? sectionId;
  final String? sentenceId;
  final String? audioRefId;
  final String? annotationHash;
  final int? annotationRevision;
  final int contentRevision;
  final String? firstWrongAttemptId;
  final String? latestWrongAttemptId;
  final int firstWrongAtUs;
  final int latestWrongAtUs;
  final int failureCount;
  final int? lastRunGeneration;
  const LearningMistake({
    required this.scopeId,
    required this.family,
    this.activityId,
    this.itemId,
    this.targetSound,
    this.skill,
    this.pairId,
    this.sectionId,
    this.sentenceId,
    this.audioRefId,
    this.annotationHash,
    this.annotationRevision,
    required this.contentRevision,
    this.firstWrongAttemptId,
    this.latestWrongAttemptId,
    required this.firstWrongAtUs,
    required this.latestWrongAtUs,
    required this.failureCount,
    this.lastRunGeneration,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['family'] = Variable<String>(family);
    if (!nullToAbsent || activityId != null) {
      map['activity_id'] = Variable<String>(activityId);
    }
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    if (!nullToAbsent || targetSound != null) {
      map['target_sound'] = Variable<String>(targetSound);
    }
    if (!nullToAbsent || skill != null) {
      map['skill'] = Variable<String>(skill);
    }
    if (!nullToAbsent || pairId != null) {
      map['pair_id'] = Variable<String>(pairId);
    }
    if (!nullToAbsent || sectionId != null) {
      map['section_id'] = Variable<String>(sectionId);
    }
    if (!nullToAbsent || sentenceId != null) {
      map['sentence_id'] = Variable<String>(sentenceId);
    }
    if (!nullToAbsent || audioRefId != null) {
      map['audio_ref_id'] = Variable<String>(audioRefId);
    }
    if (!nullToAbsent || annotationHash != null) {
      map['annotation_hash'] = Variable<String>(annotationHash);
    }
    if (!nullToAbsent || annotationRevision != null) {
      map['annotation_revision'] = Variable<int>(annotationRevision);
    }
    map['content_revision'] = Variable<int>(contentRevision);
    if (!nullToAbsent || firstWrongAttemptId != null) {
      map['first_wrong_attempt_id'] = Variable<String>(firstWrongAttemptId);
    }
    if (!nullToAbsent || latestWrongAttemptId != null) {
      map['latest_wrong_attempt_id'] = Variable<String>(latestWrongAttemptId);
    }
    map['first_wrong_at_us'] = Variable<int>(firstWrongAtUs);
    map['latest_wrong_at_us'] = Variable<int>(latestWrongAtUs);
    map['failure_count'] = Variable<int>(failureCount);
    if (!nullToAbsent || lastRunGeneration != null) {
      map['last_run_generation'] = Variable<int>(lastRunGeneration);
    }
    return map;
  }

  LearningMistakesCompanion toCompanion(bool nullToAbsent) {
    return LearningMistakesCompanion(
      scopeId: Value(scopeId),
      family: Value(family),
      activityId: activityId == null && nullToAbsent
          ? const Value.absent()
          : Value(activityId),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      targetSound: targetSound == null && nullToAbsent
          ? const Value.absent()
          : Value(targetSound),
      skill: skill == null && nullToAbsent
          ? const Value.absent()
          : Value(skill),
      pairId: pairId == null && nullToAbsent
          ? const Value.absent()
          : Value(pairId),
      sectionId: sectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionId),
      sentenceId: sentenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sentenceId),
      audioRefId: audioRefId == null && nullToAbsent
          ? const Value.absent()
          : Value(audioRefId),
      annotationHash: annotationHash == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationHash),
      annotationRevision: annotationRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationRevision),
      contentRevision: Value(contentRevision),
      firstWrongAttemptId: firstWrongAttemptId == null && nullToAbsent
          ? const Value.absent()
          : Value(firstWrongAttemptId),
      latestWrongAttemptId: latestWrongAttemptId == null && nullToAbsent
          ? const Value.absent()
          : Value(latestWrongAttemptId),
      firstWrongAtUs: Value(firstWrongAtUs),
      latestWrongAtUs: Value(latestWrongAtUs),
      failureCount: Value(failureCount),
      lastRunGeneration: lastRunGeneration == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRunGeneration),
    );
  }

  factory LearningMistake.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningMistake(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      family: serializer.fromJson<String>(json['family']),
      activityId: serializer.fromJson<String?>(json['activityId']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      targetSound: serializer.fromJson<String?>(json['targetSound']),
      skill: serializer.fromJson<String?>(json['skill']),
      pairId: serializer.fromJson<String?>(json['pairId']),
      sectionId: serializer.fromJson<String?>(json['sectionId']),
      sentenceId: serializer.fromJson<String?>(json['sentenceId']),
      audioRefId: serializer.fromJson<String?>(json['audioRefId']),
      annotationHash: serializer.fromJson<String?>(json['annotationHash']),
      annotationRevision: serializer.fromJson<int?>(json['annotationRevision']),
      contentRevision: serializer.fromJson<int>(json['contentRevision']),
      firstWrongAttemptId: serializer.fromJson<String?>(
        json['firstWrongAttemptId'],
      ),
      latestWrongAttemptId: serializer.fromJson<String?>(
        json['latestWrongAttemptId'],
      ),
      firstWrongAtUs: serializer.fromJson<int>(json['firstWrongAtUs']),
      latestWrongAtUs: serializer.fromJson<int>(json['latestWrongAtUs']),
      failureCount: serializer.fromJson<int>(json['failureCount']),
      lastRunGeneration: serializer.fromJson<int?>(json['lastRunGeneration']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'family': serializer.toJson<String>(family),
      'activityId': serializer.toJson<String?>(activityId),
      'itemId': serializer.toJson<String?>(itemId),
      'targetSound': serializer.toJson<String?>(targetSound),
      'skill': serializer.toJson<String?>(skill),
      'pairId': serializer.toJson<String?>(pairId),
      'sectionId': serializer.toJson<String?>(sectionId),
      'sentenceId': serializer.toJson<String?>(sentenceId),
      'audioRefId': serializer.toJson<String?>(audioRefId),
      'annotationHash': serializer.toJson<String?>(annotationHash),
      'annotationRevision': serializer.toJson<int?>(annotationRevision),
      'contentRevision': serializer.toJson<int>(contentRevision),
      'firstWrongAttemptId': serializer.toJson<String?>(firstWrongAttemptId),
      'latestWrongAttemptId': serializer.toJson<String?>(latestWrongAttemptId),
      'firstWrongAtUs': serializer.toJson<int>(firstWrongAtUs),
      'latestWrongAtUs': serializer.toJson<int>(latestWrongAtUs),
      'failureCount': serializer.toJson<int>(failureCount),
      'lastRunGeneration': serializer.toJson<int?>(lastRunGeneration),
    };
  }

  LearningMistake copyWith({
    int? scopeId,
    String? family,
    Value<String?> activityId = const Value.absent(),
    Value<String?> itemId = const Value.absent(),
    Value<String?> targetSound = const Value.absent(),
    Value<String?> skill = const Value.absent(),
    Value<String?> pairId = const Value.absent(),
    Value<String?> sectionId = const Value.absent(),
    Value<String?> sentenceId = const Value.absent(),
    Value<String?> audioRefId = const Value.absent(),
    Value<String?> annotationHash = const Value.absent(),
    Value<int?> annotationRevision = const Value.absent(),
    int? contentRevision,
    Value<String?> firstWrongAttemptId = const Value.absent(),
    Value<String?> latestWrongAttemptId = const Value.absent(),
    int? firstWrongAtUs,
    int? latestWrongAtUs,
    int? failureCount,
    Value<int?> lastRunGeneration = const Value.absent(),
  }) => LearningMistake(
    scopeId: scopeId ?? this.scopeId,
    family: family ?? this.family,
    activityId: activityId.present ? activityId.value : this.activityId,
    itemId: itemId.present ? itemId.value : this.itemId,
    targetSound: targetSound.present ? targetSound.value : this.targetSound,
    skill: skill.present ? skill.value : this.skill,
    pairId: pairId.present ? pairId.value : this.pairId,
    sectionId: sectionId.present ? sectionId.value : this.sectionId,
    sentenceId: sentenceId.present ? sentenceId.value : this.sentenceId,
    audioRefId: audioRefId.present ? audioRefId.value : this.audioRefId,
    annotationHash: annotationHash.present
        ? annotationHash.value
        : this.annotationHash,
    annotationRevision: annotationRevision.present
        ? annotationRevision.value
        : this.annotationRevision,
    contentRevision: contentRevision ?? this.contentRevision,
    firstWrongAttemptId: firstWrongAttemptId.present
        ? firstWrongAttemptId.value
        : this.firstWrongAttemptId,
    latestWrongAttemptId: latestWrongAttemptId.present
        ? latestWrongAttemptId.value
        : this.latestWrongAttemptId,
    firstWrongAtUs: firstWrongAtUs ?? this.firstWrongAtUs,
    latestWrongAtUs: latestWrongAtUs ?? this.latestWrongAtUs,
    failureCount: failureCount ?? this.failureCount,
    lastRunGeneration: lastRunGeneration.present
        ? lastRunGeneration.value
        : this.lastRunGeneration,
  );
  LearningMistake copyWithCompanion(LearningMistakesCompanion data) {
    return LearningMistake(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      family: data.family.present ? data.family.value : this.family,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      targetSound: data.targetSound.present
          ? data.targetSound.value
          : this.targetSound,
      skill: data.skill.present ? data.skill.value : this.skill,
      pairId: data.pairId.present ? data.pairId.value : this.pairId,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      sentenceId: data.sentenceId.present
          ? data.sentenceId.value
          : this.sentenceId,
      audioRefId: data.audioRefId.present
          ? data.audioRefId.value
          : this.audioRefId,
      annotationHash: data.annotationHash.present
          ? data.annotationHash.value
          : this.annotationHash,
      annotationRevision: data.annotationRevision.present
          ? data.annotationRevision.value
          : this.annotationRevision,
      contentRevision: data.contentRevision.present
          ? data.contentRevision.value
          : this.contentRevision,
      firstWrongAttemptId: data.firstWrongAttemptId.present
          ? data.firstWrongAttemptId.value
          : this.firstWrongAttemptId,
      latestWrongAttemptId: data.latestWrongAttemptId.present
          ? data.latestWrongAttemptId.value
          : this.latestWrongAttemptId,
      firstWrongAtUs: data.firstWrongAtUs.present
          ? data.firstWrongAtUs.value
          : this.firstWrongAtUs,
      latestWrongAtUs: data.latestWrongAtUs.present
          ? data.latestWrongAtUs.value
          : this.latestWrongAtUs,
      failureCount: data.failureCount.present
          ? data.failureCount.value
          : this.failureCount,
      lastRunGeneration: data.lastRunGeneration.present
          ? data.lastRunGeneration.value
          : this.lastRunGeneration,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningMistake(')
          ..write('scopeId: $scopeId, ')
          ..write('family: $family, ')
          ..write('activityId: $activityId, ')
          ..write('itemId: $itemId, ')
          ..write('targetSound: $targetSound, ')
          ..write('skill: $skill, ')
          ..write('pairId: $pairId, ')
          ..write('sectionId: $sectionId, ')
          ..write('sentenceId: $sentenceId, ')
          ..write('audioRefId: $audioRefId, ')
          ..write('annotationHash: $annotationHash, ')
          ..write('annotationRevision: $annotationRevision, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('firstWrongAttemptId: $firstWrongAttemptId, ')
          ..write('latestWrongAttemptId: $latestWrongAttemptId, ')
          ..write('firstWrongAtUs: $firstWrongAtUs, ')
          ..write('latestWrongAtUs: $latestWrongAtUs, ')
          ..write('failureCount: $failureCount, ')
          ..write('lastRunGeneration: $lastRunGeneration')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    family,
    activityId,
    itemId,
    targetSound,
    skill,
    pairId,
    sectionId,
    sentenceId,
    audioRefId,
    annotationHash,
    annotationRevision,
    contentRevision,
    firstWrongAttemptId,
    latestWrongAttemptId,
    firstWrongAtUs,
    latestWrongAtUs,
    failureCount,
    lastRunGeneration,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningMistake &&
          other.scopeId == this.scopeId &&
          other.family == this.family &&
          other.activityId == this.activityId &&
          other.itemId == this.itemId &&
          other.targetSound == this.targetSound &&
          other.skill == this.skill &&
          other.pairId == this.pairId &&
          other.sectionId == this.sectionId &&
          other.sentenceId == this.sentenceId &&
          other.audioRefId == this.audioRefId &&
          other.annotationHash == this.annotationHash &&
          other.annotationRevision == this.annotationRevision &&
          other.contentRevision == this.contentRevision &&
          other.firstWrongAttemptId == this.firstWrongAttemptId &&
          other.latestWrongAttemptId == this.latestWrongAttemptId &&
          other.firstWrongAtUs == this.firstWrongAtUs &&
          other.latestWrongAtUs == this.latestWrongAtUs &&
          other.failureCount == this.failureCount &&
          other.lastRunGeneration == this.lastRunGeneration);
}

class LearningMistakesCompanion extends UpdateCompanion<LearningMistake> {
  final Value<int> scopeId;
  final Value<String> family;
  final Value<String?> activityId;
  final Value<String?> itemId;
  final Value<String?> targetSound;
  final Value<String?> skill;
  final Value<String?> pairId;
  final Value<String?> sectionId;
  final Value<String?> sentenceId;
  final Value<String?> audioRefId;
  final Value<String?> annotationHash;
  final Value<int?> annotationRevision;
  final Value<int> contentRevision;
  final Value<String?> firstWrongAttemptId;
  final Value<String?> latestWrongAttemptId;
  final Value<int> firstWrongAtUs;
  final Value<int> latestWrongAtUs;
  final Value<int> failureCount;
  final Value<int?> lastRunGeneration;
  final Value<int> rowid;
  const LearningMistakesCompanion({
    this.scopeId = const Value.absent(),
    this.family = const Value.absent(),
    this.activityId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.targetSound = const Value.absent(),
    this.skill = const Value.absent(),
    this.pairId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.sentenceId = const Value.absent(),
    this.audioRefId = const Value.absent(),
    this.annotationHash = const Value.absent(),
    this.annotationRevision = const Value.absent(),
    this.contentRevision = const Value.absent(),
    this.firstWrongAttemptId = const Value.absent(),
    this.latestWrongAttemptId = const Value.absent(),
    this.firstWrongAtUs = const Value.absent(),
    this.latestWrongAtUs = const Value.absent(),
    this.failureCount = const Value.absent(),
    this.lastRunGeneration = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningMistakesCompanion.insert({
    required int scopeId,
    required String family,
    this.activityId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.targetSound = const Value.absent(),
    this.skill = const Value.absent(),
    this.pairId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.sentenceId = const Value.absent(),
    this.audioRefId = const Value.absent(),
    this.annotationHash = const Value.absent(),
    this.annotationRevision = const Value.absent(),
    required int contentRevision,
    this.firstWrongAttemptId = const Value.absent(),
    this.latestWrongAttemptId = const Value.absent(),
    required int firstWrongAtUs,
    required int latestWrongAtUs,
    required int failureCount,
    this.lastRunGeneration = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       family = Value(family),
       contentRevision = Value(contentRevision),
       firstWrongAtUs = Value(firstWrongAtUs),
       latestWrongAtUs = Value(latestWrongAtUs),
       failureCount = Value(failureCount);
  static Insertable<LearningMistake> custom({
    Expression<int>? scopeId,
    Expression<String>? family,
    Expression<String>? activityId,
    Expression<String>? itemId,
    Expression<String>? targetSound,
    Expression<String>? skill,
    Expression<String>? pairId,
    Expression<String>? sectionId,
    Expression<String>? sentenceId,
    Expression<String>? audioRefId,
    Expression<String>? annotationHash,
    Expression<int>? annotationRevision,
    Expression<int>? contentRevision,
    Expression<String>? firstWrongAttemptId,
    Expression<String>? latestWrongAttemptId,
    Expression<int>? firstWrongAtUs,
    Expression<int>? latestWrongAtUs,
    Expression<int>? failureCount,
    Expression<int>? lastRunGeneration,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (family != null) 'family': family,
      if (activityId != null) 'activity_id': activityId,
      if (itemId != null) 'item_id': itemId,
      if (targetSound != null) 'target_sound': targetSound,
      if (skill != null) 'skill': skill,
      if (pairId != null) 'pair_id': pairId,
      if (sectionId != null) 'section_id': sectionId,
      if (sentenceId != null) 'sentence_id': sentenceId,
      if (audioRefId != null) 'audio_ref_id': audioRefId,
      if (annotationHash != null) 'annotation_hash': annotationHash,
      if (annotationRevision != null) 'annotation_revision': annotationRevision,
      if (contentRevision != null) 'content_revision': contentRevision,
      if (firstWrongAttemptId != null)
        'first_wrong_attempt_id': firstWrongAttemptId,
      if (latestWrongAttemptId != null)
        'latest_wrong_attempt_id': latestWrongAttemptId,
      if (firstWrongAtUs != null) 'first_wrong_at_us': firstWrongAtUs,
      if (latestWrongAtUs != null) 'latest_wrong_at_us': latestWrongAtUs,
      if (failureCount != null) 'failure_count': failureCount,
      if (lastRunGeneration != null) 'last_run_generation': lastRunGeneration,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningMistakesCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? family,
    Value<String?>? activityId,
    Value<String?>? itemId,
    Value<String?>? targetSound,
    Value<String?>? skill,
    Value<String?>? pairId,
    Value<String?>? sectionId,
    Value<String?>? sentenceId,
    Value<String?>? audioRefId,
    Value<String?>? annotationHash,
    Value<int?>? annotationRevision,
    Value<int>? contentRevision,
    Value<String?>? firstWrongAttemptId,
    Value<String?>? latestWrongAttemptId,
    Value<int>? firstWrongAtUs,
    Value<int>? latestWrongAtUs,
    Value<int>? failureCount,
    Value<int?>? lastRunGeneration,
    Value<int>? rowid,
  }) {
    return LearningMistakesCompanion(
      scopeId: scopeId ?? this.scopeId,
      family: family ?? this.family,
      activityId: activityId ?? this.activityId,
      itemId: itemId ?? this.itemId,
      targetSound: targetSound ?? this.targetSound,
      skill: skill ?? this.skill,
      pairId: pairId ?? this.pairId,
      sectionId: sectionId ?? this.sectionId,
      sentenceId: sentenceId ?? this.sentenceId,
      audioRefId: audioRefId ?? this.audioRefId,
      annotationHash: annotationHash ?? this.annotationHash,
      annotationRevision: annotationRevision ?? this.annotationRevision,
      contentRevision: contentRevision ?? this.contentRevision,
      firstWrongAttemptId: firstWrongAttemptId ?? this.firstWrongAttemptId,
      latestWrongAttemptId: latestWrongAttemptId ?? this.latestWrongAttemptId,
      firstWrongAtUs: firstWrongAtUs ?? this.firstWrongAtUs,
      latestWrongAtUs: latestWrongAtUs ?? this.latestWrongAtUs,
      failureCount: failureCount ?? this.failureCount,
      lastRunGeneration: lastRunGeneration ?? this.lastRunGeneration,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (family.present) {
      map['family'] = Variable<String>(family.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (targetSound.present) {
      map['target_sound'] = Variable<String>(targetSound.value);
    }
    if (skill.present) {
      map['skill'] = Variable<String>(skill.value);
    }
    if (pairId.present) {
      map['pair_id'] = Variable<String>(pairId.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (sentenceId.present) {
      map['sentence_id'] = Variable<String>(sentenceId.value);
    }
    if (audioRefId.present) {
      map['audio_ref_id'] = Variable<String>(audioRefId.value);
    }
    if (annotationHash.present) {
      map['annotation_hash'] = Variable<String>(annotationHash.value);
    }
    if (annotationRevision.present) {
      map['annotation_revision'] = Variable<int>(annotationRevision.value);
    }
    if (contentRevision.present) {
      map['content_revision'] = Variable<int>(contentRevision.value);
    }
    if (firstWrongAttemptId.present) {
      map['first_wrong_attempt_id'] = Variable<String>(
        firstWrongAttemptId.value,
      );
    }
    if (latestWrongAttemptId.present) {
      map['latest_wrong_attempt_id'] = Variable<String>(
        latestWrongAttemptId.value,
      );
    }
    if (firstWrongAtUs.present) {
      map['first_wrong_at_us'] = Variable<int>(firstWrongAtUs.value);
    }
    if (latestWrongAtUs.present) {
      map['latest_wrong_at_us'] = Variable<int>(latestWrongAtUs.value);
    }
    if (failureCount.present) {
      map['failure_count'] = Variable<int>(failureCount.value);
    }
    if (lastRunGeneration.present) {
      map['last_run_generation'] = Variable<int>(lastRunGeneration.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningMistakesCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('family: $family, ')
          ..write('activityId: $activityId, ')
          ..write('itemId: $itemId, ')
          ..write('targetSound: $targetSound, ')
          ..write('skill: $skill, ')
          ..write('pairId: $pairId, ')
          ..write('sectionId: $sectionId, ')
          ..write('sentenceId: $sentenceId, ')
          ..write('audioRefId: $audioRefId, ')
          ..write('annotationHash: $annotationHash, ')
          ..write('annotationRevision: $annotationRevision, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('firstWrongAttemptId: $firstWrongAttemptId, ')
          ..write('latestWrongAttemptId: $latestWrongAttemptId, ')
          ..write('firstWrongAtUs: $firstWrongAtUs, ')
          ..write('latestWrongAtUs: $latestWrongAtUs, ')
          ..write('failureCount: $failureCount, ')
          ..write('lastRunGeneration: $lastRunGeneration, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningSummariesTable extends LearningSummaries
    with TableInfo<$LearningSummariesTable, LearningSummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _familyMeta = const VerificationMeta('family');
  @override
  late final GeneratedColumn<String> family = GeneratedColumn<String>(
    'family',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _soundMeta = const VerificationMeta('sound');
  @override
  late final GeneratedColumn<String> sound = GeneratedColumn<String>(
    'sound',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _skillMeta = const VerificationMeta('skill');
  @override
  late final GeneratedColumn<String> skill = GeneratedColumn<String>(
    'skill',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _presentationMeta = const VerificationMeta(
    'presentation',
  );
  @override
  late final GeneratedColumn<String> presentation = GeneratedColumn<String>(
    'presentation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assistanceMaskMeta = const VerificationMeta(
    'assistanceMask',
  );
  @override
  late final GeneratedColumn<int> assistanceMask = GeneratedColumn<int>(
    'assistance_mask',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pairIdMeta = const VerificationMeta('pairId');
  @override
  late final GeneratedColumn<String> pairId = GeneratedColumn<String>(
    'pair_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentenceIdMeta = const VerificationMeta(
    'sentenceId',
  );
  @override
  late final GeneratedColumn<String> sentenceId = GeneratedColumn<String>(
    'sentence_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioRefIdMeta = const VerificationMeta(
    'audioRefId',
  );
  @override
  late final GeneratedColumn<String> audioRefId = GeneratedColumn<String>(
    'audio_ref_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotationHashMeta = const VerificationMeta(
    'annotationHash',
  );
  @override
  late final GeneratedColumn<String> annotationHash = GeneratedColumn<String>(
    'annotation_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotationRevisionMeta =
      const VerificationMeta('annotationRevision');
  @override
  late final GeneratedColumn<int> annotationRevision = GeneratedColumn<int>(
    'annotation_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentRevisionMeta = const VerificationMeta(
    'contentRevision',
  );
  @override
  late final GeneratedColumn<int> contentRevision = GeneratedColumn<int>(
    'content_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bucketMeta = const VerificationMeta('bucket');
  @override
  late final GeneratedColumn<String> bucket = GeneratedColumn<String>(
    'bucket',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<int> correct = GeneratedColumn<int>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    family,
    activityId,
    sound,
    skill,
    origin,
    presentation,
    assistanceMask,
    pairId,
    sectionId,
    itemId,
    sentenceId,
    audioRefId,
    annotationHash,
    annotationRevision,
    contentRevision,
    bucket,
    correct,
    total,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningSummary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('family')) {
      context.handle(
        _familyMeta,
        family.isAcceptableOrUnknown(data['family']!, _familyMeta),
      );
    } else if (isInserting) {
      context.missing(_familyMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    }
    if (data.containsKey('sound')) {
      context.handle(
        _soundMeta,
        sound.isAcceptableOrUnknown(data['sound']!, _soundMeta),
      );
    }
    if (data.containsKey('skill')) {
      context.handle(
        _skillMeta,
        skill.isAcceptableOrUnknown(data['skill']!, _skillMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('presentation')) {
      context.handle(
        _presentationMeta,
        presentation.isAcceptableOrUnknown(
          data['presentation']!,
          _presentationMeta,
        ),
      );
    }
    if (data.containsKey('assistance_mask')) {
      context.handle(
        _assistanceMaskMeta,
        assistanceMask.isAcceptableOrUnknown(
          data['assistance_mask']!,
          _assistanceMaskMeta,
        ),
      );
    }
    if (data.containsKey('pair_id')) {
      context.handle(
        _pairIdMeta,
        pairId.isAcceptableOrUnknown(data['pair_id']!, _pairIdMeta),
      );
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('sentence_id')) {
      context.handle(
        _sentenceIdMeta,
        sentenceId.isAcceptableOrUnknown(data['sentence_id']!, _sentenceIdMeta),
      );
    }
    if (data.containsKey('audio_ref_id')) {
      context.handle(
        _audioRefIdMeta,
        audioRefId.isAcceptableOrUnknown(
          data['audio_ref_id']!,
          _audioRefIdMeta,
        ),
      );
    }
    if (data.containsKey('annotation_hash')) {
      context.handle(
        _annotationHashMeta,
        annotationHash.isAcceptableOrUnknown(
          data['annotation_hash']!,
          _annotationHashMeta,
        ),
      );
    }
    if (data.containsKey('annotation_revision')) {
      context.handle(
        _annotationRevisionMeta,
        annotationRevision.isAcceptableOrUnknown(
          data['annotation_revision']!,
          _annotationRevisionMeta,
        ),
      );
    }
    if (data.containsKey('content_revision')) {
      context.handle(
        _contentRevisionMeta,
        contentRevision.isAcceptableOrUnknown(
          data['content_revision']!,
          _contentRevisionMeta,
        ),
      );
    }
    if (data.containsKey('bucket')) {
      context.handle(
        _bucketMeta,
        bucket.isAcceptableOrUnknown(data['bucket']!, _bucketMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  LearningSummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningSummary(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      family: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      ),
      sound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sound'],
      ),
      skill: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      presentation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}presentation'],
      ),
      assistanceMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}assistance_mask'],
      ),
      pairId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pair_id'],
      ),
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      ),
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      sentenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentence_id'],
      ),
      audioRefId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_ref_id'],
      ),
      annotationHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}annotation_hash'],
      ),
      annotationRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}annotation_revision'],
      ),
      contentRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_revision'],
      ),
      bucket: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
    );
  }

  @override
  $LearningSummariesTable createAlias(String alias) {
    return $LearningSummariesTable(attachedDatabase, alias);
  }
}

class LearningSummary extends DataClass implements Insertable<LearningSummary> {
  final int scopeId;
  final String family;
  final String? activityId;
  final String? sound;
  final String? skill;
  final String? origin;
  final String? presentation;
  final int? assistanceMask;
  final String? pairId;
  final String? sectionId;
  final String? itemId;
  final String? sentenceId;
  final String? audioRefId;
  final String? annotationHash;
  final int? annotationRevision;
  final int? contentRevision;
  final String bucket;
  final int correct;
  final int total;
  const LearningSummary({
    required this.scopeId,
    required this.family,
    this.activityId,
    this.sound,
    this.skill,
    this.origin,
    this.presentation,
    this.assistanceMask,
    this.pairId,
    this.sectionId,
    this.itemId,
    this.sentenceId,
    this.audioRefId,
    this.annotationHash,
    this.annotationRevision,
    this.contentRevision,
    required this.bucket,
    required this.correct,
    required this.total,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['family'] = Variable<String>(family);
    if (!nullToAbsent || activityId != null) {
      map['activity_id'] = Variable<String>(activityId);
    }
    if (!nullToAbsent || sound != null) {
      map['sound'] = Variable<String>(sound);
    }
    if (!nullToAbsent || skill != null) {
      map['skill'] = Variable<String>(skill);
    }
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    if (!nullToAbsent || presentation != null) {
      map['presentation'] = Variable<String>(presentation);
    }
    if (!nullToAbsent || assistanceMask != null) {
      map['assistance_mask'] = Variable<int>(assistanceMask);
    }
    if (!nullToAbsent || pairId != null) {
      map['pair_id'] = Variable<String>(pairId);
    }
    if (!nullToAbsent || sectionId != null) {
      map['section_id'] = Variable<String>(sectionId);
    }
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    if (!nullToAbsent || sentenceId != null) {
      map['sentence_id'] = Variable<String>(sentenceId);
    }
    if (!nullToAbsent || audioRefId != null) {
      map['audio_ref_id'] = Variable<String>(audioRefId);
    }
    if (!nullToAbsent || annotationHash != null) {
      map['annotation_hash'] = Variable<String>(annotationHash);
    }
    if (!nullToAbsent || annotationRevision != null) {
      map['annotation_revision'] = Variable<int>(annotationRevision);
    }
    if (!nullToAbsent || contentRevision != null) {
      map['content_revision'] = Variable<int>(contentRevision);
    }
    map['bucket'] = Variable<String>(bucket);
    map['correct'] = Variable<int>(correct);
    map['total'] = Variable<int>(total);
    return map;
  }

  LearningSummariesCompanion toCompanion(bool nullToAbsent) {
    return LearningSummariesCompanion(
      scopeId: Value(scopeId),
      family: Value(family),
      activityId: activityId == null && nullToAbsent
          ? const Value.absent()
          : Value(activityId),
      sound: sound == null && nullToAbsent
          ? const Value.absent()
          : Value(sound),
      skill: skill == null && nullToAbsent
          ? const Value.absent()
          : Value(skill),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      presentation: presentation == null && nullToAbsent
          ? const Value.absent()
          : Value(presentation),
      assistanceMask: assistanceMask == null && nullToAbsent
          ? const Value.absent()
          : Value(assistanceMask),
      pairId: pairId == null && nullToAbsent
          ? const Value.absent()
          : Value(pairId),
      sectionId: sectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionId),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      sentenceId: sentenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sentenceId),
      audioRefId: audioRefId == null && nullToAbsent
          ? const Value.absent()
          : Value(audioRefId),
      annotationHash: annotationHash == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationHash),
      annotationRevision: annotationRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationRevision),
      contentRevision: contentRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(contentRevision),
      bucket: Value(bucket),
      correct: Value(correct),
      total: Value(total),
    );
  }

  factory LearningSummary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningSummary(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      family: serializer.fromJson<String>(json['family']),
      activityId: serializer.fromJson<String?>(json['activityId']),
      sound: serializer.fromJson<String?>(json['sound']),
      skill: serializer.fromJson<String?>(json['skill']),
      origin: serializer.fromJson<String?>(json['origin']),
      presentation: serializer.fromJson<String?>(json['presentation']),
      assistanceMask: serializer.fromJson<int?>(json['assistanceMask']),
      pairId: serializer.fromJson<String?>(json['pairId']),
      sectionId: serializer.fromJson<String?>(json['sectionId']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      sentenceId: serializer.fromJson<String?>(json['sentenceId']),
      audioRefId: serializer.fromJson<String?>(json['audioRefId']),
      annotationHash: serializer.fromJson<String?>(json['annotationHash']),
      annotationRevision: serializer.fromJson<int?>(json['annotationRevision']),
      contentRevision: serializer.fromJson<int?>(json['contentRevision']),
      bucket: serializer.fromJson<String>(json['bucket']),
      correct: serializer.fromJson<int>(json['correct']),
      total: serializer.fromJson<int>(json['total']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'family': serializer.toJson<String>(family),
      'activityId': serializer.toJson<String?>(activityId),
      'sound': serializer.toJson<String?>(sound),
      'skill': serializer.toJson<String?>(skill),
      'origin': serializer.toJson<String?>(origin),
      'presentation': serializer.toJson<String?>(presentation),
      'assistanceMask': serializer.toJson<int?>(assistanceMask),
      'pairId': serializer.toJson<String?>(pairId),
      'sectionId': serializer.toJson<String?>(sectionId),
      'itemId': serializer.toJson<String?>(itemId),
      'sentenceId': serializer.toJson<String?>(sentenceId),
      'audioRefId': serializer.toJson<String?>(audioRefId),
      'annotationHash': serializer.toJson<String?>(annotationHash),
      'annotationRevision': serializer.toJson<int?>(annotationRevision),
      'contentRevision': serializer.toJson<int?>(contentRevision),
      'bucket': serializer.toJson<String>(bucket),
      'correct': serializer.toJson<int>(correct),
      'total': serializer.toJson<int>(total),
    };
  }

  LearningSummary copyWith({
    int? scopeId,
    String? family,
    Value<String?> activityId = const Value.absent(),
    Value<String?> sound = const Value.absent(),
    Value<String?> skill = const Value.absent(),
    Value<String?> origin = const Value.absent(),
    Value<String?> presentation = const Value.absent(),
    Value<int?> assistanceMask = const Value.absent(),
    Value<String?> pairId = const Value.absent(),
    Value<String?> sectionId = const Value.absent(),
    Value<String?> itemId = const Value.absent(),
    Value<String?> sentenceId = const Value.absent(),
    Value<String?> audioRefId = const Value.absent(),
    Value<String?> annotationHash = const Value.absent(),
    Value<int?> annotationRevision = const Value.absent(),
    Value<int?> contentRevision = const Value.absent(),
    String? bucket,
    int? correct,
    int? total,
  }) => LearningSummary(
    scopeId: scopeId ?? this.scopeId,
    family: family ?? this.family,
    activityId: activityId.present ? activityId.value : this.activityId,
    sound: sound.present ? sound.value : this.sound,
    skill: skill.present ? skill.value : this.skill,
    origin: origin.present ? origin.value : this.origin,
    presentation: presentation.present ? presentation.value : this.presentation,
    assistanceMask: assistanceMask.present
        ? assistanceMask.value
        : this.assistanceMask,
    pairId: pairId.present ? pairId.value : this.pairId,
    sectionId: sectionId.present ? sectionId.value : this.sectionId,
    itemId: itemId.present ? itemId.value : this.itemId,
    sentenceId: sentenceId.present ? sentenceId.value : this.sentenceId,
    audioRefId: audioRefId.present ? audioRefId.value : this.audioRefId,
    annotationHash: annotationHash.present
        ? annotationHash.value
        : this.annotationHash,
    annotationRevision: annotationRevision.present
        ? annotationRevision.value
        : this.annotationRevision,
    contentRevision: contentRevision.present
        ? contentRevision.value
        : this.contentRevision,
    bucket: bucket ?? this.bucket,
    correct: correct ?? this.correct,
    total: total ?? this.total,
  );
  LearningSummary copyWithCompanion(LearningSummariesCompanion data) {
    return LearningSummary(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      family: data.family.present ? data.family.value : this.family,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      sound: data.sound.present ? data.sound.value : this.sound,
      skill: data.skill.present ? data.skill.value : this.skill,
      origin: data.origin.present ? data.origin.value : this.origin,
      presentation: data.presentation.present
          ? data.presentation.value
          : this.presentation,
      assistanceMask: data.assistanceMask.present
          ? data.assistanceMask.value
          : this.assistanceMask,
      pairId: data.pairId.present ? data.pairId.value : this.pairId,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      sentenceId: data.sentenceId.present
          ? data.sentenceId.value
          : this.sentenceId,
      audioRefId: data.audioRefId.present
          ? data.audioRefId.value
          : this.audioRefId,
      annotationHash: data.annotationHash.present
          ? data.annotationHash.value
          : this.annotationHash,
      annotationRevision: data.annotationRevision.present
          ? data.annotationRevision.value
          : this.annotationRevision,
      contentRevision: data.contentRevision.present
          ? data.contentRevision.value
          : this.contentRevision,
      bucket: data.bucket.present ? data.bucket.value : this.bucket,
      correct: data.correct.present ? data.correct.value : this.correct,
      total: data.total.present ? data.total.value : this.total,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningSummary(')
          ..write('scopeId: $scopeId, ')
          ..write('family: $family, ')
          ..write('activityId: $activityId, ')
          ..write('sound: $sound, ')
          ..write('skill: $skill, ')
          ..write('origin: $origin, ')
          ..write('presentation: $presentation, ')
          ..write('assistanceMask: $assistanceMask, ')
          ..write('pairId: $pairId, ')
          ..write('sectionId: $sectionId, ')
          ..write('itemId: $itemId, ')
          ..write('sentenceId: $sentenceId, ')
          ..write('audioRefId: $audioRefId, ')
          ..write('annotationHash: $annotationHash, ')
          ..write('annotationRevision: $annotationRevision, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('bucket: $bucket, ')
          ..write('correct: $correct, ')
          ..write('total: $total')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    family,
    activityId,
    sound,
    skill,
    origin,
    presentation,
    assistanceMask,
    pairId,
    sectionId,
    itemId,
    sentenceId,
    audioRefId,
    annotationHash,
    annotationRevision,
    contentRevision,
    bucket,
    correct,
    total,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningSummary &&
          other.scopeId == this.scopeId &&
          other.family == this.family &&
          other.activityId == this.activityId &&
          other.sound == this.sound &&
          other.skill == this.skill &&
          other.origin == this.origin &&
          other.presentation == this.presentation &&
          other.assistanceMask == this.assistanceMask &&
          other.pairId == this.pairId &&
          other.sectionId == this.sectionId &&
          other.itemId == this.itemId &&
          other.sentenceId == this.sentenceId &&
          other.audioRefId == this.audioRefId &&
          other.annotationHash == this.annotationHash &&
          other.annotationRevision == this.annotationRevision &&
          other.contentRevision == this.contentRevision &&
          other.bucket == this.bucket &&
          other.correct == this.correct &&
          other.total == this.total);
}

class LearningSummariesCompanion extends UpdateCompanion<LearningSummary> {
  final Value<int> scopeId;
  final Value<String> family;
  final Value<String?> activityId;
  final Value<String?> sound;
  final Value<String?> skill;
  final Value<String?> origin;
  final Value<String?> presentation;
  final Value<int?> assistanceMask;
  final Value<String?> pairId;
  final Value<String?> sectionId;
  final Value<String?> itemId;
  final Value<String?> sentenceId;
  final Value<String?> audioRefId;
  final Value<String?> annotationHash;
  final Value<int?> annotationRevision;
  final Value<int?> contentRevision;
  final Value<String> bucket;
  final Value<int> correct;
  final Value<int> total;
  final Value<int> rowid;
  const LearningSummariesCompanion({
    this.scopeId = const Value.absent(),
    this.family = const Value.absent(),
    this.activityId = const Value.absent(),
    this.sound = const Value.absent(),
    this.skill = const Value.absent(),
    this.origin = const Value.absent(),
    this.presentation = const Value.absent(),
    this.assistanceMask = const Value.absent(),
    this.pairId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.sentenceId = const Value.absent(),
    this.audioRefId = const Value.absent(),
    this.annotationHash = const Value.absent(),
    this.annotationRevision = const Value.absent(),
    this.contentRevision = const Value.absent(),
    this.bucket = const Value.absent(),
    this.correct = const Value.absent(),
    this.total = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningSummariesCompanion.insert({
    required int scopeId,
    required String family,
    this.activityId = const Value.absent(),
    this.sound = const Value.absent(),
    this.skill = const Value.absent(),
    this.origin = const Value.absent(),
    this.presentation = const Value.absent(),
    this.assistanceMask = const Value.absent(),
    this.pairId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.sentenceId = const Value.absent(),
    this.audioRefId = const Value.absent(),
    this.annotationHash = const Value.absent(),
    this.annotationRevision = const Value.absent(),
    this.contentRevision = const Value.absent(),
    required String bucket,
    required int correct,
    required int total,
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       family = Value(family),
       bucket = Value(bucket),
       correct = Value(correct),
       total = Value(total);
  static Insertable<LearningSummary> custom({
    Expression<int>? scopeId,
    Expression<String>? family,
    Expression<String>? activityId,
    Expression<String>? sound,
    Expression<String>? skill,
    Expression<String>? origin,
    Expression<String>? presentation,
    Expression<int>? assistanceMask,
    Expression<String>? pairId,
    Expression<String>? sectionId,
    Expression<String>? itemId,
    Expression<String>? sentenceId,
    Expression<String>? audioRefId,
    Expression<String>? annotationHash,
    Expression<int>? annotationRevision,
    Expression<int>? contentRevision,
    Expression<String>? bucket,
    Expression<int>? correct,
    Expression<int>? total,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (family != null) 'family': family,
      if (activityId != null) 'activity_id': activityId,
      if (sound != null) 'sound': sound,
      if (skill != null) 'skill': skill,
      if (origin != null) 'origin': origin,
      if (presentation != null) 'presentation': presentation,
      if (assistanceMask != null) 'assistance_mask': assistanceMask,
      if (pairId != null) 'pair_id': pairId,
      if (sectionId != null) 'section_id': sectionId,
      if (itemId != null) 'item_id': itemId,
      if (sentenceId != null) 'sentence_id': sentenceId,
      if (audioRefId != null) 'audio_ref_id': audioRefId,
      if (annotationHash != null) 'annotation_hash': annotationHash,
      if (annotationRevision != null) 'annotation_revision': annotationRevision,
      if (contentRevision != null) 'content_revision': contentRevision,
      if (bucket != null) 'bucket': bucket,
      if (correct != null) 'correct': correct,
      if (total != null) 'total': total,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningSummariesCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? family,
    Value<String?>? activityId,
    Value<String?>? sound,
    Value<String?>? skill,
    Value<String?>? origin,
    Value<String?>? presentation,
    Value<int?>? assistanceMask,
    Value<String?>? pairId,
    Value<String?>? sectionId,
    Value<String?>? itemId,
    Value<String?>? sentenceId,
    Value<String?>? audioRefId,
    Value<String?>? annotationHash,
    Value<int?>? annotationRevision,
    Value<int?>? contentRevision,
    Value<String>? bucket,
    Value<int>? correct,
    Value<int>? total,
    Value<int>? rowid,
  }) {
    return LearningSummariesCompanion(
      scopeId: scopeId ?? this.scopeId,
      family: family ?? this.family,
      activityId: activityId ?? this.activityId,
      sound: sound ?? this.sound,
      skill: skill ?? this.skill,
      origin: origin ?? this.origin,
      presentation: presentation ?? this.presentation,
      assistanceMask: assistanceMask ?? this.assistanceMask,
      pairId: pairId ?? this.pairId,
      sectionId: sectionId ?? this.sectionId,
      itemId: itemId ?? this.itemId,
      sentenceId: sentenceId ?? this.sentenceId,
      audioRefId: audioRefId ?? this.audioRefId,
      annotationHash: annotationHash ?? this.annotationHash,
      annotationRevision: annotationRevision ?? this.annotationRevision,
      contentRevision: contentRevision ?? this.contentRevision,
      bucket: bucket ?? this.bucket,
      correct: correct ?? this.correct,
      total: total ?? this.total,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (family.present) {
      map['family'] = Variable<String>(family.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (sound.present) {
      map['sound'] = Variable<String>(sound.value);
    }
    if (skill.present) {
      map['skill'] = Variable<String>(skill.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (presentation.present) {
      map['presentation'] = Variable<String>(presentation.value);
    }
    if (assistanceMask.present) {
      map['assistance_mask'] = Variable<int>(assistanceMask.value);
    }
    if (pairId.present) {
      map['pair_id'] = Variable<String>(pairId.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (sentenceId.present) {
      map['sentence_id'] = Variable<String>(sentenceId.value);
    }
    if (audioRefId.present) {
      map['audio_ref_id'] = Variable<String>(audioRefId.value);
    }
    if (annotationHash.present) {
      map['annotation_hash'] = Variable<String>(annotationHash.value);
    }
    if (annotationRevision.present) {
      map['annotation_revision'] = Variable<int>(annotationRevision.value);
    }
    if (contentRevision.present) {
      map['content_revision'] = Variable<int>(contentRevision.value);
    }
    if (bucket.present) {
      map['bucket'] = Variable<String>(bucket.value);
    }
    if (correct.present) {
      map['correct'] = Variable<int>(correct.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningSummariesCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('family: $family, ')
          ..write('activityId: $activityId, ')
          ..write('sound: $sound, ')
          ..write('skill: $skill, ')
          ..write('origin: $origin, ')
          ..write('presentation: $presentation, ')
          ..write('assistanceMask: $assistanceMask, ')
          ..write('pairId: $pairId, ')
          ..write('sectionId: $sectionId, ')
          ..write('itemId: $itemId, ')
          ..write('sentenceId: $sentenceId, ')
          ..write('audioRefId: $audioRefId, ')
          ..write('annotationHash: $annotationHash, ')
          ..write('annotationRevision: $annotationRevision, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('bucket: $bucket, ')
          ..write('correct: $correct, ')
          ..write('total: $total, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningCompletionsTable extends LearningCompletions
    with TableInfo<$LearningCompletionsTable, LearningCompletion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningCompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentRevisionMeta = const VerificationMeta(
    'contentRevision',
  );
  @override
  late final GeneratedColumn<int> contentRevision = GeneratedColumn<int>(
    'content_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _policyKindMeta = const VerificationMeta(
    'policyKind',
  );
  @override
  late final GeneratedColumn<String> policyKind = GeneratedColumn<String>(
    'policy_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _policyRevisionMeta = const VerificationMeta(
    'policyRevision',
  );
  @override
  late final GeneratedColumn<int> policyRevision = GeneratedColumn<int>(
    'policy_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thresholdPercentMeta = const VerificationMeta(
    'thresholdPercent',
  );
  @override
  late final GeneratedColumn<int> thresholdPercent = GeneratedColumn<int>(
    'threshold_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _committedAtUsMeta = const VerificationMeta(
    'committedAtUs',
  );
  @override
  late final GeneratedColumn<int> committedAtUs = GeneratedColumn<int>(
    'committed_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    activityId,
    contentRevision,
    policyKind,
    policyRevision,
    thresholdPercent,
    committedAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_completions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningCompletion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('content_revision')) {
      context.handle(
        _contentRevisionMeta,
        contentRevision.isAcceptableOrUnknown(
          data['content_revision']!,
          _contentRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentRevisionMeta);
    }
    if (data.containsKey('policy_kind')) {
      context.handle(
        _policyKindMeta,
        policyKind.isAcceptableOrUnknown(data['policy_kind']!, _policyKindMeta),
      );
    } else if (isInserting) {
      context.missing(_policyKindMeta);
    }
    if (data.containsKey('policy_revision')) {
      context.handle(
        _policyRevisionMeta,
        policyRevision.isAcceptableOrUnknown(
          data['policy_revision']!,
          _policyRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_policyRevisionMeta);
    }
    if (data.containsKey('threshold_percent')) {
      context.handle(
        _thresholdPercentMeta,
        thresholdPercent.isAcceptableOrUnknown(
          data['threshold_percent']!,
          _thresholdPercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_thresholdPercentMeta);
    }
    if (data.containsKey('committed_at_us')) {
      context.handle(
        _committedAtUsMeta,
        committedAtUs.isAcceptableOrUnknown(
          data['committed_at_us']!,
          _committedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_committedAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  LearningCompletion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningCompletion(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      contentRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_revision'],
      )!,
      policyKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}policy_kind'],
      )!,
      policyRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}policy_revision'],
      )!,
      thresholdPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}threshold_percent'],
      )!,
      committedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}committed_at_us'],
      )!,
    );
  }

  @override
  $LearningCompletionsTable createAlias(String alias) {
    return $LearningCompletionsTable(attachedDatabase, alias);
  }
}

class LearningCompletion extends DataClass
    implements Insertable<LearningCompletion> {
  final int scopeId;
  final String activityId;
  final int contentRevision;
  final String policyKind;
  final int policyRevision;
  final int thresholdPercent;
  final int committedAtUs;
  const LearningCompletion({
    required this.scopeId,
    required this.activityId,
    required this.contentRevision,
    required this.policyKind,
    required this.policyRevision,
    required this.thresholdPercent,
    required this.committedAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['activity_id'] = Variable<String>(activityId);
    map['content_revision'] = Variable<int>(contentRevision);
    map['policy_kind'] = Variable<String>(policyKind);
    map['policy_revision'] = Variable<int>(policyRevision);
    map['threshold_percent'] = Variable<int>(thresholdPercent);
    map['committed_at_us'] = Variable<int>(committedAtUs);
    return map;
  }

  LearningCompletionsCompanion toCompanion(bool nullToAbsent) {
    return LearningCompletionsCompanion(
      scopeId: Value(scopeId),
      activityId: Value(activityId),
      contentRevision: Value(contentRevision),
      policyKind: Value(policyKind),
      policyRevision: Value(policyRevision),
      thresholdPercent: Value(thresholdPercent),
      committedAtUs: Value(committedAtUs),
    );
  }

  factory LearningCompletion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningCompletion(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      activityId: serializer.fromJson<String>(json['activityId']),
      contentRevision: serializer.fromJson<int>(json['contentRevision']),
      policyKind: serializer.fromJson<String>(json['policyKind']),
      policyRevision: serializer.fromJson<int>(json['policyRevision']),
      thresholdPercent: serializer.fromJson<int>(json['thresholdPercent']),
      committedAtUs: serializer.fromJson<int>(json['committedAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'activityId': serializer.toJson<String>(activityId),
      'contentRevision': serializer.toJson<int>(contentRevision),
      'policyKind': serializer.toJson<String>(policyKind),
      'policyRevision': serializer.toJson<int>(policyRevision),
      'thresholdPercent': serializer.toJson<int>(thresholdPercent),
      'committedAtUs': serializer.toJson<int>(committedAtUs),
    };
  }

  LearningCompletion copyWith({
    int? scopeId,
    String? activityId,
    int? contentRevision,
    String? policyKind,
    int? policyRevision,
    int? thresholdPercent,
    int? committedAtUs,
  }) => LearningCompletion(
    scopeId: scopeId ?? this.scopeId,
    activityId: activityId ?? this.activityId,
    contentRevision: contentRevision ?? this.contentRevision,
    policyKind: policyKind ?? this.policyKind,
    policyRevision: policyRevision ?? this.policyRevision,
    thresholdPercent: thresholdPercent ?? this.thresholdPercent,
    committedAtUs: committedAtUs ?? this.committedAtUs,
  );
  LearningCompletion copyWithCompanion(LearningCompletionsCompanion data) {
    return LearningCompletion(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      contentRevision: data.contentRevision.present
          ? data.contentRevision.value
          : this.contentRevision,
      policyKind: data.policyKind.present
          ? data.policyKind.value
          : this.policyKind,
      policyRevision: data.policyRevision.present
          ? data.policyRevision.value
          : this.policyRevision,
      thresholdPercent: data.thresholdPercent.present
          ? data.thresholdPercent.value
          : this.thresholdPercent,
      committedAtUs: data.committedAtUs.present
          ? data.committedAtUs.value
          : this.committedAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningCompletion(')
          ..write('scopeId: $scopeId, ')
          ..write('activityId: $activityId, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('policyKind: $policyKind, ')
          ..write('policyRevision: $policyRevision, ')
          ..write('thresholdPercent: $thresholdPercent, ')
          ..write('committedAtUs: $committedAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    activityId,
    contentRevision,
    policyKind,
    policyRevision,
    thresholdPercent,
    committedAtUs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningCompletion &&
          other.scopeId == this.scopeId &&
          other.activityId == this.activityId &&
          other.contentRevision == this.contentRevision &&
          other.policyKind == this.policyKind &&
          other.policyRevision == this.policyRevision &&
          other.thresholdPercent == this.thresholdPercent &&
          other.committedAtUs == this.committedAtUs);
}

class LearningCompletionsCompanion extends UpdateCompanion<LearningCompletion> {
  final Value<int> scopeId;
  final Value<String> activityId;
  final Value<int> contentRevision;
  final Value<String> policyKind;
  final Value<int> policyRevision;
  final Value<int> thresholdPercent;
  final Value<int> committedAtUs;
  final Value<int> rowid;
  const LearningCompletionsCompanion({
    this.scopeId = const Value.absent(),
    this.activityId = const Value.absent(),
    this.contentRevision = const Value.absent(),
    this.policyKind = const Value.absent(),
    this.policyRevision = const Value.absent(),
    this.thresholdPercent = const Value.absent(),
    this.committedAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningCompletionsCompanion.insert({
    required int scopeId,
    required String activityId,
    required int contentRevision,
    required String policyKind,
    required int policyRevision,
    required int thresholdPercent,
    required int committedAtUs,
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       activityId = Value(activityId),
       contentRevision = Value(contentRevision),
       policyKind = Value(policyKind),
       policyRevision = Value(policyRevision),
       thresholdPercent = Value(thresholdPercent),
       committedAtUs = Value(committedAtUs);
  static Insertable<LearningCompletion> custom({
    Expression<int>? scopeId,
    Expression<String>? activityId,
    Expression<int>? contentRevision,
    Expression<String>? policyKind,
    Expression<int>? policyRevision,
    Expression<int>? thresholdPercent,
    Expression<int>? committedAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (activityId != null) 'activity_id': activityId,
      if (contentRevision != null) 'content_revision': contentRevision,
      if (policyKind != null) 'policy_kind': policyKind,
      if (policyRevision != null) 'policy_revision': policyRevision,
      if (thresholdPercent != null) 'threshold_percent': thresholdPercent,
      if (committedAtUs != null) 'committed_at_us': committedAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningCompletionsCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? activityId,
    Value<int>? contentRevision,
    Value<String>? policyKind,
    Value<int>? policyRevision,
    Value<int>? thresholdPercent,
    Value<int>? committedAtUs,
    Value<int>? rowid,
  }) {
    return LearningCompletionsCompanion(
      scopeId: scopeId ?? this.scopeId,
      activityId: activityId ?? this.activityId,
      contentRevision: contentRevision ?? this.contentRevision,
      policyKind: policyKind ?? this.policyKind,
      policyRevision: policyRevision ?? this.policyRevision,
      thresholdPercent: thresholdPercent ?? this.thresholdPercent,
      committedAtUs: committedAtUs ?? this.committedAtUs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (contentRevision.present) {
      map['content_revision'] = Variable<int>(contentRevision.value);
    }
    if (policyKind.present) {
      map['policy_kind'] = Variable<String>(policyKind.value);
    }
    if (policyRevision.present) {
      map['policy_revision'] = Variable<int>(policyRevision.value);
    }
    if (thresholdPercent.present) {
      map['threshold_percent'] = Variable<int>(thresholdPercent.value);
    }
    if (committedAtUs.present) {
      map['committed_at_us'] = Variable<int>(committedAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningCompletionsCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('activityId: $activityId, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('policyKind: $policyKind, ')
          ..write('policyRevision: $policyRevision, ')
          ..write('thresholdPercent: $thresholdPercent, ')
          ..write('committedAtUs: $committedAtUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningExposureTable extends LearningExposure
    with TableInfo<$LearningExposureTable, LearningExposureData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningExposureTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _familyMeta = const VerificationMeta('family');
  @override
  late final GeneratedColumn<String> family = GeneratedColumn<String>(
    'family',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetSoundMeta = const VerificationMeta(
    'targetSound',
  );
  @override
  late final GeneratedColumn<String> targetSound = GeneratedColumn<String>(
    'target_sound',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentRevisionMeta = const VerificationMeta(
    'contentRevision',
  );
  @override
  late final GeneratedColumn<int> contentRevision = GeneratedColumn<int>(
    'content_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _presentationsMeta = const VerificationMeta(
    'presentations',
  );
  @override
  late final GeneratedColumn<int> presentations = GeneratedColumn<int>(
    'presentations',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assistanceMaskMeta = const VerificationMeta(
    'assistanceMask',
  );
  @override
  late final GeneratedColumn<int> assistanceMask = GeneratedColumn<int>(
    'assistance_mask',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    family,
    activityId,
    itemId,
    targetSound,
    sectionId,
    contentRevision,
    presentations,
    assistanceMask,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_exposure';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningExposureData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('family')) {
      context.handle(
        _familyMeta,
        family.isAcceptableOrUnknown(data['family']!, _familyMeta),
      );
    } else if (isInserting) {
      context.missing(_familyMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('target_sound')) {
      context.handle(
        _targetSoundMeta,
        targetSound.isAcceptableOrUnknown(
          data['target_sound']!,
          _targetSoundMeta,
        ),
      );
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    }
    if (data.containsKey('content_revision')) {
      context.handle(
        _contentRevisionMeta,
        contentRevision.isAcceptableOrUnknown(
          data['content_revision']!,
          _contentRevisionMeta,
        ),
      );
    }
    if (data.containsKey('presentations')) {
      context.handle(
        _presentationsMeta,
        presentations.isAcceptableOrUnknown(
          data['presentations']!,
          _presentationsMeta,
        ),
      );
    }
    if (data.containsKey('assistance_mask')) {
      context.handle(
        _assistanceMaskMeta,
        assistanceMask.isAcceptableOrUnknown(
          data['assistance_mask']!,
          _assistanceMaskMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  LearningExposureData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningExposureData(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      family: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      ),
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      targetSound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_sound'],
      ),
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      ),
      contentRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_revision'],
      ),
      presentations: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}presentations'],
      ),
      assistanceMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}assistance_mask'],
      ),
    );
  }

  @override
  $LearningExposureTable createAlias(String alias) {
    return $LearningExposureTable(attachedDatabase, alias);
  }
}

class LearningExposureData extends DataClass
    implements Insertable<LearningExposureData> {
  final int scopeId;
  final String family;
  final String? activityId;
  final String? itemId;
  final String? targetSound;
  final String? sectionId;
  final int? contentRevision;
  final int? presentations;
  final int? assistanceMask;
  const LearningExposureData({
    required this.scopeId,
    required this.family,
    this.activityId,
    this.itemId,
    this.targetSound,
    this.sectionId,
    this.contentRevision,
    this.presentations,
    this.assistanceMask,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['family'] = Variable<String>(family);
    if (!nullToAbsent || activityId != null) {
      map['activity_id'] = Variable<String>(activityId);
    }
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    if (!nullToAbsent || targetSound != null) {
      map['target_sound'] = Variable<String>(targetSound);
    }
    if (!nullToAbsent || sectionId != null) {
      map['section_id'] = Variable<String>(sectionId);
    }
    if (!nullToAbsent || contentRevision != null) {
      map['content_revision'] = Variable<int>(contentRevision);
    }
    if (!nullToAbsent || presentations != null) {
      map['presentations'] = Variable<int>(presentations);
    }
    if (!nullToAbsent || assistanceMask != null) {
      map['assistance_mask'] = Variable<int>(assistanceMask);
    }
    return map;
  }

  LearningExposureCompanion toCompanion(bool nullToAbsent) {
    return LearningExposureCompanion(
      scopeId: Value(scopeId),
      family: Value(family),
      activityId: activityId == null && nullToAbsent
          ? const Value.absent()
          : Value(activityId),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      targetSound: targetSound == null && nullToAbsent
          ? const Value.absent()
          : Value(targetSound),
      sectionId: sectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionId),
      contentRevision: contentRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(contentRevision),
      presentations: presentations == null && nullToAbsent
          ? const Value.absent()
          : Value(presentations),
      assistanceMask: assistanceMask == null && nullToAbsent
          ? const Value.absent()
          : Value(assistanceMask),
    );
  }

  factory LearningExposureData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningExposureData(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      family: serializer.fromJson<String>(json['family']),
      activityId: serializer.fromJson<String?>(json['activityId']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      targetSound: serializer.fromJson<String?>(json['targetSound']),
      sectionId: serializer.fromJson<String?>(json['sectionId']),
      contentRevision: serializer.fromJson<int?>(json['contentRevision']),
      presentations: serializer.fromJson<int?>(json['presentations']),
      assistanceMask: serializer.fromJson<int?>(json['assistanceMask']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'family': serializer.toJson<String>(family),
      'activityId': serializer.toJson<String?>(activityId),
      'itemId': serializer.toJson<String?>(itemId),
      'targetSound': serializer.toJson<String?>(targetSound),
      'sectionId': serializer.toJson<String?>(sectionId),
      'contentRevision': serializer.toJson<int?>(contentRevision),
      'presentations': serializer.toJson<int?>(presentations),
      'assistanceMask': serializer.toJson<int?>(assistanceMask),
    };
  }

  LearningExposureData copyWith({
    int? scopeId,
    String? family,
    Value<String?> activityId = const Value.absent(),
    Value<String?> itemId = const Value.absent(),
    Value<String?> targetSound = const Value.absent(),
    Value<String?> sectionId = const Value.absent(),
    Value<int?> contentRevision = const Value.absent(),
    Value<int?> presentations = const Value.absent(),
    Value<int?> assistanceMask = const Value.absent(),
  }) => LearningExposureData(
    scopeId: scopeId ?? this.scopeId,
    family: family ?? this.family,
    activityId: activityId.present ? activityId.value : this.activityId,
    itemId: itemId.present ? itemId.value : this.itemId,
    targetSound: targetSound.present ? targetSound.value : this.targetSound,
    sectionId: sectionId.present ? sectionId.value : this.sectionId,
    contentRevision: contentRevision.present
        ? contentRevision.value
        : this.contentRevision,
    presentations: presentations.present
        ? presentations.value
        : this.presentations,
    assistanceMask: assistanceMask.present
        ? assistanceMask.value
        : this.assistanceMask,
  );
  LearningExposureData copyWithCompanion(LearningExposureCompanion data) {
    return LearningExposureData(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      family: data.family.present ? data.family.value : this.family,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      targetSound: data.targetSound.present
          ? data.targetSound.value
          : this.targetSound,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      contentRevision: data.contentRevision.present
          ? data.contentRevision.value
          : this.contentRevision,
      presentations: data.presentations.present
          ? data.presentations.value
          : this.presentations,
      assistanceMask: data.assistanceMask.present
          ? data.assistanceMask.value
          : this.assistanceMask,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningExposureData(')
          ..write('scopeId: $scopeId, ')
          ..write('family: $family, ')
          ..write('activityId: $activityId, ')
          ..write('itemId: $itemId, ')
          ..write('targetSound: $targetSound, ')
          ..write('sectionId: $sectionId, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('presentations: $presentations, ')
          ..write('assistanceMask: $assistanceMask')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    family,
    activityId,
    itemId,
    targetSound,
    sectionId,
    contentRevision,
    presentations,
    assistanceMask,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningExposureData &&
          other.scopeId == this.scopeId &&
          other.family == this.family &&
          other.activityId == this.activityId &&
          other.itemId == this.itemId &&
          other.targetSound == this.targetSound &&
          other.sectionId == this.sectionId &&
          other.contentRevision == this.contentRevision &&
          other.presentations == this.presentations &&
          other.assistanceMask == this.assistanceMask);
}

class LearningExposureCompanion extends UpdateCompanion<LearningExposureData> {
  final Value<int> scopeId;
  final Value<String> family;
  final Value<String?> activityId;
  final Value<String?> itemId;
  final Value<String?> targetSound;
  final Value<String?> sectionId;
  final Value<int?> contentRevision;
  final Value<int?> presentations;
  final Value<int?> assistanceMask;
  final Value<int> rowid;
  const LearningExposureCompanion({
    this.scopeId = const Value.absent(),
    this.family = const Value.absent(),
    this.activityId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.targetSound = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.contentRevision = const Value.absent(),
    this.presentations = const Value.absent(),
    this.assistanceMask = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningExposureCompanion.insert({
    required int scopeId,
    required String family,
    this.activityId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.targetSound = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.contentRevision = const Value.absent(),
    this.presentations = const Value.absent(),
    this.assistanceMask = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       family = Value(family);
  static Insertable<LearningExposureData> custom({
    Expression<int>? scopeId,
    Expression<String>? family,
    Expression<String>? activityId,
    Expression<String>? itemId,
    Expression<String>? targetSound,
    Expression<String>? sectionId,
    Expression<int>? contentRevision,
    Expression<int>? presentations,
    Expression<int>? assistanceMask,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (family != null) 'family': family,
      if (activityId != null) 'activity_id': activityId,
      if (itemId != null) 'item_id': itemId,
      if (targetSound != null) 'target_sound': targetSound,
      if (sectionId != null) 'section_id': sectionId,
      if (contentRevision != null) 'content_revision': contentRevision,
      if (presentations != null) 'presentations': presentations,
      if (assistanceMask != null) 'assistance_mask': assistanceMask,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningExposureCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? family,
    Value<String?>? activityId,
    Value<String?>? itemId,
    Value<String?>? targetSound,
    Value<String?>? sectionId,
    Value<int?>? contentRevision,
    Value<int?>? presentations,
    Value<int?>? assistanceMask,
    Value<int>? rowid,
  }) {
    return LearningExposureCompanion(
      scopeId: scopeId ?? this.scopeId,
      family: family ?? this.family,
      activityId: activityId ?? this.activityId,
      itemId: itemId ?? this.itemId,
      targetSound: targetSound ?? this.targetSound,
      sectionId: sectionId ?? this.sectionId,
      contentRevision: contentRevision ?? this.contentRevision,
      presentations: presentations ?? this.presentations,
      assistanceMask: assistanceMask ?? this.assistanceMask,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (family.present) {
      map['family'] = Variable<String>(family.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (targetSound.present) {
      map['target_sound'] = Variable<String>(targetSound.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (contentRevision.present) {
      map['content_revision'] = Variable<int>(contentRevision.value);
    }
    if (presentations.present) {
      map['presentations'] = Variable<int>(presentations.value);
    }
    if (assistanceMask.present) {
      map['assistance_mask'] = Variable<int>(assistanceMask.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningExposureCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('family: $family, ')
          ..write('activityId: $activityId, ')
          ..write('itemId: $itemId, ')
          ..write('targetSound: $targetSound, ')
          ..write('sectionId: $sectionId, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('presentations: $presentations, ')
          ..write('assistanceMask: $assistanceMask, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningBestScoresTable extends LearningBestScores
    with TableInfo<$LearningBestScoresTable, LearningBestScore> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningBestScoresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [scopeId, activityId, score];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_best_scores';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningBestScore> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scopeId, activityId};
  @override
  LearningBestScore map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningBestScore(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
    );
  }

  @override
  $LearningBestScoresTable createAlias(String alias) {
    return $LearningBestScoresTable(attachedDatabase, alias);
  }
}

class LearningBestScore extends DataClass
    implements Insertable<LearningBestScore> {
  final int scopeId;
  final String activityId;
  final int score;
  const LearningBestScore({
    required this.scopeId,
    required this.activityId,
    required this.score,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['activity_id'] = Variable<String>(activityId);
    map['score'] = Variable<int>(score);
    return map;
  }

  LearningBestScoresCompanion toCompanion(bool nullToAbsent) {
    return LearningBestScoresCompanion(
      scopeId: Value(scopeId),
      activityId: Value(activityId),
      score: Value(score),
    );
  }

  factory LearningBestScore.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningBestScore(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      activityId: serializer.fromJson<String>(json['activityId']),
      score: serializer.fromJson<int>(json['score']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'activityId': serializer.toJson<String>(activityId),
      'score': serializer.toJson<int>(score),
    };
  }

  LearningBestScore copyWith({int? scopeId, String? activityId, int? score}) =>
      LearningBestScore(
        scopeId: scopeId ?? this.scopeId,
        activityId: activityId ?? this.activityId,
        score: score ?? this.score,
      );
  LearningBestScore copyWithCompanion(LearningBestScoresCompanion data) {
    return LearningBestScore(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      score: data.score.present ? data.score.value : this.score,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningBestScore(')
          ..write('scopeId: $scopeId, ')
          ..write('activityId: $activityId, ')
          ..write('score: $score')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scopeId, activityId, score);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningBestScore &&
          other.scopeId == this.scopeId &&
          other.activityId == this.activityId &&
          other.score == this.score);
}

class LearningBestScoresCompanion extends UpdateCompanion<LearningBestScore> {
  final Value<int> scopeId;
  final Value<String> activityId;
  final Value<int> score;
  final Value<int> rowid;
  const LearningBestScoresCompanion({
    this.scopeId = const Value.absent(),
    this.activityId = const Value.absent(),
    this.score = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningBestScoresCompanion.insert({
    required int scopeId,
    required String activityId,
    required int score,
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       activityId = Value(activityId),
       score = Value(score);
  static Insertable<LearningBestScore> custom({
    Expression<int>? scopeId,
    Expression<String>? activityId,
    Expression<int>? score,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (activityId != null) 'activity_id': activityId,
      if (score != null) 'score': score,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningBestScoresCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? activityId,
    Value<int>? score,
    Value<int>? rowid,
  }) {
    return LearningBestScoresCompanion(
      scopeId: scopeId ?? this.scopeId,
      activityId: activityId ?? this.activityId,
      score: score ?? this.score,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningBestScoresCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('activityId: $activityId, ')
          ..write('score: $score, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SupportedSyncOutboxTable extends SupportedSyncOutbox
    with TableInfo<$SupportedSyncOutboxTable, SupportedSyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SupportedSyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<int> scopeId = GeneratedColumn<int>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_scopes (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enqueueCommitOrdinalMeta =
      const VerificationMeta('enqueueCommitOrdinal');
  @override
  late final GeneratedColumn<int> enqueueCommitOrdinal = GeneratedColumn<int>(
    'enqueue_commit_ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enqueueEventIndexMeta = const VerificationMeta(
    'enqueueEventIndex',
  );
  @override
  late final GeneratedColumn<int> enqueueEventIndex = GeneratedColumn<int>(
    'enqueue_event_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _soundMeta = const VerificationMeta('sound');
  @override
  late final GeneratedColumn<String> sound = GeneratedColumn<String>(
    'sound',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _skillMeta = const VerificationMeta('skill');
  @override
  late final GeneratedColumn<String> skill = GeneratedColumn<String>(
    'skill',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<int> correct = GeneratedColumn<int>(
    'correct',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activityMeta = const VerificationMeta(
    'activity',
  );
  @override
  late final GeneratedColumn<String> activity = GeneratedColumn<String>(
    'activity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gameMeta = const VerificationMeta('game');
  @override
  late final GeneratedColumn<String> game = GeneratedColumn<String>(
    'game',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scopeId,
    eventId,
    enqueueCommitOrdinal,
    enqueueEventIndex,
    userId,
    courseId,
    kind,
    sound,
    skill,
    correct,
    activity,
    lessonId,
    game,
    score,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'supported_sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SupportedSyncOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('enqueue_commit_ordinal')) {
      context.handle(
        _enqueueCommitOrdinalMeta,
        enqueueCommitOrdinal.isAcceptableOrUnknown(
          data['enqueue_commit_ordinal']!,
          _enqueueCommitOrdinalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_enqueueCommitOrdinalMeta);
    }
    if (data.containsKey('enqueue_event_index')) {
      context.handle(
        _enqueueEventIndexMeta,
        enqueueEventIndex.isAcceptableOrUnknown(
          data['enqueue_event_index']!,
          _enqueueEventIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_enqueueEventIndexMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('sound')) {
      context.handle(
        _soundMeta,
        sound.isAcceptableOrUnknown(data['sound']!, _soundMeta),
      );
    }
    if (data.containsKey('skill')) {
      context.handle(
        _skillMeta,
        skill.isAcceptableOrUnknown(data['skill']!, _skillMeta),
      );
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    }
    if (data.containsKey('activity')) {
      context.handle(
        _activityMeta,
        activity.isAcceptableOrUnknown(data['activity']!, _activityMeta),
      );
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    }
    if (data.containsKey('game')) {
      context.handle(
        _gameMeta,
        game.isAcceptableOrUnknown(data['game']!, _gameMeta),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  SupportedSyncOutboxData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SupportedSyncOutboxData(
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scope_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      enqueueCommitOrdinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enqueue_commit_ordinal'],
      )!,
      enqueueEventIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enqueue_event_index'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      sound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sound'],
      ),
      skill: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill'],
      ),
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct'],
      ),
      activity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity'],
      ),
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      ),
      game: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game'],
      ),
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      ),
    );
  }

  @override
  $SupportedSyncOutboxTable createAlias(String alias) {
    return $SupportedSyncOutboxTable(attachedDatabase, alias);
  }
}

class SupportedSyncOutboxData extends DataClass
    implements Insertable<SupportedSyncOutboxData> {
  final int scopeId;
  final String eventId;
  final int enqueueCommitOrdinal;
  final int enqueueEventIndex;
  final String userId;
  final String courseId;
  final String kind;
  final String? sound;
  final String? skill;
  final int? correct;
  final String? activity;
  final String? lessonId;
  final String? game;
  final int? score;
  const SupportedSyncOutboxData({
    required this.scopeId,
    required this.eventId,
    required this.enqueueCommitOrdinal,
    required this.enqueueEventIndex,
    required this.userId,
    required this.courseId,
    required this.kind,
    this.sound,
    this.skill,
    this.correct,
    this.activity,
    this.lessonId,
    this.game,
    this.score,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_id'] = Variable<int>(scopeId);
    map['event_id'] = Variable<String>(eventId);
    map['enqueue_commit_ordinal'] = Variable<int>(enqueueCommitOrdinal);
    map['enqueue_event_index'] = Variable<int>(enqueueEventIndex);
    map['user_id'] = Variable<String>(userId);
    map['course_id'] = Variable<String>(courseId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || sound != null) {
      map['sound'] = Variable<String>(sound);
    }
    if (!nullToAbsent || skill != null) {
      map['skill'] = Variable<String>(skill);
    }
    if (!nullToAbsent || correct != null) {
      map['correct'] = Variable<int>(correct);
    }
    if (!nullToAbsent || activity != null) {
      map['activity'] = Variable<String>(activity);
    }
    if (!nullToAbsent || lessonId != null) {
      map['lesson_id'] = Variable<String>(lessonId);
    }
    if (!nullToAbsent || game != null) {
      map['game'] = Variable<String>(game);
    }
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<int>(score);
    }
    return map;
  }

  SupportedSyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SupportedSyncOutboxCompanion(
      scopeId: Value(scopeId),
      eventId: Value(eventId),
      enqueueCommitOrdinal: Value(enqueueCommitOrdinal),
      enqueueEventIndex: Value(enqueueEventIndex),
      userId: Value(userId),
      courseId: Value(courseId),
      kind: Value(kind),
      sound: sound == null && nullToAbsent
          ? const Value.absent()
          : Value(sound),
      skill: skill == null && nullToAbsent
          ? const Value.absent()
          : Value(skill),
      correct: correct == null && nullToAbsent
          ? const Value.absent()
          : Value(correct),
      activity: activity == null && nullToAbsent
          ? const Value.absent()
          : Value(activity),
      lessonId: lessonId == null && nullToAbsent
          ? const Value.absent()
          : Value(lessonId),
      game: game == null && nullToAbsent ? const Value.absent() : Value(game),
      score: score == null && nullToAbsent
          ? const Value.absent()
          : Value(score),
    );
  }

  factory SupportedSyncOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SupportedSyncOutboxData(
      scopeId: serializer.fromJson<int>(json['scopeId']),
      eventId: serializer.fromJson<String>(json['eventId']),
      enqueueCommitOrdinal: serializer.fromJson<int>(
        json['enqueueCommitOrdinal'],
      ),
      enqueueEventIndex: serializer.fromJson<int>(json['enqueueEventIndex']),
      userId: serializer.fromJson<String>(json['userId']),
      courseId: serializer.fromJson<String>(json['courseId']),
      kind: serializer.fromJson<String>(json['kind']),
      sound: serializer.fromJson<String?>(json['sound']),
      skill: serializer.fromJson<String?>(json['skill']),
      correct: serializer.fromJson<int?>(json['correct']),
      activity: serializer.fromJson<String?>(json['activity']),
      lessonId: serializer.fromJson<String?>(json['lessonId']),
      game: serializer.fromJson<String?>(json['game']),
      score: serializer.fromJson<int?>(json['score']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeId': serializer.toJson<int>(scopeId),
      'eventId': serializer.toJson<String>(eventId),
      'enqueueCommitOrdinal': serializer.toJson<int>(enqueueCommitOrdinal),
      'enqueueEventIndex': serializer.toJson<int>(enqueueEventIndex),
      'userId': serializer.toJson<String>(userId),
      'courseId': serializer.toJson<String>(courseId),
      'kind': serializer.toJson<String>(kind),
      'sound': serializer.toJson<String?>(sound),
      'skill': serializer.toJson<String?>(skill),
      'correct': serializer.toJson<int?>(correct),
      'activity': serializer.toJson<String?>(activity),
      'lessonId': serializer.toJson<String?>(lessonId),
      'game': serializer.toJson<String?>(game),
      'score': serializer.toJson<int?>(score),
    };
  }

  SupportedSyncOutboxData copyWith({
    int? scopeId,
    String? eventId,
    int? enqueueCommitOrdinal,
    int? enqueueEventIndex,
    String? userId,
    String? courseId,
    String? kind,
    Value<String?> sound = const Value.absent(),
    Value<String?> skill = const Value.absent(),
    Value<int?> correct = const Value.absent(),
    Value<String?> activity = const Value.absent(),
    Value<String?> lessonId = const Value.absent(),
    Value<String?> game = const Value.absent(),
    Value<int?> score = const Value.absent(),
  }) => SupportedSyncOutboxData(
    scopeId: scopeId ?? this.scopeId,
    eventId: eventId ?? this.eventId,
    enqueueCommitOrdinal: enqueueCommitOrdinal ?? this.enqueueCommitOrdinal,
    enqueueEventIndex: enqueueEventIndex ?? this.enqueueEventIndex,
    userId: userId ?? this.userId,
    courseId: courseId ?? this.courseId,
    kind: kind ?? this.kind,
    sound: sound.present ? sound.value : this.sound,
    skill: skill.present ? skill.value : this.skill,
    correct: correct.present ? correct.value : this.correct,
    activity: activity.present ? activity.value : this.activity,
    lessonId: lessonId.present ? lessonId.value : this.lessonId,
    game: game.present ? game.value : this.game,
    score: score.present ? score.value : this.score,
  );
  SupportedSyncOutboxData copyWithCompanion(SupportedSyncOutboxCompanion data) {
    return SupportedSyncOutboxData(
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      enqueueCommitOrdinal: data.enqueueCommitOrdinal.present
          ? data.enqueueCommitOrdinal.value
          : this.enqueueCommitOrdinal,
      enqueueEventIndex: data.enqueueEventIndex.present
          ? data.enqueueEventIndex.value
          : this.enqueueEventIndex,
      userId: data.userId.present ? data.userId.value : this.userId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      kind: data.kind.present ? data.kind.value : this.kind,
      sound: data.sound.present ? data.sound.value : this.sound,
      skill: data.skill.present ? data.skill.value : this.skill,
      correct: data.correct.present ? data.correct.value : this.correct,
      activity: data.activity.present ? data.activity.value : this.activity,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      game: data.game.present ? data.game.value : this.game,
      score: data.score.present ? data.score.value : this.score,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SupportedSyncOutboxData(')
          ..write('scopeId: $scopeId, ')
          ..write('eventId: $eventId, ')
          ..write('enqueueCommitOrdinal: $enqueueCommitOrdinal, ')
          ..write('enqueueEventIndex: $enqueueEventIndex, ')
          ..write('userId: $userId, ')
          ..write('courseId: $courseId, ')
          ..write('kind: $kind, ')
          ..write('sound: $sound, ')
          ..write('skill: $skill, ')
          ..write('correct: $correct, ')
          ..write('activity: $activity, ')
          ..write('lessonId: $lessonId, ')
          ..write('game: $game, ')
          ..write('score: $score')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeId,
    eventId,
    enqueueCommitOrdinal,
    enqueueEventIndex,
    userId,
    courseId,
    kind,
    sound,
    skill,
    correct,
    activity,
    lessonId,
    game,
    score,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SupportedSyncOutboxData &&
          other.scopeId == this.scopeId &&
          other.eventId == this.eventId &&
          other.enqueueCommitOrdinal == this.enqueueCommitOrdinal &&
          other.enqueueEventIndex == this.enqueueEventIndex &&
          other.userId == this.userId &&
          other.courseId == this.courseId &&
          other.kind == this.kind &&
          other.sound == this.sound &&
          other.skill == this.skill &&
          other.correct == this.correct &&
          other.activity == this.activity &&
          other.lessonId == this.lessonId &&
          other.game == this.game &&
          other.score == this.score);
}

class SupportedSyncOutboxCompanion
    extends UpdateCompanion<SupportedSyncOutboxData> {
  final Value<int> scopeId;
  final Value<String> eventId;
  final Value<int> enqueueCommitOrdinal;
  final Value<int> enqueueEventIndex;
  final Value<String> userId;
  final Value<String> courseId;
  final Value<String> kind;
  final Value<String?> sound;
  final Value<String?> skill;
  final Value<int?> correct;
  final Value<String?> activity;
  final Value<String?> lessonId;
  final Value<String?> game;
  final Value<int?> score;
  final Value<int> rowid;
  const SupportedSyncOutboxCompanion({
    this.scopeId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.enqueueCommitOrdinal = const Value.absent(),
    this.enqueueEventIndex = const Value.absent(),
    this.userId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.kind = const Value.absent(),
    this.sound = const Value.absent(),
    this.skill = const Value.absent(),
    this.correct = const Value.absent(),
    this.activity = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.game = const Value.absent(),
    this.score = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SupportedSyncOutboxCompanion.insert({
    required int scopeId,
    required String eventId,
    required int enqueueCommitOrdinal,
    required int enqueueEventIndex,
    required String userId,
    required String courseId,
    required String kind,
    this.sound = const Value.absent(),
    this.skill = const Value.absent(),
    this.correct = const Value.absent(),
    this.activity = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.game = const Value.absent(),
    this.score = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scopeId = Value(scopeId),
       eventId = Value(eventId),
       enqueueCommitOrdinal = Value(enqueueCommitOrdinal),
       enqueueEventIndex = Value(enqueueEventIndex),
       userId = Value(userId),
       courseId = Value(courseId),
       kind = Value(kind);
  static Insertable<SupportedSyncOutboxData> custom({
    Expression<int>? scopeId,
    Expression<String>? eventId,
    Expression<int>? enqueueCommitOrdinal,
    Expression<int>? enqueueEventIndex,
    Expression<String>? userId,
    Expression<String>? courseId,
    Expression<String>? kind,
    Expression<String>? sound,
    Expression<String>? skill,
    Expression<int>? correct,
    Expression<String>? activity,
    Expression<String>? lessonId,
    Expression<String>? game,
    Expression<int>? score,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeId != null) 'scope_id': scopeId,
      if (eventId != null) 'event_id': eventId,
      if (enqueueCommitOrdinal != null)
        'enqueue_commit_ordinal': enqueueCommitOrdinal,
      if (enqueueEventIndex != null) 'enqueue_event_index': enqueueEventIndex,
      if (userId != null) 'user_id': userId,
      if (courseId != null) 'course_id': courseId,
      if (kind != null) 'kind': kind,
      if (sound != null) 'sound': sound,
      if (skill != null) 'skill': skill,
      if (correct != null) 'correct': correct,
      if (activity != null) 'activity': activity,
      if (lessonId != null) 'lesson_id': lessonId,
      if (game != null) 'game': game,
      if (score != null) 'score': score,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SupportedSyncOutboxCompanion copyWith({
    Value<int>? scopeId,
    Value<String>? eventId,
    Value<int>? enqueueCommitOrdinal,
    Value<int>? enqueueEventIndex,
    Value<String>? userId,
    Value<String>? courseId,
    Value<String>? kind,
    Value<String?>? sound,
    Value<String?>? skill,
    Value<int?>? correct,
    Value<String?>? activity,
    Value<String?>? lessonId,
    Value<String?>? game,
    Value<int?>? score,
    Value<int>? rowid,
  }) {
    return SupportedSyncOutboxCompanion(
      scopeId: scopeId ?? this.scopeId,
      eventId: eventId ?? this.eventId,
      enqueueCommitOrdinal: enqueueCommitOrdinal ?? this.enqueueCommitOrdinal,
      enqueueEventIndex: enqueueEventIndex ?? this.enqueueEventIndex,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      kind: kind ?? this.kind,
      sound: sound ?? this.sound,
      skill: skill ?? this.skill,
      correct: correct ?? this.correct,
      activity: activity ?? this.activity,
      lessonId: lessonId ?? this.lessonId,
      game: game ?? this.game,
      score: score ?? this.score,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeId.present) {
      map['scope_id'] = Variable<int>(scopeId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (enqueueCommitOrdinal.present) {
      map['enqueue_commit_ordinal'] = Variable<int>(enqueueCommitOrdinal.value);
    }
    if (enqueueEventIndex.present) {
      map['enqueue_event_index'] = Variable<int>(enqueueEventIndex.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (sound.present) {
      map['sound'] = Variable<String>(sound.value);
    }
    if (skill.present) {
      map['skill'] = Variable<String>(skill.value);
    }
    if (correct.present) {
      map['correct'] = Variable<int>(correct.value);
    }
    if (activity.present) {
      map['activity'] = Variable<String>(activity.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (game.present) {
      map['game'] = Variable<String>(game.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SupportedSyncOutboxCompanion(')
          ..write('scopeId: $scopeId, ')
          ..write('eventId: $eventId, ')
          ..write('enqueueCommitOrdinal: $enqueueCommitOrdinal, ')
          ..write('enqueueEventIndex: $enqueueEventIndex, ')
          ..write('userId: $userId, ')
          ..write('courseId: $courseId, ')
          ..write('kind: $kind, ')
          ..write('sound: $sound, ')
          ..write('skill: $skill, ')
          ..write('correct: $correct, ')
          ..write('activity: $activity, ')
          ..write('lessonId: $lessonId, ')
          ..write('game: $game, ')
          ..write('score: $score, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LearningDatabase extends GeneratedDatabase {
  _$LearningDatabase(QueryExecutor e) : super(e);
  $LearningDatabaseManager get managers => $LearningDatabaseManager(this);
  late final $LearningScopesTable learningScopes = $LearningScopesTable(this);
  late final $LearningContentBindingsTable learningContentBindings =
      $LearningContentBindingsTable(this);
  late final $LearningRunsTable learningRuns = $LearningRunsTable(this);
  late final $LearningAttemptsTable learningAttempts = $LearningAttemptsTable(
    this,
  );
  late final $LearningAttemptValuesTable learningAttemptValues =
      $LearningAttemptValuesTable(this);
  late final $LearningAttemptEvidenceTable learningAttemptEvidence =
      $LearningAttemptEvidenceTable(this);
  late final $LearningCommandReceiptsTable learningCommandReceipts =
      $LearningCommandReceiptsTable(this);
  late final $LearningMistakesTable learningMistakes = $LearningMistakesTable(
    this,
  );
  late final $LearningSummariesTable learningSummaries =
      $LearningSummariesTable(this);
  late final $LearningCompletionsTable learningCompletions =
      $LearningCompletionsTable(this);
  late final $LearningExposureTable learningExposure = $LearningExposureTable(
    this,
  );
  late final $LearningBestScoresTable learningBestScores =
      $LearningBestScoresTable(this);
  late final $SupportedSyncOutboxTable supportedSyncOutbox =
      $SupportedSyncOutboxTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    learningScopes,
    learningContentBindings,
    learningRuns,
    learningAttempts,
    learningAttemptValues,
    learningAttemptEvidence,
    learningCommandReceipts,
    learningMistakes,
    learningSummaries,
    learningCompletions,
    learningExposure,
    learningBestScores,
    supportedSyncOutbox,
  ];
}

typedef $$LearningScopesTableCreateCompanionBuilder =
    LearningScopesCompanion Function({
      Value<int?> id,
      required String ownerKind,
      required String ownerId,
      required String courseId,
      required String family,
      required int schemaVersion,
      required int revision,
      required int commitOrdinal,
      required String availabilityState,
    });
typedef $$LearningScopesTableUpdateCompanionBuilder =
    LearningScopesCompanion Function({
      Value<int?> id,
      Value<String> ownerKind,
      Value<String> ownerId,
      Value<String> courseId,
      Value<String> family,
      Value<int> schemaVersion,
      Value<int> revision,
      Value<int> commitOrdinal,
      Value<String> availabilityState,
    });

final class $$LearningScopesTableReferences
    extends
        BaseReferences<
          _$LearningDatabase,
          $LearningScopesTable,
          LearningScope
        > {
  $$LearningScopesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $LearningContentBindingsTable,
    List<LearningContentBinding>
  >
  _learningContentBindingsRefsTable(_$LearningDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.learningContentBindings,
        aliasName: 'learning_scopes__id__learning_content_bindings__scope_id',
      );

  $$LearningContentBindingsTableProcessedTableManager
  get learningContentBindingsRefs {
    final manager = $$LearningContentBindingsTableTableManager(
      $_db,
      $_db.learningContentBindings,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')));

    final cache = $_typedResult.readTableOrNull(
      _learningContentBindingsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LearningRunsTable, List<LearningRun>>
  _learningRunsRefsTable(_$LearningDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.learningRuns,
        aliasName: 'learning_scopes__id__learning_runs__scope_id',
      );

  $$LearningRunsTableProcessedTableManager get learningRunsRefs {
    final manager = $$LearningRunsTableTableManager(
      $_db,
      $_db.learningRuns,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')));

    final cache = $_typedResult.readTableOrNull(_learningRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LearningAttemptsTable, List<LearningAttempt>>
  _learningAttemptsRefsTable(_$LearningDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.learningAttempts,
        aliasName: 'learning_scopes__id__learning_attempts__scope_id',
      );

  $$LearningAttemptsTableProcessedTableManager get learningAttemptsRefs {
    final manager = $$LearningAttemptsTableTableManager(
      $_db,
      $_db.learningAttempts,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')));

    final cache = $_typedResult.readTableOrNull(
      _learningAttemptsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $LearningAttemptValuesTable,
    List<LearningAttemptValue>
  >
  _learningAttemptValuesRefsTable(_$LearningDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.learningAttemptValues,
        aliasName: 'learning_scopes__id__learning_attempt_values__scope_id',
      );

  $$LearningAttemptValuesTableProcessedTableManager
  get learningAttemptValuesRefs {
    final manager = $$LearningAttemptValuesTableTableManager(
      $_db,
      $_db.learningAttemptValues,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')));

    final cache = $_typedResult.readTableOrNull(
      _learningAttemptValuesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $LearningAttemptEvidenceTable,
    List<LearningAttemptEvidenceData>
  >
  _learningAttemptEvidenceRefsTable(_$LearningDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.learningAttemptEvidence,
        aliasName: 'learning_scopes__id__learning_attempt_evidence__scope_id',
      );

  $$LearningAttemptEvidenceTableProcessedTableManager
  get learningAttemptEvidenceRefs {
    final manager = $$LearningAttemptEvidenceTableTableManager(
      $_db,
      $_db.learningAttemptEvidence,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')));

    final cache = $_typedResult.readTableOrNull(
      _learningAttemptEvidenceRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $LearningCommandReceiptsTable,
    List<LearningCommandReceipt>
  >
  _learningCommandReceiptsRefsTable(_$LearningDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.learningCommandReceipts,
        aliasName: 'learning_scopes__id__learning_command_receipts__scope_id',
      );

  $$LearningCommandReceiptsTableProcessedTableManager
  get learningCommandReceiptsRefs {
    final manager = $$LearningCommandReceiptsTableTableManager(
      $_db,
      $_db.learningCommandReceipts,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')));

    final cache = $_typedResult.readTableOrNull(
      _learningCommandReceiptsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LearningMistakesTable, List<LearningMistake>>
  _learningMistakesRefsTable(_$LearningDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.learningMistakes,
        aliasName: 'learning_scopes__id__learning_mistakes__scope_id',
      );

  $$LearningMistakesTableProcessedTableManager get learningMistakesRefs {
    final manager = $$LearningMistakesTableTableManager(
      $_db,
      $_db.learningMistakes,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')));

    final cache = $_typedResult.readTableOrNull(
      _learningMistakesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LearningSummariesTable, List<LearningSummary>>
  _learningSummariesRefsTable(_$LearningDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.learningSummaries,
        aliasName: 'learning_scopes__id__learning_summaries__scope_id',
      );

  $$LearningSummariesTableProcessedTableManager get learningSummariesRefs {
    final manager = $$LearningSummariesTableTableManager(
      $_db,
      $_db.learningSummaries,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')));

    final cache = $_typedResult.readTableOrNull(
      _learningSummariesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $LearningCompletionsTable,
    List<LearningCompletion>
  >
  _learningCompletionsRefsTable(_$LearningDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.learningCompletions,
        aliasName: 'learning_scopes__id__learning_completions__scope_id',
      );

  $$LearningCompletionsTableProcessedTableManager get learningCompletionsRefs {
    final manager = $$LearningCompletionsTableTableManager(
      $_db,
      $_db.learningCompletions,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')));

    final cache = $_typedResult.readTableOrNull(
      _learningCompletionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LearningExposureTable, List<LearningExposureData>>
  _learningExposureRefsTable(_$LearningDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.learningExposure,
        aliasName: 'learning_scopes__id__learning_exposure__scope_id',
      );

  $$LearningExposureTableProcessedTableManager get learningExposureRefs {
    final manager = $$LearningExposureTableTableManager(
      $_db,
      $_db.learningExposure,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')));

    final cache = $_typedResult.readTableOrNull(
      _learningExposureRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LearningBestScoresTable, List<LearningBestScore>>
  _learningBestScoresRefsTable(_$LearningDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.learningBestScores,
        aliasName: 'learning_scopes__id__learning_best_scores__scope_id',
      );

  $$LearningBestScoresTableProcessedTableManager get learningBestScoresRefs {
    final manager = $$LearningBestScoresTableTableManager(
      $_db,
      $_db.learningBestScores,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')));

    final cache = $_typedResult.readTableOrNull(
      _learningBestScoresRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $SupportedSyncOutboxTable,
    List<SupportedSyncOutboxData>
  >
  _supportedSyncOutboxRefsTable(_$LearningDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.supportedSyncOutbox,
        aliasName: 'learning_scopes__id__supported_sync_outbox__scope_id',
      );

  $$SupportedSyncOutboxTableProcessedTableManager get supportedSyncOutboxRefs {
    final manager = $$SupportedSyncOutboxTableTableManager(
      $_db,
      $_db.supportedSyncOutbox,
    ).filter((f) => f.scopeId.id.sqlEquals($_itemColumn<int>('id')));

    final cache = $_typedResult.readTableOrNull(
      _supportedSyncOutboxRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LearningScopesTableFilterComposer
    extends Composer<_$LearningDatabase, $LearningScopesTable> {
  $$LearningScopesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerKind => $composableBuilder(
    column: $table.ownerKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get commitOrdinal => $composableBuilder(
    column: $table.commitOrdinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availabilityState => $composableBuilder(
    column: $table.availabilityState,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> learningContentBindingsRefs(
    Expression<bool> Function($$LearningContentBindingsTableFilterComposer f) f,
  ) {
    final $$LearningContentBindingsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.learningContentBindings,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningContentBindingsTableFilterComposer(
                $db: $db,
                $table: $db.learningContentBindings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> learningRunsRefs(
    Expression<bool> Function($$LearningRunsTableFilterComposer f) f,
  ) {
    final $$LearningRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningRuns,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningRunsTableFilterComposer(
            $db: $db,
            $table: $db.learningRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learningAttemptsRefs(
    Expression<bool> Function($$LearningAttemptsTableFilterComposer f) f,
  ) {
    final $$LearningAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningAttempts,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.learningAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learningAttemptValuesRefs(
    Expression<bool> Function($$LearningAttemptValuesTableFilterComposer f) f,
  ) {
    final $$LearningAttemptValuesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.learningAttemptValues,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningAttemptValuesTableFilterComposer(
                $db: $db,
                $table: $db.learningAttemptValues,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> learningAttemptEvidenceRefs(
    Expression<bool> Function($$LearningAttemptEvidenceTableFilterComposer f) f,
  ) {
    final $$LearningAttemptEvidenceTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.learningAttemptEvidence,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningAttemptEvidenceTableFilterComposer(
                $db: $db,
                $table: $db.learningAttemptEvidence,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> learningCommandReceiptsRefs(
    Expression<bool> Function($$LearningCommandReceiptsTableFilterComposer f) f,
  ) {
    final $$LearningCommandReceiptsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.learningCommandReceipts,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningCommandReceiptsTableFilterComposer(
                $db: $db,
                $table: $db.learningCommandReceipts,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> learningMistakesRefs(
    Expression<bool> Function($$LearningMistakesTableFilterComposer f) f,
  ) {
    final $$LearningMistakesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningMistakes,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningMistakesTableFilterComposer(
            $db: $db,
            $table: $db.learningMistakes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learningSummariesRefs(
    Expression<bool> Function($$LearningSummariesTableFilterComposer f) f,
  ) {
    final $$LearningSummariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningSummaries,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningSummariesTableFilterComposer(
            $db: $db,
            $table: $db.learningSummaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learningCompletionsRefs(
    Expression<bool> Function($$LearningCompletionsTableFilterComposer f) f,
  ) {
    final $$LearningCompletionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningCompletions,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningCompletionsTableFilterComposer(
            $db: $db,
            $table: $db.learningCompletions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learningExposureRefs(
    Expression<bool> Function($$LearningExposureTableFilterComposer f) f,
  ) {
    final $$LearningExposureTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningExposure,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningExposureTableFilterComposer(
            $db: $db,
            $table: $db.learningExposure,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learningBestScoresRefs(
    Expression<bool> Function($$LearningBestScoresTableFilterComposer f) f,
  ) {
    final $$LearningBestScoresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningBestScores,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningBestScoresTableFilterComposer(
            $db: $db,
            $table: $db.learningBestScores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> supportedSyncOutboxRefs(
    Expression<bool> Function($$SupportedSyncOutboxTableFilterComposer f) f,
  ) {
    final $$SupportedSyncOutboxTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.supportedSyncOutbox,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SupportedSyncOutboxTableFilterComposer(
            $db: $db,
            $table: $db.supportedSyncOutbox,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LearningScopesTableOrderingComposer
    extends Composer<_$LearningDatabase, $LearningScopesTable> {
  $$LearningScopesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerKind => $composableBuilder(
    column: $table.ownerKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get commitOrdinal => $composableBuilder(
    column: $table.commitOrdinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availabilityState => $composableBuilder(
    column: $table.availabilityState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LearningScopesTableAnnotationComposer
    extends Composer<_$LearningDatabase, $LearningScopesTable> {
  $$LearningScopesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerKind =>
      $composableBuilder(column: $table.ownerKind, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get family =>
      $composableBuilder(column: $table.family, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get commitOrdinal => $composableBuilder(
    column: $table.commitOrdinal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get availabilityState => $composableBuilder(
    column: $table.availabilityState,
    builder: (column) => column,
  );

  Expression<T> learningContentBindingsRefs<T extends Object>(
    Expression<T> Function($$LearningContentBindingsTableAnnotationComposer a)
    f,
  ) {
    final $$LearningContentBindingsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.learningContentBindings,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningContentBindingsTableAnnotationComposer(
                $db: $db,
                $table: $db.learningContentBindings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> learningRunsRefs<T extends Object>(
    Expression<T> Function($$LearningRunsTableAnnotationComposer a) f,
  ) {
    final $$LearningRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningRuns,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.learningRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> learningAttemptsRefs<T extends Object>(
    Expression<T> Function($$LearningAttemptsTableAnnotationComposer a) f,
  ) {
    final $$LearningAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningAttempts,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.learningAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> learningAttemptValuesRefs<T extends Object>(
    Expression<T> Function($$LearningAttemptValuesTableAnnotationComposer a) f,
  ) {
    final $$LearningAttemptValuesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.learningAttemptValues,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningAttemptValuesTableAnnotationComposer(
                $db: $db,
                $table: $db.learningAttemptValues,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> learningAttemptEvidenceRefs<T extends Object>(
    Expression<T> Function($$LearningAttemptEvidenceTableAnnotationComposer a)
    f,
  ) {
    final $$LearningAttemptEvidenceTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.learningAttemptEvidence,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningAttemptEvidenceTableAnnotationComposer(
                $db: $db,
                $table: $db.learningAttemptEvidence,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> learningCommandReceiptsRefs<T extends Object>(
    Expression<T> Function($$LearningCommandReceiptsTableAnnotationComposer a)
    f,
  ) {
    final $$LearningCommandReceiptsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.learningCommandReceipts,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningCommandReceiptsTableAnnotationComposer(
                $db: $db,
                $table: $db.learningCommandReceipts,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> learningMistakesRefs<T extends Object>(
    Expression<T> Function($$LearningMistakesTableAnnotationComposer a) f,
  ) {
    final $$LearningMistakesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningMistakes,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningMistakesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningMistakes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> learningSummariesRefs<T extends Object>(
    Expression<T> Function($$LearningSummariesTableAnnotationComposer a) f,
  ) {
    final $$LearningSummariesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.learningSummaries,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningSummariesTableAnnotationComposer(
                $db: $db,
                $table: $db.learningSummaries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> learningCompletionsRefs<T extends Object>(
    Expression<T> Function($$LearningCompletionsTableAnnotationComposer a) f,
  ) {
    final $$LearningCompletionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.learningCompletions,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningCompletionsTableAnnotationComposer(
                $db: $db,
                $table: $db.learningCompletions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> learningExposureRefs<T extends Object>(
    Expression<T> Function($$LearningExposureTableAnnotationComposer a) f,
  ) {
    final $$LearningExposureTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningExposure,
      getReferencedColumn: (t) => t.scopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningExposureTableAnnotationComposer(
            $db: $db,
            $table: $db.learningExposure,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> learningBestScoresRefs<T extends Object>(
    Expression<T> Function($$LearningBestScoresTableAnnotationComposer a) f,
  ) {
    final $$LearningBestScoresTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.learningBestScores,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningBestScoresTableAnnotationComposer(
                $db: $db,
                $table: $db.learningBestScores,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> supportedSyncOutboxRefs<T extends Object>(
    Expression<T> Function($$SupportedSyncOutboxTableAnnotationComposer a) f,
  ) {
    final $$SupportedSyncOutboxTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.supportedSyncOutbox,
          getReferencedColumn: (t) => t.scopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SupportedSyncOutboxTableAnnotationComposer(
                $db: $db,
                $table: $db.supportedSyncOutbox,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LearningScopesTableTableManager
    extends
        RootTableManager<
          _$LearningDatabase,
          $LearningScopesTable,
          LearningScope,
          $$LearningScopesTableFilterComposer,
          $$LearningScopesTableOrderingComposer,
          $$LearningScopesTableAnnotationComposer,
          $$LearningScopesTableCreateCompanionBuilder,
          $$LearningScopesTableUpdateCompanionBuilder,
          (LearningScope, $$LearningScopesTableReferences),
          LearningScope,
          PrefetchHooks Function({
            bool learningContentBindingsRefs,
            bool learningRunsRefs,
            bool learningAttemptsRefs,
            bool learningAttemptValuesRefs,
            bool learningAttemptEvidenceRefs,
            bool learningCommandReceiptsRefs,
            bool learningMistakesRefs,
            bool learningSummariesRefs,
            bool learningCompletionsRefs,
            bool learningExposureRefs,
            bool learningBestScoresRefs,
            bool supportedSyncOutboxRefs,
          })
        > {
  $$LearningScopesTableTableManager(
    _$LearningDatabase db,
    $LearningScopesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningScopesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningScopesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningScopesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int?> id = const Value.absent(),
                Value<String> ownerKind = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> family = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> commitOrdinal = const Value.absent(),
                Value<String> availabilityState = const Value.absent(),
              }) => LearningScopesCompanion(
                id: id,
                ownerKind: ownerKind,
                ownerId: ownerId,
                courseId: courseId,
                family: family,
                schemaVersion: schemaVersion,
                revision: revision,
                commitOrdinal: commitOrdinal,
                availabilityState: availabilityState,
              ),
          createCompanionCallback:
              ({
                Value<int?> id = const Value.absent(),
                required String ownerKind,
                required String ownerId,
                required String courseId,
                required String family,
                required int schemaVersion,
                required int revision,
                required int commitOrdinal,
                required String availabilityState,
              }) => LearningScopesCompanion.insert(
                id: id,
                ownerKind: ownerKind,
                ownerId: ownerId,
                courseId: courseId,
                family: family,
                schemaVersion: schemaVersion,
                revision: revision,
                commitOrdinal: commitOrdinal,
                availabilityState: availabilityState,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LearningScopesTable, LearningScope>(table),
                  $$LearningScopesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                learningContentBindingsRefs = false,
                learningRunsRefs = false,
                learningAttemptsRefs = false,
                learningAttemptValuesRefs = false,
                learningAttemptEvidenceRefs = false,
                learningCommandReceiptsRefs = false,
                learningMistakesRefs = false,
                learningSummariesRefs = false,
                learningCompletionsRefs = false,
                learningExposureRefs = false,
                learningBestScoresRefs = false,
                supportedSyncOutboxRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (learningContentBindingsRefs) db.learningContentBindings,
                    if (learningRunsRefs) db.learningRuns,
                    if (learningAttemptsRefs) db.learningAttempts,
                    if (learningAttemptValuesRefs) db.learningAttemptValues,
                    if (learningAttemptEvidenceRefs) db.learningAttemptEvidence,
                    if (learningCommandReceiptsRefs) db.learningCommandReceipts,
                    if (learningMistakesRefs) db.learningMistakes,
                    if (learningSummariesRefs) db.learningSummaries,
                    if (learningCompletionsRefs) db.learningCompletions,
                    if (learningExposureRefs) db.learningExposure,
                    if (learningBestScoresRefs) db.learningBestScores,
                    if (supportedSyncOutboxRefs) db.supportedSyncOutbox,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (learningContentBindingsRefs)
                        await $_getPrefetchedData<
                          LearningScope,
                          $LearningScopesTable,
                          LearningContentBinding
                        >(
                          currentTable: table,
                          referencedTable: $$LearningScopesTableReferences
                              ._learningContentBindingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningContentBindingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningRunsRefs)
                        await $_getPrefetchedData<
                          LearningScope,
                          $LearningScopesTable,
                          LearningRun
                        >(
                          currentTable: table,
                          referencedTable: $$LearningScopesTableReferences
                              ._learningRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningAttemptsRefs)
                        await $_getPrefetchedData<
                          LearningScope,
                          $LearningScopesTable,
                          LearningAttempt
                        >(
                          currentTable: table,
                          referencedTable: $$LearningScopesTableReferences
                              ._learningAttemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningAttemptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningAttemptValuesRefs)
                        await $_getPrefetchedData<
                          LearningScope,
                          $LearningScopesTable,
                          LearningAttemptValue
                        >(
                          currentTable: table,
                          referencedTable: $$LearningScopesTableReferences
                              ._learningAttemptValuesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningAttemptValuesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningAttemptEvidenceRefs)
                        await $_getPrefetchedData<
                          LearningScope,
                          $LearningScopesTable,
                          LearningAttemptEvidenceData
                        >(
                          currentTable: table,
                          referencedTable: $$LearningScopesTableReferences
                              ._learningAttemptEvidenceRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningAttemptEvidenceRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningCommandReceiptsRefs)
                        await $_getPrefetchedData<
                          LearningScope,
                          $LearningScopesTable,
                          LearningCommandReceipt
                        >(
                          currentTable: table,
                          referencedTable: $$LearningScopesTableReferences
                              ._learningCommandReceiptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningCommandReceiptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningMistakesRefs)
                        await $_getPrefetchedData<
                          LearningScope,
                          $LearningScopesTable,
                          LearningMistake
                        >(
                          currentTable: table,
                          referencedTable: $$LearningScopesTableReferences
                              ._learningMistakesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningMistakesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningSummariesRefs)
                        await $_getPrefetchedData<
                          LearningScope,
                          $LearningScopesTable,
                          LearningSummary
                        >(
                          currentTable: table,
                          referencedTable: $$LearningScopesTableReferences
                              ._learningSummariesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningSummariesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningCompletionsRefs)
                        await $_getPrefetchedData<
                          LearningScope,
                          $LearningScopesTable,
                          LearningCompletion
                        >(
                          currentTable: table,
                          referencedTable: $$LearningScopesTableReferences
                              ._learningCompletionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningCompletionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningExposureRefs)
                        await $_getPrefetchedData<
                          LearningScope,
                          $LearningScopesTable,
                          LearningExposureData
                        >(
                          currentTable: table,
                          referencedTable: $$LearningScopesTableReferences
                              ._learningExposureRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningExposureRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningBestScoresRefs)
                        await $_getPrefetchedData<
                          LearningScope,
                          $LearningScopesTable,
                          LearningBestScore
                        >(
                          currentTable: table,
                          referencedTable: $$LearningScopesTableReferences
                              ._learningBestScoresRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningBestScoresRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (supportedSyncOutboxRefs)
                        await $_getPrefetchedData<
                          LearningScope,
                          $LearningScopesTable,
                          SupportedSyncOutboxData
                        >(
                          currentTable: table,
                          referencedTable: $$LearningScopesTableReferences
                              ._supportedSyncOutboxRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).supportedSyncOutboxRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LearningScopesTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabase,
      $LearningScopesTable,
      LearningScope,
      $$LearningScopesTableFilterComposer,
      $$LearningScopesTableOrderingComposer,
      $$LearningScopesTableAnnotationComposer,
      $$LearningScopesTableCreateCompanionBuilder,
      $$LearningScopesTableUpdateCompanionBuilder,
      (LearningScope, $$LearningScopesTableReferences),
      LearningScope,
      PrefetchHooks Function({
        bool learningContentBindingsRefs,
        bool learningRunsRefs,
        bool learningAttemptsRefs,
        bool learningAttemptValuesRefs,
        bool learningAttemptEvidenceRefs,
        bool learningCommandReceiptsRefs,
        bool learningMistakesRefs,
        bool learningSummariesRefs,
        bool learningCompletionsRefs,
        bool learningExposureRefs,
        bool learningBestScoresRefs,
        bool supportedSyncOutboxRefs,
      })
    >;
typedef $$LearningContentBindingsTableCreateCompanionBuilder =
    LearningContentBindingsCompanion Function({
      Value<int?> id,
      required int scopeId,
      required String activityId,
      required int contentRevision,
      Value<String?> policyKind,
      Value<int?> policyRevision,
      Value<String?> catalogueFingerprint,
      Value<String?> sectionFingerprint,
      Value<String?> annotationHash,
      Value<int?> annotationRevision,
    });
typedef $$LearningContentBindingsTableUpdateCompanionBuilder =
    LearningContentBindingsCompanion Function({
      Value<int?> id,
      Value<int> scopeId,
      Value<String> activityId,
      Value<int> contentRevision,
      Value<String?> policyKind,
      Value<int?> policyRevision,
      Value<String?> catalogueFingerprint,
      Value<String?> sectionFingerprint,
      Value<String?> annotationHash,
      Value<int?> annotationRevision,
    });

final class $$LearningContentBindingsTableReferences
    extends
        BaseReferences<
          _$LearningDatabase,
          $LearningContentBindingsTable,
          LearningContentBinding
        > {
  $$LearningContentBindingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningScopesTable _scopeIdTable(_$LearningDatabase db) => db
      .learningScopes
      .createAlias('learning_content_bindings__scope_id__learning_scopes__id');

  $$LearningScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$LearningScopesTableTableManager(
      $_db,
      $_db.learningScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LearningRunsTable, List<LearningRun>>
  _learningRunsRefsTable(_$LearningDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.learningRuns,
        aliasName:
            'learning_content_bindings__id__learning_runs__content_binding_id',
      );

  $$LearningRunsTableProcessedTableManager get learningRunsRefs {
    final manager = $$LearningRunsTableTableManager(
      $_db,
      $_db.learningRuns,
    ).filter((f) => f.contentBindingId.id.sqlEquals($_itemColumn<int>('id')));

    final cache = $_typedResult.readTableOrNull(_learningRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LearningContentBindingsTableFilterComposer
    extends Composer<_$LearningDatabase, $LearningContentBindingsTable> {
  $$LearningContentBindingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get policyKind => $composableBuilder(
    column: $table.policyKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get policyRevision => $composableBuilder(
    column: $table.policyRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get catalogueFingerprint => $composableBuilder(
    column: $table.catalogueFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionFingerprint => $composableBuilder(
    column: $table.sectionFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningScopesTableFilterComposer get scopeId {
    final $$LearningScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableFilterComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> learningRunsRefs(
    Expression<bool> Function($$LearningRunsTableFilterComposer f) f,
  ) {
    final $$LearningRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningRuns,
      getReferencedColumn: (t) => t.contentBindingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningRunsTableFilterComposer(
            $db: $db,
            $table: $db.learningRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LearningContentBindingsTableOrderingComposer
    extends Composer<_$LearningDatabase, $LearningContentBindingsTable> {
  $$LearningContentBindingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get policyKind => $composableBuilder(
    column: $table.policyKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get policyRevision => $composableBuilder(
    column: $table.policyRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get catalogueFingerprint => $composableBuilder(
    column: $table.catalogueFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionFingerprint => $composableBuilder(
    column: $table.sectionFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningScopesTableOrderingComposer get scopeId {
    final $$LearningScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableOrderingComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningContentBindingsTableAnnotationComposer
    extends Composer<_$LearningDatabase, $LearningContentBindingsTable> {
  $$LearningContentBindingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get policyKind => $composableBuilder(
    column: $table.policyKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get policyRevision => $composableBuilder(
    column: $table.policyRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get catalogueFingerprint => $composableBuilder(
    column: $table.catalogueFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sectionFingerprint => $composableBuilder(
    column: $table.sectionFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => column,
  );

  $$LearningScopesTableAnnotationComposer get scopeId {
    final $$LearningScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> learningRunsRefs<T extends Object>(
    Expression<T> Function($$LearningRunsTableAnnotationComposer a) f,
  ) {
    final $$LearningRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningRuns,
      getReferencedColumn: (t) => t.contentBindingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.learningRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LearningContentBindingsTableTableManager
    extends
        RootTableManager<
          _$LearningDatabase,
          $LearningContentBindingsTable,
          LearningContentBinding,
          $$LearningContentBindingsTableFilterComposer,
          $$LearningContentBindingsTableOrderingComposer,
          $$LearningContentBindingsTableAnnotationComposer,
          $$LearningContentBindingsTableCreateCompanionBuilder,
          $$LearningContentBindingsTableUpdateCompanionBuilder,
          (LearningContentBinding, $$LearningContentBindingsTableReferences),
          LearningContentBinding,
          PrefetchHooks Function({bool scopeId, bool learningRunsRefs})
        > {
  $$LearningContentBindingsTableTableManager(
    _$LearningDatabase db,
    $LearningContentBindingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningContentBindingsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LearningContentBindingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LearningContentBindingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int?> id = const Value.absent(),
                Value<int> scopeId = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<int> contentRevision = const Value.absent(),
                Value<String?> policyKind = const Value.absent(),
                Value<int?> policyRevision = const Value.absent(),
                Value<String?> catalogueFingerprint = const Value.absent(),
                Value<String?> sectionFingerprint = const Value.absent(),
                Value<String?> annotationHash = const Value.absent(),
                Value<int?> annotationRevision = const Value.absent(),
              }) => LearningContentBindingsCompanion(
                id: id,
                scopeId: scopeId,
                activityId: activityId,
                contentRevision: contentRevision,
                policyKind: policyKind,
                policyRevision: policyRevision,
                catalogueFingerprint: catalogueFingerprint,
                sectionFingerprint: sectionFingerprint,
                annotationHash: annotationHash,
                annotationRevision: annotationRevision,
              ),
          createCompanionCallback:
              ({
                Value<int?> id = const Value.absent(),
                required int scopeId,
                required String activityId,
                required int contentRevision,
                Value<String?> policyKind = const Value.absent(),
                Value<int?> policyRevision = const Value.absent(),
                Value<String?> catalogueFingerprint = const Value.absent(),
                Value<String?> sectionFingerprint = const Value.absent(),
                Value<String?> annotationHash = const Value.absent(),
                Value<int?> annotationRevision = const Value.absent(),
              }) => LearningContentBindingsCompanion.insert(
                id: id,
                scopeId: scopeId,
                activityId: activityId,
                contentRevision: contentRevision,
                policyKind: policyKind,
                policyRevision: policyRevision,
                catalogueFingerprint: catalogueFingerprint,
                sectionFingerprint: sectionFingerprint,
                annotationHash: annotationHash,
                annotationRevision: annotationRevision,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LearningContentBindingsTable,
                    LearningContentBinding
                  >(table),
                  $$LearningContentBindingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false, learningRunsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (learningRunsRefs) db.learningRuns],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$LearningContentBindingsTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$LearningContentBindingsTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (learningRunsRefs)
                    await $_getPrefetchedData<
                      LearningContentBinding,
                      $LearningContentBindingsTable,
                      LearningRun
                    >(
                      currentTable: table,
                      referencedTable: $$LearningContentBindingsTableReferences
                          ._learningRunsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LearningContentBindingsTableReferences(
                            db,
                            table,
                            p0,
                          ).learningRunsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.contentBindingId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LearningContentBindingsTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabase,
      $LearningContentBindingsTable,
      LearningContentBinding,
      $$LearningContentBindingsTableFilterComposer,
      $$LearningContentBindingsTableOrderingComposer,
      $$LearningContentBindingsTableAnnotationComposer,
      $$LearningContentBindingsTableCreateCompanionBuilder,
      $$LearningContentBindingsTableUpdateCompanionBuilder,
      (LearningContentBinding, $$LearningContentBindingsTableReferences),
      LearningContentBinding,
      PrefetchHooks Function({bool scopeId, bool learningRunsRefs})
    >;
typedef $$LearningRunsTableCreateCompanionBuilder =
    LearningRunsCompanion Function({
      required int scopeId,
      required String activityId,
      required String activityKind,
      required int runGeneration,
      required int sequence,
      required int cursorRevision,
      required int contentBindingId,
      Value<String?> runMode,
      required int finished,
      Value<String?> sessionId,
      Value<int?> policyRevision,
      Value<int?> thresholdPercent,
      Value<int?> runStartRound,
      required String checkpointJson,
      required String latestReceiptToken,
      required String latestReceiptPayload,
      required int latestReceiptBeforeGeneration,
      required int latestReceiptBeforeSequence,
      required int latestReceiptBeforeCursorRevision,
      required int latestReceiptCommitOrdinal,
      Value<int> rowid,
    });
typedef $$LearningRunsTableUpdateCompanionBuilder =
    LearningRunsCompanion Function({
      Value<int> scopeId,
      Value<String> activityId,
      Value<String> activityKind,
      Value<int> runGeneration,
      Value<int> sequence,
      Value<int> cursorRevision,
      Value<int> contentBindingId,
      Value<String?> runMode,
      Value<int> finished,
      Value<String?> sessionId,
      Value<int?> policyRevision,
      Value<int?> thresholdPercent,
      Value<int?> runStartRound,
      Value<String> checkpointJson,
      Value<String> latestReceiptToken,
      Value<String> latestReceiptPayload,
      Value<int> latestReceiptBeforeGeneration,
      Value<int> latestReceiptBeforeSequence,
      Value<int> latestReceiptBeforeCursorRevision,
      Value<int> latestReceiptCommitOrdinal,
      Value<int> rowid,
    });

final class $$LearningRunsTableReferences
    extends
        BaseReferences<_$LearningDatabase, $LearningRunsTable, LearningRun> {
  $$LearningRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LearningScopesTable _scopeIdTable(_$LearningDatabase db) => db
      .learningScopes
      .createAlias('learning_runs__scope_id__learning_scopes__id');

  $$LearningScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$LearningScopesTableTableManager(
      $_db,
      $_db.learningScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LearningContentBindingsTable _contentBindingIdTable(
    _$LearningDatabase db,
  ) => db.learningContentBindings.createAlias(
    'learning_runs__content_binding_id__learning_content_bindings__id',
  );

  $$LearningContentBindingsTableProcessedTableManager get contentBindingId {
    final $_column = $_itemColumn<int>('content_binding_id')!;

    final manager = $$LearningContentBindingsTableTableManager(
      $_db,
      $_db.learningContentBindings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_contentBindingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningRunsTableFilterComposer
    extends Composer<_$LearningDatabase, $LearningRunsTable> {
  $$LearningRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityKind => $composableBuilder(
    column: $table.activityKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runGeneration => $composableBuilder(
    column: $table.runGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cursorRevision => $composableBuilder(
    column: $table.cursorRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runMode => $composableBuilder(
    column: $table.runMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finished => $composableBuilder(
    column: $table.finished,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get policyRevision => $composableBuilder(
    column: $table.policyRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get thresholdPercent => $composableBuilder(
    column: $table.thresholdPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runStartRound => $composableBuilder(
    column: $table.runStartRound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkpointJson => $composableBuilder(
    column: $table.checkpointJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latestReceiptToken => $composableBuilder(
    column: $table.latestReceiptToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latestReceiptPayload => $composableBuilder(
    column: $table.latestReceiptPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latestReceiptBeforeGeneration => $composableBuilder(
    column: $table.latestReceiptBeforeGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latestReceiptBeforeSequence => $composableBuilder(
    column: $table.latestReceiptBeforeSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latestReceiptBeforeCursorRevision =>
      $composableBuilder(
        column: $table.latestReceiptBeforeCursorRevision,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<int> get latestReceiptCommitOrdinal => $composableBuilder(
    column: $table.latestReceiptCommitOrdinal,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningScopesTableFilterComposer get scopeId {
    final $$LearningScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableFilterComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LearningContentBindingsTableFilterComposer get contentBindingId {
    final $$LearningContentBindingsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.contentBindingId,
          referencedTable: $db.learningContentBindings,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningContentBindingsTableFilterComposer(
                $db: $db,
                $table: $db.learningContentBindings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$LearningRunsTableOrderingComposer
    extends Composer<_$LearningDatabase, $LearningRunsTable> {
  $$LearningRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityKind => $composableBuilder(
    column: $table.activityKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runGeneration => $composableBuilder(
    column: $table.runGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cursorRevision => $composableBuilder(
    column: $table.cursorRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runMode => $composableBuilder(
    column: $table.runMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finished => $composableBuilder(
    column: $table.finished,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get policyRevision => $composableBuilder(
    column: $table.policyRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get thresholdPercent => $composableBuilder(
    column: $table.thresholdPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runStartRound => $composableBuilder(
    column: $table.runStartRound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkpointJson => $composableBuilder(
    column: $table.checkpointJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latestReceiptToken => $composableBuilder(
    column: $table.latestReceiptToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latestReceiptPayload => $composableBuilder(
    column: $table.latestReceiptPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latestReceiptBeforeGeneration => $composableBuilder(
    column: $table.latestReceiptBeforeGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latestReceiptBeforeSequence => $composableBuilder(
    column: $table.latestReceiptBeforeSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latestReceiptBeforeCursorRevision =>
      $composableBuilder(
        column: $table.latestReceiptBeforeCursorRevision,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<int> get latestReceiptCommitOrdinal => $composableBuilder(
    column: $table.latestReceiptCommitOrdinal,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningScopesTableOrderingComposer get scopeId {
    final $$LearningScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableOrderingComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LearningContentBindingsTableOrderingComposer get contentBindingId {
    final $$LearningContentBindingsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.contentBindingId,
          referencedTable: $db.learningContentBindings,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningContentBindingsTableOrderingComposer(
                $db: $db,
                $table: $db.learningContentBindings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$LearningRunsTableAnnotationComposer
    extends Composer<_$LearningDatabase, $LearningRunsTable> {
  $$LearningRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityKind => $composableBuilder(
    column: $table.activityKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get runGeneration => $composableBuilder(
    column: $table.runGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<int> get cursorRevision => $composableBuilder(
    column: $table.cursorRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get runMode =>
      $composableBuilder(column: $table.runMode, builder: (column) => column);

  GeneratedColumn<int> get finished =>
      $composableBuilder(column: $table.finished, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get policyRevision => $composableBuilder(
    column: $table.policyRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get thresholdPercent => $composableBuilder(
    column: $table.thresholdPercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get runStartRound => $composableBuilder(
    column: $table.runStartRound,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checkpointJson => $composableBuilder(
    column: $table.checkpointJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get latestReceiptToken => $composableBuilder(
    column: $table.latestReceiptToken,
    builder: (column) => column,
  );

  GeneratedColumn<String> get latestReceiptPayload => $composableBuilder(
    column: $table.latestReceiptPayload,
    builder: (column) => column,
  );

  GeneratedColumn<int> get latestReceiptBeforeGeneration => $composableBuilder(
    column: $table.latestReceiptBeforeGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get latestReceiptBeforeSequence => $composableBuilder(
    column: $table.latestReceiptBeforeSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get latestReceiptBeforeCursorRevision =>
      $composableBuilder(
        column: $table.latestReceiptBeforeCursorRevision,
        builder: (column) => column,
      );

  GeneratedColumn<int> get latestReceiptCommitOrdinal => $composableBuilder(
    column: $table.latestReceiptCommitOrdinal,
    builder: (column) => column,
  );

  $$LearningScopesTableAnnotationComposer get scopeId {
    final $$LearningScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LearningContentBindingsTableAnnotationComposer get contentBindingId {
    final $$LearningContentBindingsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.contentBindingId,
          referencedTable: $db.learningContentBindings,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningContentBindingsTableAnnotationComposer(
                $db: $db,
                $table: $db.learningContentBindings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$LearningRunsTableTableManager
    extends
        RootTableManager<
          _$LearningDatabase,
          $LearningRunsTable,
          LearningRun,
          $$LearningRunsTableFilterComposer,
          $$LearningRunsTableOrderingComposer,
          $$LearningRunsTableAnnotationComposer,
          $$LearningRunsTableCreateCompanionBuilder,
          $$LearningRunsTableUpdateCompanionBuilder,
          (LearningRun, $$LearningRunsTableReferences),
          LearningRun,
          PrefetchHooks Function({bool scopeId, bool contentBindingId})
        > {
  $$LearningRunsTableTableManager(
    _$LearningDatabase db,
    $LearningRunsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<String> activityKind = const Value.absent(),
                Value<int> runGeneration = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<int> cursorRevision = const Value.absent(),
                Value<int> contentBindingId = const Value.absent(),
                Value<String?> runMode = const Value.absent(),
                Value<int> finished = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<int?> policyRevision = const Value.absent(),
                Value<int?> thresholdPercent = const Value.absent(),
                Value<int?> runStartRound = const Value.absent(),
                Value<String> checkpointJson = const Value.absent(),
                Value<String> latestReceiptToken = const Value.absent(),
                Value<String> latestReceiptPayload = const Value.absent(),
                Value<int> latestReceiptBeforeGeneration = const Value.absent(),
                Value<int> latestReceiptBeforeSequence = const Value.absent(),
                Value<int> latestReceiptBeforeCursorRevision =
                    const Value.absent(),
                Value<int> latestReceiptCommitOrdinal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningRunsCompanion(
                scopeId: scopeId,
                activityId: activityId,
                activityKind: activityKind,
                runGeneration: runGeneration,
                sequence: sequence,
                cursorRevision: cursorRevision,
                contentBindingId: contentBindingId,
                runMode: runMode,
                finished: finished,
                sessionId: sessionId,
                policyRevision: policyRevision,
                thresholdPercent: thresholdPercent,
                runStartRound: runStartRound,
                checkpointJson: checkpointJson,
                latestReceiptToken: latestReceiptToken,
                latestReceiptPayload: latestReceiptPayload,
                latestReceiptBeforeGeneration: latestReceiptBeforeGeneration,
                latestReceiptBeforeSequence: latestReceiptBeforeSequence,
                latestReceiptBeforeCursorRevision:
                    latestReceiptBeforeCursorRevision,
                latestReceiptCommitOrdinal: latestReceiptCommitOrdinal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String activityId,
                required String activityKind,
                required int runGeneration,
                required int sequence,
                required int cursorRevision,
                required int contentBindingId,
                Value<String?> runMode = const Value.absent(),
                required int finished,
                Value<String?> sessionId = const Value.absent(),
                Value<int?> policyRevision = const Value.absent(),
                Value<int?> thresholdPercent = const Value.absent(),
                Value<int?> runStartRound = const Value.absent(),
                required String checkpointJson,
                required String latestReceiptToken,
                required String latestReceiptPayload,
                required int latestReceiptBeforeGeneration,
                required int latestReceiptBeforeSequence,
                required int latestReceiptBeforeCursorRevision,
                required int latestReceiptCommitOrdinal,
                Value<int> rowid = const Value.absent(),
              }) => LearningRunsCompanion.insert(
                scopeId: scopeId,
                activityId: activityId,
                activityKind: activityKind,
                runGeneration: runGeneration,
                sequence: sequence,
                cursorRevision: cursorRevision,
                contentBindingId: contentBindingId,
                runMode: runMode,
                finished: finished,
                sessionId: sessionId,
                policyRevision: policyRevision,
                thresholdPercent: thresholdPercent,
                runStartRound: runStartRound,
                checkpointJson: checkpointJson,
                latestReceiptToken: latestReceiptToken,
                latestReceiptPayload: latestReceiptPayload,
                latestReceiptBeforeGeneration: latestReceiptBeforeGeneration,
                latestReceiptBeforeSequence: latestReceiptBeforeSequence,
                latestReceiptBeforeCursorRevision:
                    latestReceiptBeforeCursorRevision,
                latestReceiptCommitOrdinal: latestReceiptCommitOrdinal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LearningRunsTable, LearningRun>(table),
                  $$LearningRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false, contentBindingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable: $$LearningRunsTableReferences
                                    ._scopeIdTable(db),
                                referencedColumn: $$LearningRunsTableReferences
                                    ._scopeIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (contentBindingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.contentBindingId,
                                referencedTable: $$LearningRunsTableReferences
                                    ._contentBindingIdTable(db),
                                referencedColumn: $$LearningRunsTableReferences
                                    ._contentBindingIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabase,
      $LearningRunsTable,
      LearningRun,
      $$LearningRunsTableFilterComposer,
      $$LearningRunsTableOrderingComposer,
      $$LearningRunsTableAnnotationComposer,
      $$LearningRunsTableCreateCompanionBuilder,
      $$LearningRunsTableUpdateCompanionBuilder,
      (LearningRun, $$LearningRunsTableReferences),
      LearningRun,
      PrefetchHooks Function({bool scopeId, bool contentBindingId})
    >;
typedef $$LearningAttemptsTableCreateCompanionBuilder =
    LearningAttemptsCompanion Function({
      required int scopeId,
      required String attemptId,
      required String activityId,
      required int runGeneration,
      required int commandSequence,
      required int batchIndex,
      Value<String?> itemId,
      Value<int?> itemOccurrence,
      required int contentRevision,
      required int commitOrdinal,
      required int answeredAtUs,
      required int committedAtUs,
      required String answerKind,
      required int correct,
      Value<String?> skill,
      Value<String?> origin,
      Value<String?> presentation,
      Value<int?> assistanceMask,
      Value<String?> contentState,
      Value<String?> audioSource,
      Value<int?> round,
      Value<int?> afterDebrief,
      Value<int?> teachingExposed,
      Value<String?> selectedRelation,
      Value<String?> expectedRelation,
      Value<String?> sectionId,
      Value<String?> sentenceId,
      Value<String?> annotationHash,
      Value<int?> annotationRevision,
      Value<int> rowid,
    });
typedef $$LearningAttemptsTableUpdateCompanionBuilder =
    LearningAttemptsCompanion Function({
      Value<int> scopeId,
      Value<String> attemptId,
      Value<String> activityId,
      Value<int> runGeneration,
      Value<int> commandSequence,
      Value<int> batchIndex,
      Value<String?> itemId,
      Value<int?> itemOccurrence,
      Value<int> contentRevision,
      Value<int> commitOrdinal,
      Value<int> answeredAtUs,
      Value<int> committedAtUs,
      Value<String> answerKind,
      Value<int> correct,
      Value<String?> skill,
      Value<String?> origin,
      Value<String?> presentation,
      Value<int?> assistanceMask,
      Value<String?> contentState,
      Value<String?> audioSource,
      Value<int?> round,
      Value<int?> afterDebrief,
      Value<int?> teachingExposed,
      Value<String?> selectedRelation,
      Value<String?> expectedRelation,
      Value<String?> sectionId,
      Value<String?> sentenceId,
      Value<String?> annotationHash,
      Value<int?> annotationRevision,
      Value<int> rowid,
    });

final class $$LearningAttemptsTableReferences
    extends
        BaseReferences<
          _$LearningDatabase,
          $LearningAttemptsTable,
          LearningAttempt
        > {
  $$LearningAttemptsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningScopesTable _scopeIdTable(_$LearningDatabase db) => db
      .learningScopes
      .createAlias('learning_attempts__scope_id__learning_scopes__id');

  $$LearningScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$LearningScopesTableTableManager(
      $_db,
      $_db.learningScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningAttemptsTableFilterComposer
    extends Composer<_$LearningDatabase, $LearningAttemptsTable> {
  $$LearningAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runGeneration => $composableBuilder(
    column: $table.runGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get commandSequence => $composableBuilder(
    column: $table.commandSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get batchIndex => $composableBuilder(
    column: $table.batchIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemOccurrence => $composableBuilder(
    column: $table.itemOccurrence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get commitOrdinal => $composableBuilder(
    column: $table.commitOrdinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get answeredAtUs => $composableBuilder(
    column: $table.answeredAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get committedAtUs => $composableBuilder(
    column: $table.committedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answerKind => $composableBuilder(
    column: $table.answerKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skill => $composableBuilder(
    column: $table.skill,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presentation => $composableBuilder(
    column: $table.presentation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get assistanceMask => $composableBuilder(
    column: $table.assistanceMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentState => $composableBuilder(
    column: $table.contentState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioSource => $composableBuilder(
    column: $table.audioSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get afterDebrief => $composableBuilder(
    column: $table.afterDebrief,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get teachingExposed => $composableBuilder(
    column: $table.teachingExposed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedRelation => $composableBuilder(
    column: $table.selectedRelation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expectedRelation => $composableBuilder(
    column: $table.expectedRelation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningScopesTableFilterComposer get scopeId {
    final $$LearningScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableFilterComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningAttemptsTableOrderingComposer
    extends Composer<_$LearningDatabase, $LearningAttemptsTable> {
  $$LearningAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runGeneration => $composableBuilder(
    column: $table.runGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get commandSequence => $composableBuilder(
    column: $table.commandSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get batchIndex => $composableBuilder(
    column: $table.batchIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemOccurrence => $composableBuilder(
    column: $table.itemOccurrence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get commitOrdinal => $composableBuilder(
    column: $table.commitOrdinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get answeredAtUs => $composableBuilder(
    column: $table.answeredAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get committedAtUs => $composableBuilder(
    column: $table.committedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerKind => $composableBuilder(
    column: $table.answerKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skill => $composableBuilder(
    column: $table.skill,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presentation => $composableBuilder(
    column: $table.presentation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get assistanceMask => $composableBuilder(
    column: $table.assistanceMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentState => $composableBuilder(
    column: $table.contentState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioSource => $composableBuilder(
    column: $table.audioSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get afterDebrief => $composableBuilder(
    column: $table.afterDebrief,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get teachingExposed => $composableBuilder(
    column: $table.teachingExposed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedRelation => $composableBuilder(
    column: $table.selectedRelation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expectedRelation => $composableBuilder(
    column: $table.expectedRelation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningScopesTableOrderingComposer get scopeId {
    final $$LearningScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableOrderingComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningAttemptsTableAnnotationComposer
    extends Composer<_$LearningDatabase, $LearningAttemptsTable> {
  $$LearningAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get attemptId =>
      $composableBuilder(column: $table.attemptId, builder: (column) => column);

  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get runGeneration => $composableBuilder(
    column: $table.runGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get commandSequence => $composableBuilder(
    column: $table.commandSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get batchIndex => $composableBuilder(
    column: $table.batchIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get itemOccurrence => $composableBuilder(
    column: $table.itemOccurrence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get commitOrdinal => $composableBuilder(
    column: $table.commitOrdinal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get answeredAtUs => $composableBuilder(
    column: $table.answeredAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get committedAtUs => $composableBuilder(
    column: $table.committedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answerKind => $composableBuilder(
    column: $table.answerKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<String> get skill =>
      $composableBuilder(column: $table.skill, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get presentation => $composableBuilder(
    column: $table.presentation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get assistanceMask => $composableBuilder(
    column: $table.assistanceMask,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentState => $composableBuilder(
    column: $table.contentState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioSource => $composableBuilder(
    column: $table.audioSource,
    builder: (column) => column,
  );

  GeneratedColumn<int> get round =>
      $composableBuilder(column: $table.round, builder: (column) => column);

  GeneratedColumn<int> get afterDebrief => $composableBuilder(
    column: $table.afterDebrief,
    builder: (column) => column,
  );

  GeneratedColumn<int> get teachingExposed => $composableBuilder(
    column: $table.teachingExposed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedRelation => $composableBuilder(
    column: $table.selectedRelation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expectedRelation => $composableBuilder(
    column: $table.expectedRelation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => column,
  );

  $$LearningScopesTableAnnotationComposer get scopeId {
    final $$LearningScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningAttemptsTableTableManager
    extends
        RootTableManager<
          _$LearningDatabase,
          $LearningAttemptsTable,
          LearningAttempt,
          $$LearningAttemptsTableFilterComposer,
          $$LearningAttemptsTableOrderingComposer,
          $$LearningAttemptsTableAnnotationComposer,
          $$LearningAttemptsTableCreateCompanionBuilder,
          $$LearningAttemptsTableUpdateCompanionBuilder,
          (LearningAttempt, $$LearningAttemptsTableReferences),
          LearningAttempt,
          PrefetchHooks Function({bool scopeId})
        > {
  $$LearningAttemptsTableTableManager(
    _$LearningDatabase db,
    $LearningAttemptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningAttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> attemptId = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<int> runGeneration = const Value.absent(),
                Value<int> commandSequence = const Value.absent(),
                Value<int> batchIndex = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<int?> itemOccurrence = const Value.absent(),
                Value<int> contentRevision = const Value.absent(),
                Value<int> commitOrdinal = const Value.absent(),
                Value<int> answeredAtUs = const Value.absent(),
                Value<int> committedAtUs = const Value.absent(),
                Value<String> answerKind = const Value.absent(),
                Value<int> correct = const Value.absent(),
                Value<String?> skill = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> presentation = const Value.absent(),
                Value<int?> assistanceMask = const Value.absent(),
                Value<String?> contentState = const Value.absent(),
                Value<String?> audioSource = const Value.absent(),
                Value<int?> round = const Value.absent(),
                Value<int?> afterDebrief = const Value.absent(),
                Value<int?> teachingExposed = const Value.absent(),
                Value<String?> selectedRelation = const Value.absent(),
                Value<String?> expectedRelation = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String?> sentenceId = const Value.absent(),
                Value<String?> annotationHash = const Value.absent(),
                Value<int?> annotationRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningAttemptsCompanion(
                scopeId: scopeId,
                attemptId: attemptId,
                activityId: activityId,
                runGeneration: runGeneration,
                commandSequence: commandSequence,
                batchIndex: batchIndex,
                itemId: itemId,
                itemOccurrence: itemOccurrence,
                contentRevision: contentRevision,
                commitOrdinal: commitOrdinal,
                answeredAtUs: answeredAtUs,
                committedAtUs: committedAtUs,
                answerKind: answerKind,
                correct: correct,
                skill: skill,
                origin: origin,
                presentation: presentation,
                assistanceMask: assistanceMask,
                contentState: contentState,
                audioSource: audioSource,
                round: round,
                afterDebrief: afterDebrief,
                teachingExposed: teachingExposed,
                selectedRelation: selectedRelation,
                expectedRelation: expectedRelation,
                sectionId: sectionId,
                sentenceId: sentenceId,
                annotationHash: annotationHash,
                annotationRevision: annotationRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String attemptId,
                required String activityId,
                required int runGeneration,
                required int commandSequence,
                required int batchIndex,
                Value<String?> itemId = const Value.absent(),
                Value<int?> itemOccurrence = const Value.absent(),
                required int contentRevision,
                required int commitOrdinal,
                required int answeredAtUs,
                required int committedAtUs,
                required String answerKind,
                required int correct,
                Value<String?> skill = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> presentation = const Value.absent(),
                Value<int?> assistanceMask = const Value.absent(),
                Value<String?> contentState = const Value.absent(),
                Value<String?> audioSource = const Value.absent(),
                Value<int?> round = const Value.absent(),
                Value<int?> afterDebrief = const Value.absent(),
                Value<int?> teachingExposed = const Value.absent(),
                Value<String?> selectedRelation = const Value.absent(),
                Value<String?> expectedRelation = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String?> sentenceId = const Value.absent(),
                Value<String?> annotationHash = const Value.absent(),
                Value<int?> annotationRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningAttemptsCompanion.insert(
                scopeId: scopeId,
                attemptId: attemptId,
                activityId: activityId,
                runGeneration: runGeneration,
                commandSequence: commandSequence,
                batchIndex: batchIndex,
                itemId: itemId,
                itemOccurrence: itemOccurrence,
                contentRevision: contentRevision,
                commitOrdinal: commitOrdinal,
                answeredAtUs: answeredAtUs,
                committedAtUs: committedAtUs,
                answerKind: answerKind,
                correct: correct,
                skill: skill,
                origin: origin,
                presentation: presentation,
                assistanceMask: assistanceMask,
                contentState: contentState,
                audioSource: audioSource,
                round: round,
                afterDebrief: afterDebrief,
                teachingExposed: teachingExposed,
                selectedRelation: selectedRelation,
                expectedRelation: expectedRelation,
                sectionId: sectionId,
                sentenceId: sentenceId,
                annotationHash: annotationHash,
                annotationRevision: annotationRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LearningAttemptsTable, LearningAttempt>(table),
                  $$LearningAttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$LearningAttemptsTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$LearningAttemptsTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabase,
      $LearningAttemptsTable,
      LearningAttempt,
      $$LearningAttemptsTableFilterComposer,
      $$LearningAttemptsTableOrderingComposer,
      $$LearningAttemptsTableAnnotationComposer,
      $$LearningAttemptsTableCreateCompanionBuilder,
      $$LearningAttemptsTableUpdateCompanionBuilder,
      (LearningAttempt, $$LearningAttemptsTableReferences),
      LearningAttempt,
      PrefetchHooks Function({bool scopeId})
    >;
typedef $$LearningAttemptValuesTableCreateCompanionBuilder =
    LearningAttemptValuesCompanion Function({
      required int scopeId,
      required String attemptId,
      required String field,
      required int ordinal,
      required String valueType,
      Value<String?> textValue,
      Value<int?> intValue,
      Value<int?> boolValue,
      Value<int> rowid,
    });
typedef $$LearningAttemptValuesTableUpdateCompanionBuilder =
    LearningAttemptValuesCompanion Function({
      Value<int> scopeId,
      Value<String> attemptId,
      Value<String> field,
      Value<int> ordinal,
      Value<String> valueType,
      Value<String?> textValue,
      Value<int?> intValue,
      Value<int?> boolValue,
      Value<int> rowid,
    });

final class $$LearningAttemptValuesTableReferences
    extends
        BaseReferences<
          _$LearningDatabase,
          $LearningAttemptValuesTable,
          LearningAttemptValue
        > {
  $$LearningAttemptValuesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningScopesTable _scopeIdTable(_$LearningDatabase db) => db
      .learningScopes
      .createAlias('learning_attempt_values__scope_id__learning_scopes__id');

  $$LearningScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$LearningScopesTableTableManager(
      $_db,
      $_db.learningScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningAttemptValuesTableFilterComposer
    extends Composer<_$LearningDatabase, $LearningAttemptValuesTable> {
  $$LearningAttemptValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textValue => $composableBuilder(
    column: $table.textValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intValue => $composableBuilder(
    column: $table.intValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get boolValue => $composableBuilder(
    column: $table.boolValue,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningScopesTableFilterComposer get scopeId {
    final $$LearningScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableFilterComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningAttemptValuesTableOrderingComposer
    extends Composer<_$LearningDatabase, $LearningAttemptValuesTable> {
  $$LearningAttemptValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textValue => $composableBuilder(
    column: $table.textValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intValue => $composableBuilder(
    column: $table.intValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get boolValue => $composableBuilder(
    column: $table.boolValue,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningScopesTableOrderingComposer get scopeId {
    final $$LearningScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableOrderingComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningAttemptValuesTableAnnotationComposer
    extends Composer<_$LearningDatabase, $LearningAttemptValuesTable> {
  $$LearningAttemptValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get attemptId =>
      $composableBuilder(column: $table.attemptId, builder: (column) => column);

  GeneratedColumn<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<String> get valueType =>
      $composableBuilder(column: $table.valueType, builder: (column) => column);

  GeneratedColumn<String> get textValue =>
      $composableBuilder(column: $table.textValue, builder: (column) => column);

  GeneratedColumn<int> get intValue =>
      $composableBuilder(column: $table.intValue, builder: (column) => column);

  GeneratedColumn<int> get boolValue =>
      $composableBuilder(column: $table.boolValue, builder: (column) => column);

  $$LearningScopesTableAnnotationComposer get scopeId {
    final $$LearningScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningAttemptValuesTableTableManager
    extends
        RootTableManager<
          _$LearningDatabase,
          $LearningAttemptValuesTable,
          LearningAttemptValue,
          $$LearningAttemptValuesTableFilterComposer,
          $$LearningAttemptValuesTableOrderingComposer,
          $$LearningAttemptValuesTableAnnotationComposer,
          $$LearningAttemptValuesTableCreateCompanionBuilder,
          $$LearningAttemptValuesTableUpdateCompanionBuilder,
          (LearningAttemptValue, $$LearningAttemptValuesTableReferences),
          LearningAttemptValue,
          PrefetchHooks Function({bool scopeId})
        > {
  $$LearningAttemptValuesTableTableManager(
    _$LearningDatabase db,
    $LearningAttemptValuesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningAttemptValuesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LearningAttemptValuesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LearningAttemptValuesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> attemptId = const Value.absent(),
                Value<String> field = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<String> valueType = const Value.absent(),
                Value<String?> textValue = const Value.absent(),
                Value<int?> intValue = const Value.absent(),
                Value<int?> boolValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningAttemptValuesCompanion(
                scopeId: scopeId,
                attemptId: attemptId,
                field: field,
                ordinal: ordinal,
                valueType: valueType,
                textValue: textValue,
                intValue: intValue,
                boolValue: boolValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String attemptId,
                required String field,
                required int ordinal,
                required String valueType,
                Value<String?> textValue = const Value.absent(),
                Value<int?> intValue = const Value.absent(),
                Value<int?> boolValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningAttemptValuesCompanion.insert(
                scopeId: scopeId,
                attemptId: attemptId,
                field: field,
                ordinal: ordinal,
                valueType: valueType,
                textValue: textValue,
                intValue: intValue,
                boolValue: boolValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LearningAttemptValuesTable,
                    LearningAttemptValue
                  >(table),
                  $$LearningAttemptValuesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$LearningAttemptValuesTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$LearningAttemptValuesTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningAttemptValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabase,
      $LearningAttemptValuesTable,
      LearningAttemptValue,
      $$LearningAttemptValuesTableFilterComposer,
      $$LearningAttemptValuesTableOrderingComposer,
      $$LearningAttemptValuesTableAnnotationComposer,
      $$LearningAttemptValuesTableCreateCompanionBuilder,
      $$LearningAttemptValuesTableUpdateCompanionBuilder,
      (LearningAttemptValue, $$LearningAttemptValuesTableReferences),
      LearningAttemptValue,
      PrefetchHooks Function({bool scopeId})
    >;
typedef $$LearningAttemptEvidenceTableCreateCompanionBuilder =
    LearningAttemptEvidenceCompanion Function({
      required int scopeId,
      required String attemptId,
      required int evidenceIndex,
      required String evidenceKind,
      Value<String?> slot,
      Value<String?> referenceId,
      Value<String?> outcome,
      Value<String?> source,
      Value<String?> activityId,
      Value<int?> runGeneration,
      Value<int?> round,
      Value<String?> pairId,
      Value<int?> uiGeneration,
      Value<String?> sectionId,
      Value<String?> itemId,
      Value<String?> sentenceId,
      Value<String?> audioRefId,
      Value<String?> annotationHash,
      Value<int?> annotationRevision,
      Value<int?> contentRevision,
      Value<int> rowid,
    });
typedef $$LearningAttemptEvidenceTableUpdateCompanionBuilder =
    LearningAttemptEvidenceCompanion Function({
      Value<int> scopeId,
      Value<String> attemptId,
      Value<int> evidenceIndex,
      Value<String> evidenceKind,
      Value<String?> slot,
      Value<String?> referenceId,
      Value<String?> outcome,
      Value<String?> source,
      Value<String?> activityId,
      Value<int?> runGeneration,
      Value<int?> round,
      Value<String?> pairId,
      Value<int?> uiGeneration,
      Value<String?> sectionId,
      Value<String?> itemId,
      Value<String?> sentenceId,
      Value<String?> audioRefId,
      Value<String?> annotationHash,
      Value<int?> annotationRevision,
      Value<int?> contentRevision,
      Value<int> rowid,
    });

final class $$LearningAttemptEvidenceTableReferences
    extends
        BaseReferences<
          _$LearningDatabase,
          $LearningAttemptEvidenceTable,
          LearningAttemptEvidenceData
        > {
  $$LearningAttemptEvidenceTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningScopesTable _scopeIdTable(_$LearningDatabase db) => db
      .learningScopes
      .createAlias('learning_attempt_evidence__scope_id__learning_scopes__id');

  $$LearningScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$LearningScopesTableTableManager(
      $_db,
      $_db.learningScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningAttemptEvidenceTableFilterComposer
    extends Composer<_$LearningDatabase, $LearningAttemptEvidenceTable> {
  $$LearningAttemptEvidenceTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get evidenceIndex => $composableBuilder(
    column: $table.evidenceIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceKind => $composableBuilder(
    column: $table.evidenceKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runGeneration => $composableBuilder(
    column: $table.runGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pairId => $composableBuilder(
    column: $table.pairId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uiGeneration => $composableBuilder(
    column: $table.uiGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioRefId => $composableBuilder(
    column: $table.audioRefId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningScopesTableFilterComposer get scopeId {
    final $$LearningScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableFilterComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningAttemptEvidenceTableOrderingComposer
    extends Composer<_$LearningDatabase, $LearningAttemptEvidenceTable> {
  $$LearningAttemptEvidenceTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get evidenceIndex => $composableBuilder(
    column: $table.evidenceIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceKind => $composableBuilder(
    column: $table.evidenceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runGeneration => $composableBuilder(
    column: $table.runGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pairId => $composableBuilder(
    column: $table.pairId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uiGeneration => $composableBuilder(
    column: $table.uiGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioRefId => $composableBuilder(
    column: $table.audioRefId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningScopesTableOrderingComposer get scopeId {
    final $$LearningScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableOrderingComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningAttemptEvidenceTableAnnotationComposer
    extends Composer<_$LearningDatabase, $LearningAttemptEvidenceTable> {
  $$LearningAttemptEvidenceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get attemptId =>
      $composableBuilder(column: $table.attemptId, builder: (column) => column);

  GeneratedColumn<int> get evidenceIndex => $composableBuilder(
    column: $table.evidenceIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidenceKind => $composableBuilder(
    column: $table.evidenceKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get runGeneration => $composableBuilder(
    column: $table.runGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get round =>
      $composableBuilder(column: $table.round, builder: (column) => column);

  GeneratedColumn<String> get pairId =>
      $composableBuilder(column: $table.pairId, builder: (column) => column);

  GeneratedColumn<int> get uiGeneration => $composableBuilder(
    column: $table.uiGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioRefId => $composableBuilder(
    column: $table.audioRefId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => column,
  );

  $$LearningScopesTableAnnotationComposer get scopeId {
    final $$LearningScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningAttemptEvidenceTableTableManager
    extends
        RootTableManager<
          _$LearningDatabase,
          $LearningAttemptEvidenceTable,
          LearningAttemptEvidenceData,
          $$LearningAttemptEvidenceTableFilterComposer,
          $$LearningAttemptEvidenceTableOrderingComposer,
          $$LearningAttemptEvidenceTableAnnotationComposer,
          $$LearningAttemptEvidenceTableCreateCompanionBuilder,
          $$LearningAttemptEvidenceTableUpdateCompanionBuilder,
          (
            LearningAttemptEvidenceData,
            $$LearningAttemptEvidenceTableReferences,
          ),
          LearningAttemptEvidenceData,
          PrefetchHooks Function({bool scopeId})
        > {
  $$LearningAttemptEvidenceTableTableManager(
    _$LearningDatabase db,
    $LearningAttemptEvidenceTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningAttemptEvidenceTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LearningAttemptEvidenceTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LearningAttemptEvidenceTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> attemptId = const Value.absent(),
                Value<int> evidenceIndex = const Value.absent(),
                Value<String> evidenceKind = const Value.absent(),
                Value<String?> slot = const Value.absent(),
                Value<String?> referenceId = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> activityId = const Value.absent(),
                Value<int?> runGeneration = const Value.absent(),
                Value<int?> round = const Value.absent(),
                Value<String?> pairId = const Value.absent(),
                Value<int?> uiGeneration = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> sentenceId = const Value.absent(),
                Value<String?> audioRefId = const Value.absent(),
                Value<String?> annotationHash = const Value.absent(),
                Value<int?> annotationRevision = const Value.absent(),
                Value<int?> contentRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningAttemptEvidenceCompanion(
                scopeId: scopeId,
                attemptId: attemptId,
                evidenceIndex: evidenceIndex,
                evidenceKind: evidenceKind,
                slot: slot,
                referenceId: referenceId,
                outcome: outcome,
                source: source,
                activityId: activityId,
                runGeneration: runGeneration,
                round: round,
                pairId: pairId,
                uiGeneration: uiGeneration,
                sectionId: sectionId,
                itemId: itemId,
                sentenceId: sentenceId,
                audioRefId: audioRefId,
                annotationHash: annotationHash,
                annotationRevision: annotationRevision,
                contentRevision: contentRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String attemptId,
                required int evidenceIndex,
                required String evidenceKind,
                Value<String?> slot = const Value.absent(),
                Value<String?> referenceId = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> activityId = const Value.absent(),
                Value<int?> runGeneration = const Value.absent(),
                Value<int?> round = const Value.absent(),
                Value<String?> pairId = const Value.absent(),
                Value<int?> uiGeneration = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> sentenceId = const Value.absent(),
                Value<String?> audioRefId = const Value.absent(),
                Value<String?> annotationHash = const Value.absent(),
                Value<int?> annotationRevision = const Value.absent(),
                Value<int?> contentRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningAttemptEvidenceCompanion.insert(
                scopeId: scopeId,
                attemptId: attemptId,
                evidenceIndex: evidenceIndex,
                evidenceKind: evidenceKind,
                slot: slot,
                referenceId: referenceId,
                outcome: outcome,
                source: source,
                activityId: activityId,
                runGeneration: runGeneration,
                round: round,
                pairId: pairId,
                uiGeneration: uiGeneration,
                sectionId: sectionId,
                itemId: itemId,
                sentenceId: sentenceId,
                audioRefId: audioRefId,
                annotationHash: annotationHash,
                annotationRevision: annotationRevision,
                contentRevision: contentRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LearningAttemptEvidenceTable,
                    LearningAttemptEvidenceData
                  >(table),
                  $$LearningAttemptEvidenceTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$LearningAttemptEvidenceTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$LearningAttemptEvidenceTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningAttemptEvidenceTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabase,
      $LearningAttemptEvidenceTable,
      LearningAttemptEvidenceData,
      $$LearningAttemptEvidenceTableFilterComposer,
      $$LearningAttemptEvidenceTableOrderingComposer,
      $$LearningAttemptEvidenceTableAnnotationComposer,
      $$LearningAttemptEvidenceTableCreateCompanionBuilder,
      $$LearningAttemptEvidenceTableUpdateCompanionBuilder,
      (LearningAttemptEvidenceData, $$LearningAttemptEvidenceTableReferences),
      LearningAttemptEvidenceData,
      PrefetchHooks Function({bool scopeId})
    >;
typedef $$LearningCommandReceiptsTableCreateCompanionBuilder =
    LearningCommandReceiptsCompanion Function({
      required int scopeId,
      required String activityId,
      required String token,
      required String canonicalPayload,
      required int beforeGeneration,
      required int beforeSequence,
      required int beforeCursorRevision,
      required int afterGeneration,
      required int afterSequence,
      required int afterCursorRevision,
      required int commitOrdinal,
      required String resultActivityId,
      required int resultGeneration,
      required int resultSequence,
      required int resultCursorRevision,
      Value<int> rowid,
    });
typedef $$LearningCommandReceiptsTableUpdateCompanionBuilder =
    LearningCommandReceiptsCompanion Function({
      Value<int> scopeId,
      Value<String> activityId,
      Value<String> token,
      Value<String> canonicalPayload,
      Value<int> beforeGeneration,
      Value<int> beforeSequence,
      Value<int> beforeCursorRevision,
      Value<int> afterGeneration,
      Value<int> afterSequence,
      Value<int> afterCursorRevision,
      Value<int> commitOrdinal,
      Value<String> resultActivityId,
      Value<int> resultGeneration,
      Value<int> resultSequence,
      Value<int> resultCursorRevision,
      Value<int> rowid,
    });

final class $$LearningCommandReceiptsTableReferences
    extends
        BaseReferences<
          _$LearningDatabase,
          $LearningCommandReceiptsTable,
          LearningCommandReceipt
        > {
  $$LearningCommandReceiptsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningScopesTable _scopeIdTable(_$LearningDatabase db) => db
      .learningScopes
      .createAlias('learning_command_receipts__scope_id__learning_scopes__id');

  $$LearningScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$LearningScopesTableTableManager(
      $_db,
      $_db.learningScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningCommandReceiptsTableFilterComposer
    extends Composer<_$LearningDatabase, $LearningCommandReceiptsTable> {
  $$LearningCommandReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalPayload => $composableBuilder(
    column: $table.canonicalPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get beforeGeneration => $composableBuilder(
    column: $table.beforeGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get beforeSequence => $composableBuilder(
    column: $table.beforeSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get beforeCursorRevision => $composableBuilder(
    column: $table.beforeCursorRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get afterGeneration => $composableBuilder(
    column: $table.afterGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get afterSequence => $composableBuilder(
    column: $table.afterSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get afterCursorRevision => $composableBuilder(
    column: $table.afterCursorRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get commitOrdinal => $composableBuilder(
    column: $table.commitOrdinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultActivityId => $composableBuilder(
    column: $table.resultActivityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resultGeneration => $composableBuilder(
    column: $table.resultGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resultSequence => $composableBuilder(
    column: $table.resultSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resultCursorRevision => $composableBuilder(
    column: $table.resultCursorRevision,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningScopesTableFilterComposer get scopeId {
    final $$LearningScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableFilterComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningCommandReceiptsTableOrderingComposer
    extends Composer<_$LearningDatabase, $LearningCommandReceiptsTable> {
  $$LearningCommandReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalPayload => $composableBuilder(
    column: $table.canonicalPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get beforeGeneration => $composableBuilder(
    column: $table.beforeGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get beforeSequence => $composableBuilder(
    column: $table.beforeSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get beforeCursorRevision => $composableBuilder(
    column: $table.beforeCursorRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get afterGeneration => $composableBuilder(
    column: $table.afterGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get afterSequence => $composableBuilder(
    column: $table.afterSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get afterCursorRevision => $composableBuilder(
    column: $table.afterCursorRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get commitOrdinal => $composableBuilder(
    column: $table.commitOrdinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultActivityId => $composableBuilder(
    column: $table.resultActivityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resultGeneration => $composableBuilder(
    column: $table.resultGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resultSequence => $composableBuilder(
    column: $table.resultSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resultCursorRevision => $composableBuilder(
    column: $table.resultCursorRevision,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningScopesTableOrderingComposer get scopeId {
    final $$LearningScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableOrderingComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningCommandReceiptsTableAnnotationComposer
    extends Composer<_$LearningDatabase, $LearningCommandReceiptsTable> {
  $$LearningCommandReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get token =>
      $composableBuilder(column: $table.token, builder: (column) => column);

  GeneratedColumn<String> get canonicalPayload => $composableBuilder(
    column: $table.canonicalPayload,
    builder: (column) => column,
  );

  GeneratedColumn<int> get beforeGeneration => $composableBuilder(
    column: $table.beforeGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get beforeSequence => $composableBuilder(
    column: $table.beforeSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get beforeCursorRevision => $composableBuilder(
    column: $table.beforeCursorRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get afterGeneration => $composableBuilder(
    column: $table.afterGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get afterSequence => $composableBuilder(
    column: $table.afterSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get afterCursorRevision => $composableBuilder(
    column: $table.afterCursorRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get commitOrdinal => $composableBuilder(
    column: $table.commitOrdinal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultActivityId => $composableBuilder(
    column: $table.resultActivityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resultGeneration => $composableBuilder(
    column: $table.resultGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resultSequence => $composableBuilder(
    column: $table.resultSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resultCursorRevision => $composableBuilder(
    column: $table.resultCursorRevision,
    builder: (column) => column,
  );

  $$LearningScopesTableAnnotationComposer get scopeId {
    final $$LearningScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningCommandReceiptsTableTableManager
    extends
        RootTableManager<
          _$LearningDatabase,
          $LearningCommandReceiptsTable,
          LearningCommandReceipt,
          $$LearningCommandReceiptsTableFilterComposer,
          $$LearningCommandReceiptsTableOrderingComposer,
          $$LearningCommandReceiptsTableAnnotationComposer,
          $$LearningCommandReceiptsTableCreateCompanionBuilder,
          $$LearningCommandReceiptsTableUpdateCompanionBuilder,
          (LearningCommandReceipt, $$LearningCommandReceiptsTableReferences),
          LearningCommandReceipt,
          PrefetchHooks Function({bool scopeId})
        > {
  $$LearningCommandReceiptsTableTableManager(
    _$LearningDatabase db,
    $LearningCommandReceiptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningCommandReceiptsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LearningCommandReceiptsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LearningCommandReceiptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<String> token = const Value.absent(),
                Value<String> canonicalPayload = const Value.absent(),
                Value<int> beforeGeneration = const Value.absent(),
                Value<int> beforeSequence = const Value.absent(),
                Value<int> beforeCursorRevision = const Value.absent(),
                Value<int> afterGeneration = const Value.absent(),
                Value<int> afterSequence = const Value.absent(),
                Value<int> afterCursorRevision = const Value.absent(),
                Value<int> commitOrdinal = const Value.absent(),
                Value<String> resultActivityId = const Value.absent(),
                Value<int> resultGeneration = const Value.absent(),
                Value<int> resultSequence = const Value.absent(),
                Value<int> resultCursorRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningCommandReceiptsCompanion(
                scopeId: scopeId,
                activityId: activityId,
                token: token,
                canonicalPayload: canonicalPayload,
                beforeGeneration: beforeGeneration,
                beforeSequence: beforeSequence,
                beforeCursorRevision: beforeCursorRevision,
                afterGeneration: afterGeneration,
                afterSequence: afterSequence,
                afterCursorRevision: afterCursorRevision,
                commitOrdinal: commitOrdinal,
                resultActivityId: resultActivityId,
                resultGeneration: resultGeneration,
                resultSequence: resultSequence,
                resultCursorRevision: resultCursorRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String activityId,
                required String token,
                required String canonicalPayload,
                required int beforeGeneration,
                required int beforeSequence,
                required int beforeCursorRevision,
                required int afterGeneration,
                required int afterSequence,
                required int afterCursorRevision,
                required int commitOrdinal,
                required String resultActivityId,
                required int resultGeneration,
                required int resultSequence,
                required int resultCursorRevision,
                Value<int> rowid = const Value.absent(),
              }) => LearningCommandReceiptsCompanion.insert(
                scopeId: scopeId,
                activityId: activityId,
                token: token,
                canonicalPayload: canonicalPayload,
                beforeGeneration: beforeGeneration,
                beforeSequence: beforeSequence,
                beforeCursorRevision: beforeCursorRevision,
                afterGeneration: afterGeneration,
                afterSequence: afterSequence,
                afterCursorRevision: afterCursorRevision,
                commitOrdinal: commitOrdinal,
                resultActivityId: resultActivityId,
                resultGeneration: resultGeneration,
                resultSequence: resultSequence,
                resultCursorRevision: resultCursorRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LearningCommandReceiptsTable,
                    LearningCommandReceipt
                  >(table),
                  $$LearningCommandReceiptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$LearningCommandReceiptsTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$LearningCommandReceiptsTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningCommandReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabase,
      $LearningCommandReceiptsTable,
      LearningCommandReceipt,
      $$LearningCommandReceiptsTableFilterComposer,
      $$LearningCommandReceiptsTableOrderingComposer,
      $$LearningCommandReceiptsTableAnnotationComposer,
      $$LearningCommandReceiptsTableCreateCompanionBuilder,
      $$LearningCommandReceiptsTableUpdateCompanionBuilder,
      (LearningCommandReceipt, $$LearningCommandReceiptsTableReferences),
      LearningCommandReceipt,
      PrefetchHooks Function({bool scopeId})
    >;
typedef $$LearningMistakesTableCreateCompanionBuilder =
    LearningMistakesCompanion Function({
      required int scopeId,
      required String family,
      Value<String?> activityId,
      Value<String?> itemId,
      Value<String?> targetSound,
      Value<String?> skill,
      Value<String?> pairId,
      Value<String?> sectionId,
      Value<String?> sentenceId,
      Value<String?> audioRefId,
      Value<String?> annotationHash,
      Value<int?> annotationRevision,
      required int contentRevision,
      Value<String?> firstWrongAttemptId,
      Value<String?> latestWrongAttemptId,
      required int firstWrongAtUs,
      required int latestWrongAtUs,
      required int failureCount,
      Value<int?> lastRunGeneration,
      Value<int> rowid,
    });
typedef $$LearningMistakesTableUpdateCompanionBuilder =
    LearningMistakesCompanion Function({
      Value<int> scopeId,
      Value<String> family,
      Value<String?> activityId,
      Value<String?> itemId,
      Value<String?> targetSound,
      Value<String?> skill,
      Value<String?> pairId,
      Value<String?> sectionId,
      Value<String?> sentenceId,
      Value<String?> audioRefId,
      Value<String?> annotationHash,
      Value<int?> annotationRevision,
      Value<int> contentRevision,
      Value<String?> firstWrongAttemptId,
      Value<String?> latestWrongAttemptId,
      Value<int> firstWrongAtUs,
      Value<int> latestWrongAtUs,
      Value<int> failureCount,
      Value<int?> lastRunGeneration,
      Value<int> rowid,
    });

final class $$LearningMistakesTableReferences
    extends
        BaseReferences<
          _$LearningDatabase,
          $LearningMistakesTable,
          LearningMistake
        > {
  $$LearningMistakesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningScopesTable _scopeIdTable(_$LearningDatabase db) => db
      .learningScopes
      .createAlias('learning_mistakes__scope_id__learning_scopes__id');

  $$LearningScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$LearningScopesTableTableManager(
      $_db,
      $_db.learningScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningMistakesTableFilterComposer
    extends Composer<_$LearningDatabase, $LearningMistakesTable> {
  $$LearningMistakesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetSound => $composableBuilder(
    column: $table.targetSound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skill => $composableBuilder(
    column: $table.skill,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pairId => $composableBuilder(
    column: $table.pairId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioRefId => $composableBuilder(
    column: $table.audioRefId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstWrongAttemptId => $composableBuilder(
    column: $table.firstWrongAttemptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latestWrongAttemptId => $composableBuilder(
    column: $table.latestWrongAttemptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstWrongAtUs => $composableBuilder(
    column: $table.firstWrongAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latestWrongAtUs => $composableBuilder(
    column: $table.latestWrongAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failureCount => $composableBuilder(
    column: $table.failureCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastRunGeneration => $composableBuilder(
    column: $table.lastRunGeneration,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningScopesTableFilterComposer get scopeId {
    final $$LearningScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableFilterComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningMistakesTableOrderingComposer
    extends Composer<_$LearningDatabase, $LearningMistakesTable> {
  $$LearningMistakesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetSound => $composableBuilder(
    column: $table.targetSound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skill => $composableBuilder(
    column: $table.skill,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pairId => $composableBuilder(
    column: $table.pairId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioRefId => $composableBuilder(
    column: $table.audioRefId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstWrongAttemptId => $composableBuilder(
    column: $table.firstWrongAttemptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latestWrongAttemptId => $composableBuilder(
    column: $table.latestWrongAttemptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstWrongAtUs => $composableBuilder(
    column: $table.firstWrongAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latestWrongAtUs => $composableBuilder(
    column: $table.latestWrongAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failureCount => $composableBuilder(
    column: $table.failureCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastRunGeneration => $composableBuilder(
    column: $table.lastRunGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningScopesTableOrderingComposer get scopeId {
    final $$LearningScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableOrderingComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningMistakesTableAnnotationComposer
    extends Composer<_$LearningDatabase, $LearningMistakesTable> {
  $$LearningMistakesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get family =>
      $composableBuilder(column: $table.family, builder: (column) => column);

  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get targetSound => $composableBuilder(
    column: $table.targetSound,
    builder: (column) => column,
  );

  GeneratedColumn<String> get skill =>
      $composableBuilder(column: $table.skill, builder: (column) => column);

  GeneratedColumn<String> get pairId =>
      $composableBuilder(column: $table.pairId, builder: (column) => column);

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioRefId => $composableBuilder(
    column: $table.audioRefId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get firstWrongAttemptId => $composableBuilder(
    column: $table.firstWrongAttemptId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get latestWrongAttemptId => $composableBuilder(
    column: $table.latestWrongAttemptId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get firstWrongAtUs => $composableBuilder(
    column: $table.firstWrongAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get latestWrongAtUs => $composableBuilder(
    column: $table.latestWrongAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failureCount => $composableBuilder(
    column: $table.failureCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastRunGeneration => $composableBuilder(
    column: $table.lastRunGeneration,
    builder: (column) => column,
  );

  $$LearningScopesTableAnnotationComposer get scopeId {
    final $$LearningScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningMistakesTableTableManager
    extends
        RootTableManager<
          _$LearningDatabase,
          $LearningMistakesTable,
          LearningMistake,
          $$LearningMistakesTableFilterComposer,
          $$LearningMistakesTableOrderingComposer,
          $$LearningMistakesTableAnnotationComposer,
          $$LearningMistakesTableCreateCompanionBuilder,
          $$LearningMistakesTableUpdateCompanionBuilder,
          (LearningMistake, $$LearningMistakesTableReferences),
          LearningMistake,
          PrefetchHooks Function({bool scopeId})
        > {
  $$LearningMistakesTableTableManager(
    _$LearningDatabase db,
    $LearningMistakesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningMistakesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningMistakesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningMistakesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> family = const Value.absent(),
                Value<String?> activityId = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> targetSound = const Value.absent(),
                Value<String?> skill = const Value.absent(),
                Value<String?> pairId = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String?> sentenceId = const Value.absent(),
                Value<String?> audioRefId = const Value.absent(),
                Value<String?> annotationHash = const Value.absent(),
                Value<int?> annotationRevision = const Value.absent(),
                Value<int> contentRevision = const Value.absent(),
                Value<String?> firstWrongAttemptId = const Value.absent(),
                Value<String?> latestWrongAttemptId = const Value.absent(),
                Value<int> firstWrongAtUs = const Value.absent(),
                Value<int> latestWrongAtUs = const Value.absent(),
                Value<int> failureCount = const Value.absent(),
                Value<int?> lastRunGeneration = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningMistakesCompanion(
                scopeId: scopeId,
                family: family,
                activityId: activityId,
                itemId: itemId,
                targetSound: targetSound,
                skill: skill,
                pairId: pairId,
                sectionId: sectionId,
                sentenceId: sentenceId,
                audioRefId: audioRefId,
                annotationHash: annotationHash,
                annotationRevision: annotationRevision,
                contentRevision: contentRevision,
                firstWrongAttemptId: firstWrongAttemptId,
                latestWrongAttemptId: latestWrongAttemptId,
                firstWrongAtUs: firstWrongAtUs,
                latestWrongAtUs: latestWrongAtUs,
                failureCount: failureCount,
                lastRunGeneration: lastRunGeneration,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String family,
                Value<String?> activityId = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> targetSound = const Value.absent(),
                Value<String?> skill = const Value.absent(),
                Value<String?> pairId = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String?> sentenceId = const Value.absent(),
                Value<String?> audioRefId = const Value.absent(),
                Value<String?> annotationHash = const Value.absent(),
                Value<int?> annotationRevision = const Value.absent(),
                required int contentRevision,
                Value<String?> firstWrongAttemptId = const Value.absent(),
                Value<String?> latestWrongAttemptId = const Value.absent(),
                required int firstWrongAtUs,
                required int latestWrongAtUs,
                required int failureCount,
                Value<int?> lastRunGeneration = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningMistakesCompanion.insert(
                scopeId: scopeId,
                family: family,
                activityId: activityId,
                itemId: itemId,
                targetSound: targetSound,
                skill: skill,
                pairId: pairId,
                sectionId: sectionId,
                sentenceId: sentenceId,
                audioRefId: audioRefId,
                annotationHash: annotationHash,
                annotationRevision: annotationRevision,
                contentRevision: contentRevision,
                firstWrongAttemptId: firstWrongAttemptId,
                latestWrongAttemptId: latestWrongAttemptId,
                firstWrongAtUs: firstWrongAtUs,
                latestWrongAtUs: latestWrongAtUs,
                failureCount: failureCount,
                lastRunGeneration: lastRunGeneration,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LearningMistakesTable, LearningMistake>(table),
                  $$LearningMistakesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$LearningMistakesTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$LearningMistakesTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningMistakesTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabase,
      $LearningMistakesTable,
      LearningMistake,
      $$LearningMistakesTableFilterComposer,
      $$LearningMistakesTableOrderingComposer,
      $$LearningMistakesTableAnnotationComposer,
      $$LearningMistakesTableCreateCompanionBuilder,
      $$LearningMistakesTableUpdateCompanionBuilder,
      (LearningMistake, $$LearningMistakesTableReferences),
      LearningMistake,
      PrefetchHooks Function({bool scopeId})
    >;
typedef $$LearningSummariesTableCreateCompanionBuilder =
    LearningSummariesCompanion Function({
      required int scopeId,
      required String family,
      Value<String?> activityId,
      Value<String?> sound,
      Value<String?> skill,
      Value<String?> origin,
      Value<String?> presentation,
      Value<int?> assistanceMask,
      Value<String?> pairId,
      Value<String?> sectionId,
      Value<String?> itemId,
      Value<String?> sentenceId,
      Value<String?> audioRefId,
      Value<String?> annotationHash,
      Value<int?> annotationRevision,
      Value<int?> contentRevision,
      required String bucket,
      required int correct,
      required int total,
      Value<int> rowid,
    });
typedef $$LearningSummariesTableUpdateCompanionBuilder =
    LearningSummariesCompanion Function({
      Value<int> scopeId,
      Value<String> family,
      Value<String?> activityId,
      Value<String?> sound,
      Value<String?> skill,
      Value<String?> origin,
      Value<String?> presentation,
      Value<int?> assistanceMask,
      Value<String?> pairId,
      Value<String?> sectionId,
      Value<String?> itemId,
      Value<String?> sentenceId,
      Value<String?> audioRefId,
      Value<String?> annotationHash,
      Value<int?> annotationRevision,
      Value<int?> contentRevision,
      Value<String> bucket,
      Value<int> correct,
      Value<int> total,
      Value<int> rowid,
    });

final class $$LearningSummariesTableReferences
    extends
        BaseReferences<
          _$LearningDatabase,
          $LearningSummariesTable,
          LearningSummary
        > {
  $$LearningSummariesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningScopesTable _scopeIdTable(_$LearningDatabase db) => db
      .learningScopes
      .createAlias('learning_summaries__scope_id__learning_scopes__id');

  $$LearningScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$LearningScopesTableTableManager(
      $_db,
      $_db.learningScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningSummariesTableFilterComposer
    extends Composer<_$LearningDatabase, $LearningSummariesTable> {
  $$LearningSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sound => $composableBuilder(
    column: $table.sound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skill => $composableBuilder(
    column: $table.skill,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presentation => $composableBuilder(
    column: $table.presentation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get assistanceMask => $composableBuilder(
    column: $table.assistanceMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pairId => $composableBuilder(
    column: $table.pairId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioRefId => $composableBuilder(
    column: $table.audioRefId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningScopesTableFilterComposer get scopeId {
    final $$LearningScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableFilterComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningSummariesTableOrderingComposer
    extends Composer<_$LearningDatabase, $LearningSummariesTable> {
  $$LearningSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sound => $composableBuilder(
    column: $table.sound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skill => $composableBuilder(
    column: $table.skill,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presentation => $composableBuilder(
    column: $table.presentation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get assistanceMask => $composableBuilder(
    column: $table.assistanceMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pairId => $composableBuilder(
    column: $table.pairId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioRefId => $composableBuilder(
    column: $table.audioRefId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningScopesTableOrderingComposer get scopeId {
    final $$LearningScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableOrderingComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningSummariesTableAnnotationComposer
    extends Composer<_$LearningDatabase, $LearningSummariesTable> {
  $$LearningSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get family =>
      $composableBuilder(column: $table.family, builder: (column) => column);

  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sound =>
      $composableBuilder(column: $table.sound, builder: (column) => column);

  GeneratedColumn<String> get skill =>
      $composableBuilder(column: $table.skill, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get presentation => $composableBuilder(
    column: $table.presentation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get assistanceMask => $composableBuilder(
    column: $table.assistanceMask,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pairId =>
      $composableBuilder(column: $table.pairId, builder: (column) => column);

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioRefId => $composableBuilder(
    column: $table.audioRefId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get annotationHash => $composableBuilder(
    column: $table.annotationHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get annotationRevision => $composableBuilder(
    column: $table.annotationRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bucket =>
      $composableBuilder(column: $table.bucket, builder: (column) => column);

  GeneratedColumn<int> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  $$LearningScopesTableAnnotationComposer get scopeId {
    final $$LearningScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningSummariesTableTableManager
    extends
        RootTableManager<
          _$LearningDatabase,
          $LearningSummariesTable,
          LearningSummary,
          $$LearningSummariesTableFilterComposer,
          $$LearningSummariesTableOrderingComposer,
          $$LearningSummariesTableAnnotationComposer,
          $$LearningSummariesTableCreateCompanionBuilder,
          $$LearningSummariesTableUpdateCompanionBuilder,
          (LearningSummary, $$LearningSummariesTableReferences),
          LearningSummary,
          PrefetchHooks Function({bool scopeId})
        > {
  $$LearningSummariesTableTableManager(
    _$LearningDatabase db,
    $LearningSummariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningSummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningSummariesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> family = const Value.absent(),
                Value<String?> activityId = const Value.absent(),
                Value<String?> sound = const Value.absent(),
                Value<String?> skill = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> presentation = const Value.absent(),
                Value<int?> assistanceMask = const Value.absent(),
                Value<String?> pairId = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> sentenceId = const Value.absent(),
                Value<String?> audioRefId = const Value.absent(),
                Value<String?> annotationHash = const Value.absent(),
                Value<int?> annotationRevision = const Value.absent(),
                Value<int?> contentRevision = const Value.absent(),
                Value<String> bucket = const Value.absent(),
                Value<int> correct = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningSummariesCompanion(
                scopeId: scopeId,
                family: family,
                activityId: activityId,
                sound: sound,
                skill: skill,
                origin: origin,
                presentation: presentation,
                assistanceMask: assistanceMask,
                pairId: pairId,
                sectionId: sectionId,
                itemId: itemId,
                sentenceId: sentenceId,
                audioRefId: audioRefId,
                annotationHash: annotationHash,
                annotationRevision: annotationRevision,
                contentRevision: contentRevision,
                bucket: bucket,
                correct: correct,
                total: total,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String family,
                Value<String?> activityId = const Value.absent(),
                Value<String?> sound = const Value.absent(),
                Value<String?> skill = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> presentation = const Value.absent(),
                Value<int?> assistanceMask = const Value.absent(),
                Value<String?> pairId = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> sentenceId = const Value.absent(),
                Value<String?> audioRefId = const Value.absent(),
                Value<String?> annotationHash = const Value.absent(),
                Value<int?> annotationRevision = const Value.absent(),
                Value<int?> contentRevision = const Value.absent(),
                required String bucket,
                required int correct,
                required int total,
                Value<int> rowid = const Value.absent(),
              }) => LearningSummariesCompanion.insert(
                scopeId: scopeId,
                family: family,
                activityId: activityId,
                sound: sound,
                skill: skill,
                origin: origin,
                presentation: presentation,
                assistanceMask: assistanceMask,
                pairId: pairId,
                sectionId: sectionId,
                itemId: itemId,
                sentenceId: sentenceId,
                audioRefId: audioRefId,
                annotationHash: annotationHash,
                annotationRevision: annotationRevision,
                contentRevision: contentRevision,
                bucket: bucket,
                correct: correct,
                total: total,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LearningSummariesTable, LearningSummary>(table),
                  $$LearningSummariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$LearningSummariesTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$LearningSummariesTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningSummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabase,
      $LearningSummariesTable,
      LearningSummary,
      $$LearningSummariesTableFilterComposer,
      $$LearningSummariesTableOrderingComposer,
      $$LearningSummariesTableAnnotationComposer,
      $$LearningSummariesTableCreateCompanionBuilder,
      $$LearningSummariesTableUpdateCompanionBuilder,
      (LearningSummary, $$LearningSummariesTableReferences),
      LearningSummary,
      PrefetchHooks Function({bool scopeId})
    >;
typedef $$LearningCompletionsTableCreateCompanionBuilder =
    LearningCompletionsCompanion Function({
      required int scopeId,
      required String activityId,
      required int contentRevision,
      required String policyKind,
      required int policyRevision,
      required int thresholdPercent,
      required int committedAtUs,
      Value<int> rowid,
    });
typedef $$LearningCompletionsTableUpdateCompanionBuilder =
    LearningCompletionsCompanion Function({
      Value<int> scopeId,
      Value<String> activityId,
      Value<int> contentRevision,
      Value<String> policyKind,
      Value<int> policyRevision,
      Value<int> thresholdPercent,
      Value<int> committedAtUs,
      Value<int> rowid,
    });

final class $$LearningCompletionsTableReferences
    extends
        BaseReferences<
          _$LearningDatabase,
          $LearningCompletionsTable,
          LearningCompletion
        > {
  $$LearningCompletionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningScopesTable _scopeIdTable(_$LearningDatabase db) => db
      .learningScopes
      .createAlias('learning_completions__scope_id__learning_scopes__id');

  $$LearningScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$LearningScopesTableTableManager(
      $_db,
      $_db.learningScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningCompletionsTableFilterComposer
    extends Composer<_$LearningDatabase, $LearningCompletionsTable> {
  $$LearningCompletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get policyKind => $composableBuilder(
    column: $table.policyKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get policyRevision => $composableBuilder(
    column: $table.policyRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get thresholdPercent => $composableBuilder(
    column: $table.thresholdPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get committedAtUs => $composableBuilder(
    column: $table.committedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningScopesTableFilterComposer get scopeId {
    final $$LearningScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableFilterComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningCompletionsTableOrderingComposer
    extends Composer<_$LearningDatabase, $LearningCompletionsTable> {
  $$LearningCompletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get policyKind => $composableBuilder(
    column: $table.policyKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get policyRevision => $composableBuilder(
    column: $table.policyRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get thresholdPercent => $composableBuilder(
    column: $table.thresholdPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get committedAtUs => $composableBuilder(
    column: $table.committedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningScopesTableOrderingComposer get scopeId {
    final $$LearningScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableOrderingComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningCompletionsTableAnnotationComposer
    extends Composer<_$LearningDatabase, $LearningCompletionsTable> {
  $$LearningCompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get policyKind => $composableBuilder(
    column: $table.policyKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get policyRevision => $composableBuilder(
    column: $table.policyRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get thresholdPercent => $composableBuilder(
    column: $table.thresholdPercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get committedAtUs => $composableBuilder(
    column: $table.committedAtUs,
    builder: (column) => column,
  );

  $$LearningScopesTableAnnotationComposer get scopeId {
    final $$LearningScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningCompletionsTableTableManager
    extends
        RootTableManager<
          _$LearningDatabase,
          $LearningCompletionsTable,
          LearningCompletion,
          $$LearningCompletionsTableFilterComposer,
          $$LearningCompletionsTableOrderingComposer,
          $$LearningCompletionsTableAnnotationComposer,
          $$LearningCompletionsTableCreateCompanionBuilder,
          $$LearningCompletionsTableUpdateCompanionBuilder,
          (LearningCompletion, $$LearningCompletionsTableReferences),
          LearningCompletion,
          PrefetchHooks Function({bool scopeId})
        > {
  $$LearningCompletionsTableTableManager(
    _$LearningDatabase db,
    $LearningCompletionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningCompletionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningCompletionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LearningCompletionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<int> contentRevision = const Value.absent(),
                Value<String> policyKind = const Value.absent(),
                Value<int> policyRevision = const Value.absent(),
                Value<int> thresholdPercent = const Value.absent(),
                Value<int> committedAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningCompletionsCompanion(
                scopeId: scopeId,
                activityId: activityId,
                contentRevision: contentRevision,
                policyKind: policyKind,
                policyRevision: policyRevision,
                thresholdPercent: thresholdPercent,
                committedAtUs: committedAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String activityId,
                required int contentRevision,
                required String policyKind,
                required int policyRevision,
                required int thresholdPercent,
                required int committedAtUs,
                Value<int> rowid = const Value.absent(),
              }) => LearningCompletionsCompanion.insert(
                scopeId: scopeId,
                activityId: activityId,
                contentRevision: contentRevision,
                policyKind: policyKind,
                policyRevision: policyRevision,
                thresholdPercent: thresholdPercent,
                committedAtUs: committedAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LearningCompletionsTable, LearningCompletion>(
                    table,
                  ),
                  $$LearningCompletionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$LearningCompletionsTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$LearningCompletionsTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningCompletionsTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabase,
      $LearningCompletionsTable,
      LearningCompletion,
      $$LearningCompletionsTableFilterComposer,
      $$LearningCompletionsTableOrderingComposer,
      $$LearningCompletionsTableAnnotationComposer,
      $$LearningCompletionsTableCreateCompanionBuilder,
      $$LearningCompletionsTableUpdateCompanionBuilder,
      (LearningCompletion, $$LearningCompletionsTableReferences),
      LearningCompletion,
      PrefetchHooks Function({bool scopeId})
    >;
typedef $$LearningExposureTableCreateCompanionBuilder =
    LearningExposureCompanion Function({
      required int scopeId,
      required String family,
      Value<String?> activityId,
      Value<String?> itemId,
      Value<String?> targetSound,
      Value<String?> sectionId,
      Value<int?> contentRevision,
      Value<int?> presentations,
      Value<int?> assistanceMask,
      Value<int> rowid,
    });
typedef $$LearningExposureTableUpdateCompanionBuilder =
    LearningExposureCompanion Function({
      Value<int> scopeId,
      Value<String> family,
      Value<String?> activityId,
      Value<String?> itemId,
      Value<String?> targetSound,
      Value<String?> sectionId,
      Value<int?> contentRevision,
      Value<int?> presentations,
      Value<int?> assistanceMask,
      Value<int> rowid,
    });

final class $$LearningExposureTableReferences
    extends
        BaseReferences<
          _$LearningDatabase,
          $LearningExposureTable,
          LearningExposureData
        > {
  $$LearningExposureTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningScopesTable _scopeIdTable(_$LearningDatabase db) => db
      .learningScopes
      .createAlias('learning_exposure__scope_id__learning_scopes__id');

  $$LearningScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$LearningScopesTableTableManager(
      $_db,
      $_db.learningScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningExposureTableFilterComposer
    extends Composer<_$LearningDatabase, $LearningExposureTable> {
  $$LearningExposureTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetSound => $composableBuilder(
    column: $table.targetSound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get presentations => $composableBuilder(
    column: $table.presentations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get assistanceMask => $composableBuilder(
    column: $table.assistanceMask,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningScopesTableFilterComposer get scopeId {
    final $$LearningScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableFilterComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningExposureTableOrderingComposer
    extends Composer<_$LearningDatabase, $LearningExposureTable> {
  $$LearningExposureTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetSound => $composableBuilder(
    column: $table.targetSound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get presentations => $composableBuilder(
    column: $table.presentations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get assistanceMask => $composableBuilder(
    column: $table.assistanceMask,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningScopesTableOrderingComposer get scopeId {
    final $$LearningScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableOrderingComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningExposureTableAnnotationComposer
    extends Composer<_$LearningDatabase, $LearningExposureTable> {
  $$LearningExposureTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get family =>
      $composableBuilder(column: $table.family, builder: (column) => column);

  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get targetSound => $composableBuilder(
    column: $table.targetSound,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<int> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get presentations => $composableBuilder(
    column: $table.presentations,
    builder: (column) => column,
  );

  GeneratedColumn<int> get assistanceMask => $composableBuilder(
    column: $table.assistanceMask,
    builder: (column) => column,
  );

  $$LearningScopesTableAnnotationComposer get scopeId {
    final $$LearningScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningExposureTableTableManager
    extends
        RootTableManager<
          _$LearningDatabase,
          $LearningExposureTable,
          LearningExposureData,
          $$LearningExposureTableFilterComposer,
          $$LearningExposureTableOrderingComposer,
          $$LearningExposureTableAnnotationComposer,
          $$LearningExposureTableCreateCompanionBuilder,
          $$LearningExposureTableUpdateCompanionBuilder,
          (LearningExposureData, $$LearningExposureTableReferences),
          LearningExposureData,
          PrefetchHooks Function({bool scopeId})
        > {
  $$LearningExposureTableTableManager(
    _$LearningDatabase db,
    $LearningExposureTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningExposureTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningExposureTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningExposureTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> family = const Value.absent(),
                Value<String?> activityId = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> targetSound = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<int?> contentRevision = const Value.absent(),
                Value<int?> presentations = const Value.absent(),
                Value<int?> assistanceMask = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningExposureCompanion(
                scopeId: scopeId,
                family: family,
                activityId: activityId,
                itemId: itemId,
                targetSound: targetSound,
                sectionId: sectionId,
                contentRevision: contentRevision,
                presentations: presentations,
                assistanceMask: assistanceMask,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String family,
                Value<String?> activityId = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> targetSound = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<int?> contentRevision = const Value.absent(),
                Value<int?> presentations = const Value.absent(),
                Value<int?> assistanceMask = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningExposureCompanion.insert(
                scopeId: scopeId,
                family: family,
                activityId: activityId,
                itemId: itemId,
                targetSound: targetSound,
                sectionId: sectionId,
                contentRevision: contentRevision,
                presentations: presentations,
                assistanceMask: assistanceMask,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LearningExposureTable, LearningExposureData>(
                    table,
                  ),
                  $$LearningExposureTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$LearningExposureTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$LearningExposureTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningExposureTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabase,
      $LearningExposureTable,
      LearningExposureData,
      $$LearningExposureTableFilterComposer,
      $$LearningExposureTableOrderingComposer,
      $$LearningExposureTableAnnotationComposer,
      $$LearningExposureTableCreateCompanionBuilder,
      $$LearningExposureTableUpdateCompanionBuilder,
      (LearningExposureData, $$LearningExposureTableReferences),
      LearningExposureData,
      PrefetchHooks Function({bool scopeId})
    >;
typedef $$LearningBestScoresTableCreateCompanionBuilder =
    LearningBestScoresCompanion Function({
      required int scopeId,
      required String activityId,
      required int score,
      Value<int> rowid,
    });
typedef $$LearningBestScoresTableUpdateCompanionBuilder =
    LearningBestScoresCompanion Function({
      Value<int> scopeId,
      Value<String> activityId,
      Value<int> score,
      Value<int> rowid,
    });

final class $$LearningBestScoresTableReferences
    extends
        BaseReferences<
          _$LearningDatabase,
          $LearningBestScoresTable,
          LearningBestScore
        > {
  $$LearningBestScoresTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningScopesTable _scopeIdTable(_$LearningDatabase db) => db
      .learningScopes
      .createAlias('learning_best_scores__scope_id__learning_scopes__id');

  $$LearningScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$LearningScopesTableTableManager(
      $_db,
      $_db.learningScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningBestScoresTableFilterComposer
    extends Composer<_$LearningDatabase, $LearningBestScoresTable> {
  $$LearningBestScoresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningScopesTableFilterComposer get scopeId {
    final $$LearningScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableFilterComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningBestScoresTableOrderingComposer
    extends Composer<_$LearningDatabase, $LearningBestScoresTable> {
  $$LearningBestScoresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningScopesTableOrderingComposer get scopeId {
    final $$LearningScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableOrderingComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningBestScoresTableAnnotationComposer
    extends Composer<_$LearningDatabase, $LearningBestScoresTable> {
  $$LearningBestScoresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  $$LearningScopesTableAnnotationComposer get scopeId {
    final $$LearningScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningBestScoresTableTableManager
    extends
        RootTableManager<
          _$LearningDatabase,
          $LearningBestScoresTable,
          LearningBestScore,
          $$LearningBestScoresTableFilterComposer,
          $$LearningBestScoresTableOrderingComposer,
          $$LearningBestScoresTableAnnotationComposer,
          $$LearningBestScoresTableCreateCompanionBuilder,
          $$LearningBestScoresTableUpdateCompanionBuilder,
          (LearningBestScore, $$LearningBestScoresTableReferences),
          LearningBestScore,
          PrefetchHooks Function({bool scopeId})
        > {
  $$LearningBestScoresTableTableManager(
    _$LearningDatabase db,
    $LearningBestScoresTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningBestScoresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningBestScoresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningBestScoresTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningBestScoresCompanion(
                scopeId: scopeId,
                activityId: activityId,
                score: score,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String activityId,
                required int score,
                Value<int> rowid = const Value.absent(),
              }) => LearningBestScoresCompanion.insert(
                scopeId: scopeId,
                activityId: activityId,
                score: score,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LearningBestScoresTable, LearningBestScore>(
                    table,
                  ),
                  $$LearningBestScoresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$LearningBestScoresTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$LearningBestScoresTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningBestScoresTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabase,
      $LearningBestScoresTable,
      LearningBestScore,
      $$LearningBestScoresTableFilterComposer,
      $$LearningBestScoresTableOrderingComposer,
      $$LearningBestScoresTableAnnotationComposer,
      $$LearningBestScoresTableCreateCompanionBuilder,
      $$LearningBestScoresTableUpdateCompanionBuilder,
      (LearningBestScore, $$LearningBestScoresTableReferences),
      LearningBestScore,
      PrefetchHooks Function({bool scopeId})
    >;
typedef $$SupportedSyncOutboxTableCreateCompanionBuilder =
    SupportedSyncOutboxCompanion Function({
      required int scopeId,
      required String eventId,
      required int enqueueCommitOrdinal,
      required int enqueueEventIndex,
      required String userId,
      required String courseId,
      required String kind,
      Value<String?> sound,
      Value<String?> skill,
      Value<int?> correct,
      Value<String?> activity,
      Value<String?> lessonId,
      Value<String?> game,
      Value<int?> score,
      Value<int> rowid,
    });
typedef $$SupportedSyncOutboxTableUpdateCompanionBuilder =
    SupportedSyncOutboxCompanion Function({
      Value<int> scopeId,
      Value<String> eventId,
      Value<int> enqueueCommitOrdinal,
      Value<int> enqueueEventIndex,
      Value<String> userId,
      Value<String> courseId,
      Value<String> kind,
      Value<String?> sound,
      Value<String?> skill,
      Value<int?> correct,
      Value<String?> activity,
      Value<String?> lessonId,
      Value<String?> game,
      Value<int?> score,
      Value<int> rowid,
    });

final class $$SupportedSyncOutboxTableReferences
    extends
        BaseReferences<
          _$LearningDatabase,
          $SupportedSyncOutboxTable,
          SupportedSyncOutboxData
        > {
  $$SupportedSyncOutboxTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningScopesTable _scopeIdTable(_$LearningDatabase db) => db
      .learningScopes
      .createAlias('supported_sync_outbox__scope_id__learning_scopes__id');

  $$LearningScopesTableProcessedTableManager get scopeId {
    final $_column = $_itemColumn<int>('scope_id')!;

    final manager = $$LearningScopesTableTableManager(
      $_db,
      $_db.learningScopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SupportedSyncOutboxTableFilterComposer
    extends Composer<_$LearningDatabase, $SupportedSyncOutboxTable> {
  $$SupportedSyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enqueueCommitOrdinal => $composableBuilder(
    column: $table.enqueueCommitOrdinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enqueueEventIndex => $composableBuilder(
    column: $table.enqueueEventIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sound => $composableBuilder(
    column: $table.sound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skill => $composableBuilder(
    column: $table.skill,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activity => $composableBuilder(
    column: $table.activity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get game => $composableBuilder(
    column: $table.game,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningScopesTableFilterComposer get scopeId {
    final $$LearningScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableFilterComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SupportedSyncOutboxTableOrderingComposer
    extends Composer<_$LearningDatabase, $SupportedSyncOutboxTable> {
  $$SupportedSyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enqueueCommitOrdinal => $composableBuilder(
    column: $table.enqueueCommitOrdinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enqueueEventIndex => $composableBuilder(
    column: $table.enqueueEventIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sound => $composableBuilder(
    column: $table.sound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skill => $composableBuilder(
    column: $table.skill,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activity => $composableBuilder(
    column: $table.activity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get game => $composableBuilder(
    column: $table.game,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningScopesTableOrderingComposer get scopeId {
    final $$LearningScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableOrderingComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SupportedSyncOutboxTableAnnotationComposer
    extends Composer<_$LearningDatabase, $SupportedSyncOutboxTable> {
  $$SupportedSyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<int> get enqueueCommitOrdinal => $composableBuilder(
    column: $table.enqueueCommitOrdinal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get enqueueEventIndex => $composableBuilder(
    column: $table.enqueueEventIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get sound =>
      $composableBuilder(column: $table.sound, builder: (column) => column);

  GeneratedColumn<String> get skill =>
      $composableBuilder(column: $table.skill, builder: (column) => column);

  GeneratedColumn<int> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<String> get activity =>
      $composableBuilder(column: $table.activity, builder: (column) => column);

  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<String> get game =>
      $composableBuilder(column: $table.game, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  $$LearningScopesTableAnnotationComposer get scopeId {
    final $$LearningScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scopeId,
      referencedTable: $db.learningScopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SupportedSyncOutboxTableTableManager
    extends
        RootTableManager<
          _$LearningDatabase,
          $SupportedSyncOutboxTable,
          SupportedSyncOutboxData,
          $$SupportedSyncOutboxTableFilterComposer,
          $$SupportedSyncOutboxTableOrderingComposer,
          $$SupportedSyncOutboxTableAnnotationComposer,
          $$SupportedSyncOutboxTableCreateCompanionBuilder,
          $$SupportedSyncOutboxTableUpdateCompanionBuilder,
          (SupportedSyncOutboxData, $$SupportedSyncOutboxTableReferences),
          SupportedSyncOutboxData,
          PrefetchHooks Function({bool scopeId})
        > {
  $$SupportedSyncOutboxTableTableManager(
    _$LearningDatabase db,
    $SupportedSyncOutboxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SupportedSyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SupportedSyncOutboxTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SupportedSyncOutboxTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> scopeId = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<int> enqueueCommitOrdinal = const Value.absent(),
                Value<int> enqueueEventIndex = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> sound = const Value.absent(),
                Value<String?> skill = const Value.absent(),
                Value<int?> correct = const Value.absent(),
                Value<String?> activity = const Value.absent(),
                Value<String?> lessonId = const Value.absent(),
                Value<String?> game = const Value.absent(),
                Value<int?> score = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SupportedSyncOutboxCompanion(
                scopeId: scopeId,
                eventId: eventId,
                enqueueCommitOrdinal: enqueueCommitOrdinal,
                enqueueEventIndex: enqueueEventIndex,
                userId: userId,
                courseId: courseId,
                kind: kind,
                sound: sound,
                skill: skill,
                correct: correct,
                activity: activity,
                lessonId: lessonId,
                game: game,
                score: score,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int scopeId,
                required String eventId,
                required int enqueueCommitOrdinal,
                required int enqueueEventIndex,
                required String userId,
                required String courseId,
                required String kind,
                Value<String?> sound = const Value.absent(),
                Value<String?> skill = const Value.absent(),
                Value<int?> correct = const Value.absent(),
                Value<String?> activity = const Value.absent(),
                Value<String?> lessonId = const Value.absent(),
                Value<String?> game = const Value.absent(),
                Value<int?> score = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SupportedSyncOutboxCompanion.insert(
                scopeId: scopeId,
                eventId: eventId,
                enqueueCommitOrdinal: enqueueCommitOrdinal,
                enqueueEventIndex: enqueueEventIndex,
                userId: userId,
                courseId: courseId,
                kind: kind,
                sound: sound,
                skill: skill,
                correct: correct,
                activity: activity,
                lessonId: lessonId,
                game: game,
                score: score,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SupportedSyncOutboxTable,
                    SupportedSyncOutboxData
                  >(table),
                  $$SupportedSyncOutboxTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scopeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scopeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scopeId,
                                referencedTable:
                                    $$SupportedSyncOutboxTableReferences
                                        ._scopeIdTable(db),
                                referencedColumn:
                                    $$SupportedSyncOutboxTableReferences
                                        ._scopeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SupportedSyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabase,
      $SupportedSyncOutboxTable,
      SupportedSyncOutboxData,
      $$SupportedSyncOutboxTableFilterComposer,
      $$SupportedSyncOutboxTableOrderingComposer,
      $$SupportedSyncOutboxTableAnnotationComposer,
      $$SupportedSyncOutboxTableCreateCompanionBuilder,
      $$SupportedSyncOutboxTableUpdateCompanionBuilder,
      (SupportedSyncOutboxData, $$SupportedSyncOutboxTableReferences),
      SupportedSyncOutboxData,
      PrefetchHooks Function({bool scopeId})
    >;

class $LearningDatabaseManager {
  final _$LearningDatabase _db;
  $LearningDatabaseManager(this._db);
  $$LearningScopesTableTableManager get learningScopes =>
      $$LearningScopesTableTableManager(_db, _db.learningScopes);
  $$LearningContentBindingsTableTableManager get learningContentBindings =>
      $$LearningContentBindingsTableTableManager(
        _db,
        _db.learningContentBindings,
      );
  $$LearningRunsTableTableManager get learningRuns =>
      $$LearningRunsTableTableManager(_db, _db.learningRuns);
  $$LearningAttemptsTableTableManager get learningAttempts =>
      $$LearningAttemptsTableTableManager(_db, _db.learningAttempts);
  $$LearningAttemptValuesTableTableManager get learningAttemptValues =>
      $$LearningAttemptValuesTableTableManager(_db, _db.learningAttemptValues);
  $$LearningAttemptEvidenceTableTableManager get learningAttemptEvidence =>
      $$LearningAttemptEvidenceTableTableManager(
        _db,
        _db.learningAttemptEvidence,
      );
  $$LearningCommandReceiptsTableTableManager get learningCommandReceipts =>
      $$LearningCommandReceiptsTableTableManager(
        _db,
        _db.learningCommandReceipts,
      );
  $$LearningMistakesTableTableManager get learningMistakes =>
      $$LearningMistakesTableTableManager(_db, _db.learningMistakes);
  $$LearningSummariesTableTableManager get learningSummaries =>
      $$LearningSummariesTableTableManager(_db, _db.learningSummaries);
  $$LearningCompletionsTableTableManager get learningCompletions =>
      $$LearningCompletionsTableTableManager(_db, _db.learningCompletions);
  $$LearningExposureTableTableManager get learningExposure =>
      $$LearningExposureTableTableManager(_db, _db.learningExposure);
  $$LearningBestScoresTableTableManager get learningBestScores =>
      $$LearningBestScoresTableTableManager(_db, _db.learningBestScores);
  $$SupportedSyncOutboxTableTableManager get supportedSyncOutbox =>
      $$SupportedSyncOutboxTableTableManager(_db, _db.supportedSyncOutbox);
}

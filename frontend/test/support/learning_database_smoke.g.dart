// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_database_smoke.dart';

// ignore_for_file: type=lint
class $LearningDatabaseSmokeRowsTable extends LearningDatabaseSmokeRows
    with TableInfo<$LearningDatabaseSmokeRowsTable, LearningDatabaseSmokeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningDatabaseSmokeRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _probeKeyMeta = const VerificationMeta(
    'probeKey',
  );
  @override
  late final GeneratedColumn<String> probeKey = GeneratedColumn<String>(
    'probe_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _probeValueMeta = const VerificationMeta(
    'probeValue',
  );
  @override
  late final GeneratedColumn<String> probeValue = GeneratedColumn<String>(
    'probe_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [probeKey, probeValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_database_smoke_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningDatabaseSmokeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('probe_key')) {
      context.handle(
        _probeKeyMeta,
        probeKey.isAcceptableOrUnknown(data['probe_key']!, _probeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_probeKeyMeta);
    }
    if (data.containsKey('probe_value')) {
      context.handle(
        _probeValueMeta,
        probeValue.isAcceptableOrUnknown(data['probe_value']!, _probeValueMeta),
      );
    } else if (isInserting) {
      context.missing(_probeValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {probeKey};
  @override
  LearningDatabaseSmokeRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningDatabaseSmokeRow(
      probeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}probe_key'],
      )!,
      probeValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}probe_value'],
      )!,
    );
  }

  @override
  $LearningDatabaseSmokeRowsTable createAlias(String alias) {
    return $LearningDatabaseSmokeRowsTable(attachedDatabase, alias);
  }
}

class LearningDatabaseSmokeRow extends DataClass
    implements Insertable<LearningDatabaseSmokeRow> {
  final String probeKey;
  final String probeValue;
  const LearningDatabaseSmokeRow({
    required this.probeKey,
    required this.probeValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['probe_key'] = Variable<String>(probeKey);
    map['probe_value'] = Variable<String>(probeValue);
    return map;
  }

  LearningDatabaseSmokeRowsCompanion toCompanion(bool nullToAbsent) {
    return LearningDatabaseSmokeRowsCompanion(
      probeKey: Value(probeKey),
      probeValue: Value(probeValue),
    );
  }

  factory LearningDatabaseSmokeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningDatabaseSmokeRow(
      probeKey: serializer.fromJson<String>(json['probeKey']),
      probeValue: serializer.fromJson<String>(json['probeValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'probeKey': serializer.toJson<String>(probeKey),
      'probeValue': serializer.toJson<String>(probeValue),
    };
  }

  LearningDatabaseSmokeRow copyWith({String? probeKey, String? probeValue}) =>
      LearningDatabaseSmokeRow(
        probeKey: probeKey ?? this.probeKey,
        probeValue: probeValue ?? this.probeValue,
      );
  LearningDatabaseSmokeRow copyWithCompanion(
    LearningDatabaseSmokeRowsCompanion data,
  ) {
    return LearningDatabaseSmokeRow(
      probeKey: data.probeKey.present ? data.probeKey.value : this.probeKey,
      probeValue: data.probeValue.present
          ? data.probeValue.value
          : this.probeValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningDatabaseSmokeRow(')
          ..write('probeKey: $probeKey, ')
          ..write('probeValue: $probeValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(probeKey, probeValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningDatabaseSmokeRow &&
          other.probeKey == this.probeKey &&
          other.probeValue == this.probeValue);
}

class LearningDatabaseSmokeRowsCompanion
    extends UpdateCompanion<LearningDatabaseSmokeRow> {
  final Value<String> probeKey;
  final Value<String> probeValue;
  final Value<int> rowid;
  const LearningDatabaseSmokeRowsCompanion({
    this.probeKey = const Value.absent(),
    this.probeValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningDatabaseSmokeRowsCompanion.insert({
    required String probeKey,
    required String probeValue,
    this.rowid = const Value.absent(),
  }) : probeKey = Value(probeKey),
       probeValue = Value(probeValue);
  static Insertable<LearningDatabaseSmokeRow> custom({
    Expression<String>? probeKey,
    Expression<String>? probeValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (probeKey != null) 'probe_key': probeKey,
      if (probeValue != null) 'probe_value': probeValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningDatabaseSmokeRowsCompanion copyWith({
    Value<String>? probeKey,
    Value<String>? probeValue,
    Value<int>? rowid,
  }) {
    return LearningDatabaseSmokeRowsCompanion(
      probeKey: probeKey ?? this.probeKey,
      probeValue: probeValue ?? this.probeValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (probeKey.present) {
      map['probe_key'] = Variable<String>(probeKey.value);
    }
    if (probeValue.present) {
      map['probe_value'] = Variable<String>(probeValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningDatabaseSmokeRowsCompanion(')
          ..write('probeKey: $probeKey, ')
          ..write('probeValue: $probeValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LearningDatabaseSmoke extends GeneratedDatabase {
  _$LearningDatabaseSmoke(QueryExecutor e) : super(e);
  $LearningDatabaseSmokeManager get managers =>
      $LearningDatabaseSmokeManager(this);
  late final $LearningDatabaseSmokeRowsTable learningDatabaseSmokeRows =
      $LearningDatabaseSmokeRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    learningDatabaseSmokeRows,
  ];
}

typedef $$LearningDatabaseSmokeRowsTableCreateCompanionBuilder =
    LearningDatabaseSmokeRowsCompanion Function({
      required String probeKey,
      required String probeValue,
      Value<int> rowid,
    });
typedef $$LearningDatabaseSmokeRowsTableUpdateCompanionBuilder =
    LearningDatabaseSmokeRowsCompanion Function({
      Value<String> probeKey,
      Value<String> probeValue,
      Value<int> rowid,
    });

class $$LearningDatabaseSmokeRowsTableFilterComposer
    extends Composer<_$LearningDatabaseSmoke, $LearningDatabaseSmokeRowsTable> {
  $$LearningDatabaseSmokeRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get probeKey => $composableBuilder(
    column: $table.probeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get probeValue => $composableBuilder(
    column: $table.probeValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LearningDatabaseSmokeRowsTableOrderingComposer
    extends Composer<_$LearningDatabaseSmoke, $LearningDatabaseSmokeRowsTable> {
  $$LearningDatabaseSmokeRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get probeKey => $composableBuilder(
    column: $table.probeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get probeValue => $composableBuilder(
    column: $table.probeValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LearningDatabaseSmokeRowsTableAnnotationComposer
    extends Composer<_$LearningDatabaseSmoke, $LearningDatabaseSmokeRowsTable> {
  $$LearningDatabaseSmokeRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get probeKey =>
      $composableBuilder(column: $table.probeKey, builder: (column) => column);

  GeneratedColumn<String> get probeValue => $composableBuilder(
    column: $table.probeValue,
    builder: (column) => column,
  );
}

class $$LearningDatabaseSmokeRowsTableTableManager
    extends
        RootTableManager<
          _$LearningDatabaseSmoke,
          $LearningDatabaseSmokeRowsTable,
          LearningDatabaseSmokeRow,
          $$LearningDatabaseSmokeRowsTableFilterComposer,
          $$LearningDatabaseSmokeRowsTableOrderingComposer,
          $$LearningDatabaseSmokeRowsTableAnnotationComposer,
          $$LearningDatabaseSmokeRowsTableCreateCompanionBuilder,
          $$LearningDatabaseSmokeRowsTableUpdateCompanionBuilder,
          (
            LearningDatabaseSmokeRow,
            BaseReferences<
              _$LearningDatabaseSmoke,
              $LearningDatabaseSmokeRowsTable,
              LearningDatabaseSmokeRow
            >,
          ),
          LearningDatabaseSmokeRow,
          PrefetchHooks Function()
        > {
  $$LearningDatabaseSmokeRowsTableTableManager(
    _$LearningDatabaseSmoke db,
    $LearningDatabaseSmokeRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningDatabaseSmokeRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LearningDatabaseSmokeRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LearningDatabaseSmokeRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> probeKey = const Value.absent(),
                Value<String> probeValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningDatabaseSmokeRowsCompanion(
                probeKey: probeKey,
                probeValue: probeValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String probeKey,
                required String probeValue,
                Value<int> rowid = const Value.absent(),
              }) => LearningDatabaseSmokeRowsCompanion.insert(
                probeKey: probeKey,
                probeValue: probeValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LearningDatabaseSmokeRowsTable,
                    LearningDatabaseSmokeRow
                  >(table),
                  BaseReferences<
                    _$LearningDatabaseSmoke,
                    $LearningDatabaseSmokeRowsTable,
                    LearningDatabaseSmokeRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LearningDatabaseSmokeRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LearningDatabaseSmoke,
      $LearningDatabaseSmokeRowsTable,
      LearningDatabaseSmokeRow,
      $$LearningDatabaseSmokeRowsTableFilterComposer,
      $$LearningDatabaseSmokeRowsTableOrderingComposer,
      $$LearningDatabaseSmokeRowsTableAnnotationComposer,
      $$LearningDatabaseSmokeRowsTableCreateCompanionBuilder,
      $$LearningDatabaseSmokeRowsTableUpdateCompanionBuilder,
      (
        LearningDatabaseSmokeRow,
        BaseReferences<
          _$LearningDatabaseSmoke,
          $LearningDatabaseSmokeRowsTable,
          LearningDatabaseSmokeRow
        >,
      ),
      LearningDatabaseSmokeRow,
      PrefetchHooks Function()
    >;

class $LearningDatabaseSmokeManager {
  final _$LearningDatabaseSmoke _db;
  $LearningDatabaseSmokeManager(this._db);
  $$LearningDatabaseSmokeRowsTableTableManager get learningDatabaseSmokeRows =>
      $$LearningDatabaseSmokeRowsTableTableManager(
        _db,
        _db.learningDatabaseSmokeRows,
      );
}

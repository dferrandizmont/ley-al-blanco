// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $QuestionsTable extends Questions
    with TableInfo<$QuestionsTable, QuestionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _temaMeta = const VerificationMeta('tema');
  @override
  late final GeneratedColumn<int> tema = GeneratedColumn<int>(
    'tema',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionMeta = const VerificationMeta(
    'section',
  );
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
    'section',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stemMeta = const VerificationMeta('stem');
  @override
  late final GeneratedColumn<String> stem = GeneratedColumn<String>(
    'stem',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> options =
      GeneratedColumn<String>(
        'options',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<String>>($QuestionsTable.$converteroptions);
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<int> answer = GeneratedColumn<int>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _explanationMeta = const VerificationMeta(
    'explanation',
  );
  @override
  late final GeneratedColumn<String> explanation = GeneratedColumn<String>(
    'explanation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _articleMeta = const VerificationMeta(
    'article',
  );
  @override
  late final GeneratedColumn<String> article = GeneratedColumn<String>(
    'article',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> flags =
      GeneratedColumn<String>(
        'flags',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<String>>($QuestionsTable.$converterflags);
  static const VerificationMeta _editionMeta = const VerificationMeta(
    'edition',
  );
  @override
  late final GeneratedColumn<String> edition = GeneratedColumn<String>(
    'edition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewedMeta = const VerificationMeta(
    'reviewed',
  );
  @override
  late final GeneratedColumn<bool> reviewed = GeneratedColumn<bool>(
    'reviewed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reviewed" IN (0, 1))',
    ),
  );
  static const VerificationMeta _retiredMeta = const VerificationMeta(
    'retired',
  );
  @override
  late final GeneratedColumn<bool> retired = GeneratedColumn<bool>(
    'retired',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("retired" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noticeMeta = const VerificationMeta('notice');
  @override
  late final GeneratedColumn<String> notice = GeneratedColumn<String>(
    'notice',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tema,
    section,
    stem,
    options,
    answer,
    explanation,
    article,
    flags,
    edition,
    reviewed,
    retired,
    notice,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuestionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tema')) {
      context.handle(
        _temaMeta,
        tema.isAcceptableOrUnknown(data['tema']!, _temaMeta),
      );
    } else if (isInserting) {
      context.missing(_temaMeta);
    }
    if (data.containsKey('section')) {
      context.handle(
        _sectionMeta,
        section.isAcceptableOrUnknown(data['section']!, _sectionMeta),
      );
    }
    if (data.containsKey('stem')) {
      context.handle(
        _stemMeta,
        stem.isAcceptableOrUnknown(data['stem']!, _stemMeta),
      );
    } else if (isInserting) {
      context.missing(_stemMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('explanation')) {
      context.handle(
        _explanationMeta,
        explanation.isAcceptableOrUnknown(
          data['explanation']!,
          _explanationMeta,
        ),
      );
    }
    if (data.containsKey('article')) {
      context.handle(
        _articleMeta,
        article.isAcceptableOrUnknown(data['article']!, _articleMeta),
      );
    }
    if (data.containsKey('edition')) {
      context.handle(
        _editionMeta,
        edition.isAcceptableOrUnknown(data['edition']!, _editionMeta),
      );
    } else if (isInserting) {
      context.missing(_editionMeta);
    }
    if (data.containsKey('reviewed')) {
      context.handle(
        _reviewedMeta,
        reviewed.isAcceptableOrUnknown(data['reviewed']!, _reviewedMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewedMeta);
    }
    if (data.containsKey('retired')) {
      context.handle(
        _retiredMeta,
        retired.isAcceptableOrUnknown(data['retired']!, _retiredMeta),
      );
    }
    if (data.containsKey('notice')) {
      context.handle(
        _noticeMeta,
        notice.isAcceptableOrUnknown(data['notice']!, _noticeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuestionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuestionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tema: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tema'],
      )!,
      section: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section'],
      ),
      stem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stem'],
      )!,
      options: $QuestionsTable.$converteroptions.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}options'],
        )!,
      ),
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}answer'],
      )!,
      explanation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation'],
      ),
      article: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article'],
      ),
      flags: $QuestionsTable.$converterflags.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}flags'],
        )!,
      ),
      edition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edition'],
      )!,
      reviewed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reviewed'],
      )!,
      retired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}retired'],
      )!,
      notice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notice'],
      ),
    );
  }

  @override
  $QuestionsTable createAlias(String alias) {
    return $QuestionsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converteroptions =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterflags =
      const StringListConverter();
}

class QuestionRow extends DataClass implements Insertable<QuestionRow> {
  /// Stable across editions, e.g. `t2-017`.
  final String id;
  final int tema;
  final String? section;
  final String stem;

  /// JSON array, questionnaire order (never shuffled).
  final List<String> options;
  final int answer;
  final String? explanation;
  final String? article;

  /// JSON array.
  final List<String> flags;
  final String edition;
  final bool reviewed;

  /// True once the question is no longer in the current edition.
  final bool retired;

  /// Our legal-reform notice, shown above the explanation (schema v3, so it
  /// sits last: an upgraded database appends the column). Null until the
  /// bank is re-imported.
  final String? notice;
  const QuestionRow({
    required this.id,
    required this.tema,
    this.section,
    required this.stem,
    required this.options,
    required this.answer,
    this.explanation,
    this.article,
    required this.flags,
    required this.edition,
    required this.reviewed,
    required this.retired,
    this.notice,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tema'] = Variable<int>(tema);
    if (!nullToAbsent || section != null) {
      map['section'] = Variable<String>(section);
    }
    map['stem'] = Variable<String>(stem);
    {
      map['options'] = Variable<String>(
        $QuestionsTable.$converteroptions.toSql(options),
      );
    }
    map['answer'] = Variable<int>(answer);
    if (!nullToAbsent || explanation != null) {
      map['explanation'] = Variable<String>(explanation);
    }
    if (!nullToAbsent || article != null) {
      map['article'] = Variable<String>(article);
    }
    {
      map['flags'] = Variable<String>(
        $QuestionsTable.$converterflags.toSql(flags),
      );
    }
    map['edition'] = Variable<String>(edition);
    map['reviewed'] = Variable<bool>(reviewed);
    map['retired'] = Variable<bool>(retired);
    if (!nullToAbsent || notice != null) {
      map['notice'] = Variable<String>(notice);
    }
    return map;
  }

  QuestionsCompanion toCompanion(bool nullToAbsent) {
    return QuestionsCompanion(
      id: Value(id),
      tema: Value(tema),
      section: section == null && nullToAbsent
          ? const Value.absent()
          : Value(section),
      stem: Value(stem),
      options: Value(options),
      answer: Value(answer),
      explanation: explanation == null && nullToAbsent
          ? const Value.absent()
          : Value(explanation),
      article: article == null && nullToAbsent
          ? const Value.absent()
          : Value(article),
      flags: Value(flags),
      edition: Value(edition),
      reviewed: Value(reviewed),
      retired: Value(retired),
      notice: notice == null && nullToAbsent
          ? const Value.absent()
          : Value(notice),
    );
  }

  factory QuestionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuestionRow(
      id: serializer.fromJson<String>(json['id']),
      tema: serializer.fromJson<int>(json['tema']),
      section: serializer.fromJson<String?>(json['section']),
      stem: serializer.fromJson<String>(json['stem']),
      options: serializer.fromJson<List<String>>(json['options']),
      answer: serializer.fromJson<int>(json['answer']),
      explanation: serializer.fromJson<String?>(json['explanation']),
      article: serializer.fromJson<String?>(json['article']),
      flags: serializer.fromJson<List<String>>(json['flags']),
      edition: serializer.fromJson<String>(json['edition']),
      reviewed: serializer.fromJson<bool>(json['reviewed']),
      retired: serializer.fromJson<bool>(json['retired']),
      notice: serializer.fromJson<String?>(json['notice']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tema': serializer.toJson<int>(tema),
      'section': serializer.toJson<String?>(section),
      'stem': serializer.toJson<String>(stem),
      'options': serializer.toJson<List<String>>(options),
      'answer': serializer.toJson<int>(answer),
      'explanation': serializer.toJson<String?>(explanation),
      'article': serializer.toJson<String?>(article),
      'flags': serializer.toJson<List<String>>(flags),
      'edition': serializer.toJson<String>(edition),
      'reviewed': serializer.toJson<bool>(reviewed),
      'retired': serializer.toJson<bool>(retired),
      'notice': serializer.toJson<String?>(notice),
    };
  }

  QuestionRow copyWith({
    String? id,
    int? tema,
    Value<String?> section = const Value.absent(),
    String? stem,
    List<String>? options,
    int? answer,
    Value<String?> explanation = const Value.absent(),
    Value<String?> article = const Value.absent(),
    List<String>? flags,
    String? edition,
    bool? reviewed,
    bool? retired,
    Value<String?> notice = const Value.absent(),
  }) => QuestionRow(
    id: id ?? this.id,
    tema: tema ?? this.tema,
    section: section.present ? section.value : this.section,
    stem: stem ?? this.stem,
    options: options ?? this.options,
    answer: answer ?? this.answer,
    explanation: explanation.present ? explanation.value : this.explanation,
    article: article.present ? article.value : this.article,
    flags: flags ?? this.flags,
    edition: edition ?? this.edition,
    reviewed: reviewed ?? this.reviewed,
    retired: retired ?? this.retired,
    notice: notice.present ? notice.value : this.notice,
  );
  QuestionRow copyWithCompanion(QuestionsCompanion data) {
    return QuestionRow(
      id: data.id.present ? data.id.value : this.id,
      tema: data.tema.present ? data.tema.value : this.tema,
      section: data.section.present ? data.section.value : this.section,
      stem: data.stem.present ? data.stem.value : this.stem,
      options: data.options.present ? data.options.value : this.options,
      answer: data.answer.present ? data.answer.value : this.answer,
      explanation: data.explanation.present
          ? data.explanation.value
          : this.explanation,
      article: data.article.present ? data.article.value : this.article,
      flags: data.flags.present ? data.flags.value : this.flags,
      edition: data.edition.present ? data.edition.value : this.edition,
      reviewed: data.reviewed.present ? data.reviewed.value : this.reviewed,
      retired: data.retired.present ? data.retired.value : this.retired,
      notice: data.notice.present ? data.notice.value : this.notice,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuestionRow(')
          ..write('id: $id, ')
          ..write('tema: $tema, ')
          ..write('section: $section, ')
          ..write('stem: $stem, ')
          ..write('options: $options, ')
          ..write('answer: $answer, ')
          ..write('explanation: $explanation, ')
          ..write('article: $article, ')
          ..write('flags: $flags, ')
          ..write('edition: $edition, ')
          ..write('reviewed: $reviewed, ')
          ..write('retired: $retired, ')
          ..write('notice: $notice')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tema,
    section,
    stem,
    options,
    answer,
    explanation,
    article,
    flags,
    edition,
    reviewed,
    retired,
    notice,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionRow &&
          other.id == this.id &&
          other.tema == this.tema &&
          other.section == this.section &&
          other.stem == this.stem &&
          other.options == this.options &&
          other.answer == this.answer &&
          other.explanation == this.explanation &&
          other.article == this.article &&
          other.flags == this.flags &&
          other.edition == this.edition &&
          other.reviewed == this.reviewed &&
          other.retired == this.retired &&
          other.notice == this.notice);
}

class QuestionsCompanion extends UpdateCompanion<QuestionRow> {
  final Value<String> id;
  final Value<int> tema;
  final Value<String?> section;
  final Value<String> stem;
  final Value<List<String>> options;
  final Value<int> answer;
  final Value<String?> explanation;
  final Value<String?> article;
  final Value<List<String>> flags;
  final Value<String> edition;
  final Value<bool> reviewed;
  final Value<bool> retired;
  final Value<String?> notice;
  final Value<int> rowid;
  const QuestionsCompanion({
    this.id = const Value.absent(),
    this.tema = const Value.absent(),
    this.section = const Value.absent(),
    this.stem = const Value.absent(),
    this.options = const Value.absent(),
    this.answer = const Value.absent(),
    this.explanation = const Value.absent(),
    this.article = const Value.absent(),
    this.flags = const Value.absent(),
    this.edition = const Value.absent(),
    this.reviewed = const Value.absent(),
    this.retired = const Value.absent(),
    this.notice = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuestionsCompanion.insert({
    required String id,
    required int tema,
    this.section = const Value.absent(),
    required String stem,
    required List<String> options,
    required int answer,
    this.explanation = const Value.absent(),
    this.article = const Value.absent(),
    required List<String> flags,
    required String edition,
    required bool reviewed,
    this.retired = const Value.absent(),
    this.notice = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tema = Value(tema),
       stem = Value(stem),
       options = Value(options),
       answer = Value(answer),
       flags = Value(flags),
       edition = Value(edition),
       reviewed = Value(reviewed);
  static Insertable<QuestionRow> custom({
    Expression<String>? id,
    Expression<int>? tema,
    Expression<String>? section,
    Expression<String>? stem,
    Expression<String>? options,
    Expression<int>? answer,
    Expression<String>? explanation,
    Expression<String>? article,
    Expression<String>? flags,
    Expression<String>? edition,
    Expression<bool>? reviewed,
    Expression<bool>? retired,
    Expression<String>? notice,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tema != null) 'tema': tema,
      if (section != null) 'section': section,
      if (stem != null) 'stem': stem,
      if (options != null) 'options': options,
      if (answer != null) 'answer': answer,
      if (explanation != null) 'explanation': explanation,
      if (article != null) 'article': article,
      if (flags != null) 'flags': flags,
      if (edition != null) 'edition': edition,
      if (reviewed != null) 'reviewed': reviewed,
      if (retired != null) 'retired': retired,
      if (notice != null) 'notice': notice,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuestionsCompanion copyWith({
    Value<String>? id,
    Value<int>? tema,
    Value<String?>? section,
    Value<String>? stem,
    Value<List<String>>? options,
    Value<int>? answer,
    Value<String?>? explanation,
    Value<String?>? article,
    Value<List<String>>? flags,
    Value<String>? edition,
    Value<bool>? reviewed,
    Value<bool>? retired,
    Value<String?>? notice,
    Value<int>? rowid,
  }) {
    return QuestionsCompanion(
      id: id ?? this.id,
      tema: tema ?? this.tema,
      section: section ?? this.section,
      stem: stem ?? this.stem,
      options: options ?? this.options,
      answer: answer ?? this.answer,
      explanation: explanation ?? this.explanation,
      article: article ?? this.article,
      flags: flags ?? this.flags,
      edition: edition ?? this.edition,
      reviewed: reviewed ?? this.reviewed,
      retired: retired ?? this.retired,
      notice: notice ?? this.notice,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tema.present) {
      map['tema'] = Variable<int>(tema.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (stem.present) {
      map['stem'] = Variable<String>(stem.value);
    }
    if (options.present) {
      map['options'] = Variable<String>(
        $QuestionsTable.$converteroptions.toSql(options.value),
      );
    }
    if (answer.present) {
      map['answer'] = Variable<int>(answer.value);
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (article.present) {
      map['article'] = Variable<String>(article.value);
    }
    if (flags.present) {
      map['flags'] = Variable<String>(
        $QuestionsTable.$converterflags.toSql(flags.value),
      );
    }
    if (edition.present) {
      map['edition'] = Variable<String>(edition.value);
    }
    if (reviewed.present) {
      map['reviewed'] = Variable<bool>(reviewed.value);
    }
    if (retired.present) {
      map['retired'] = Variable<bool>(retired.value);
    }
    if (notice.present) {
      map['notice'] = Variable<String>(notice.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuestionsCompanion(')
          ..write('id: $id, ')
          ..write('tema: $tema, ')
          ..write('section: $section, ')
          ..write('stem: $stem, ')
          ..write('options: $options, ')
          ..write('answer: $answer, ')
          ..write('explanation: $explanation, ')
          ..write('article: $article, ')
          ..write('flags: $flags, ')
          ..write('edition: $edition, ')
          ..write('reviewed: $reviewed, ')
          ..write('retired: $retired, ')
          ..write('notice: $notice, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttemptsTable extends Attempts
    with TableInfo<$AttemptsTable, AttemptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AttemptMode, String> mode =
      GeneratedColumn<String>(
        'mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AttemptMode>($AttemptsTable.$convertermode);
  static const VerificationMeta _selectedMeta = const VerificationMeta(
    'selected',
  );
  @override
  late final GeneratedColumn<int> selected = GeneratedColumn<int>(
    'selected',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<bool> correct = GeneratedColumn<bool>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("correct" IN (0, 1))',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> answeredAt =
      GeneratedColumn<DateTime>(
        'answered_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AttemptsTable.$converteransweredAt);
  static const VerificationMeta _mockIdMeta = const VerificationMeta('mockId');
  @override
  late final GeneratedColumn<int> mockId = GeneratedColumn<int>(
    'mock_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elapsedMsMeta = const VerificationMeta(
    'elapsedMs',
  );
  @override
  late final GeneratedColumn<int> elapsedMs = GeneratedColumn<int>(
    'elapsed_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    questionId,
    mode,
    selected,
    correct,
    answeredAt,
    mockId,
    elapsedMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttemptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('selected')) {
      context.handle(
        _selectedMeta,
        selected.isAcceptableOrUnknown(data['selected']!, _selectedMeta),
      );
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('mock_id')) {
      context.handle(
        _mockIdMeta,
        mockId.isAcceptableOrUnknown(data['mock_id']!, _mockIdMeta),
      );
    }
    if (data.containsKey('elapsed_ms')) {
      context.handle(
        _elapsedMsMeta,
        elapsedMs.isAcceptableOrUnknown(data['elapsed_ms']!, _elapsedMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttemptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttemptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      mode: $AttemptsTable.$convertermode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}mode'],
        )!,
      ),
      selected: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}selected'],
      ),
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}correct'],
      )!,
      answeredAt: $AttemptsTable.$converteransweredAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}answered_at'],
        )!,
      ),
      mockId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mock_id'],
      ),
      elapsedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_ms'],
      ),
    );
  }

  @override
  $AttemptsTable createAlias(String alias) {
    return $AttemptsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AttemptMode, String, String> $convertermode =
      const EnumNameConverter<AttemptMode>(AttemptMode.values);
  static TypeConverter<DateTime, DateTime> $converteransweredAt =
      const LocalUtcDateTimeConverter();
}

class AttemptRow extends DataClass implements Insertable<AttemptRow> {
  final int id;
  final String questionId;
  final AttemptMode mode;

  /// 0-based option; null = left blank in a mock.
  final int? selected;
  final bool correct;
  final DateTime answeredAt;
  final int? mockId;
  final int? elapsedMs;
  const AttemptRow({
    required this.id,
    required this.questionId,
    required this.mode,
    this.selected,
    required this.correct,
    required this.answeredAt,
    this.mockId,
    this.elapsedMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['question_id'] = Variable<String>(questionId);
    {
      map['mode'] = Variable<String>($AttemptsTable.$convertermode.toSql(mode));
    }
    if (!nullToAbsent || selected != null) {
      map['selected'] = Variable<int>(selected);
    }
    map['correct'] = Variable<bool>(correct);
    {
      map['answered_at'] = Variable<DateTime>(
        $AttemptsTable.$converteransweredAt.toSql(answeredAt),
      );
    }
    if (!nullToAbsent || mockId != null) {
      map['mock_id'] = Variable<int>(mockId);
    }
    if (!nullToAbsent || elapsedMs != null) {
      map['elapsed_ms'] = Variable<int>(elapsedMs);
    }
    return map;
  }

  AttemptsCompanion toCompanion(bool nullToAbsent) {
    return AttemptsCompanion(
      id: Value(id),
      questionId: Value(questionId),
      mode: Value(mode),
      selected: selected == null && nullToAbsent
          ? const Value.absent()
          : Value(selected),
      correct: Value(correct),
      answeredAt: Value(answeredAt),
      mockId: mockId == null && nullToAbsent
          ? const Value.absent()
          : Value(mockId),
      elapsedMs: elapsedMs == null && nullToAbsent
          ? const Value.absent()
          : Value(elapsedMs),
    );
  }

  factory AttemptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttemptRow(
      id: serializer.fromJson<int>(json['id']),
      questionId: serializer.fromJson<String>(json['questionId']),
      mode: $AttemptsTable.$convertermode.fromJson(
        serializer.fromJson<String>(json['mode']),
      ),
      selected: serializer.fromJson<int?>(json['selected']),
      correct: serializer.fromJson<bool>(json['correct']),
      answeredAt: serializer.fromJson<DateTime>(json['answeredAt']),
      mockId: serializer.fromJson<int?>(json['mockId']),
      elapsedMs: serializer.fromJson<int?>(json['elapsedMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'questionId': serializer.toJson<String>(questionId),
      'mode': serializer.toJson<String>(
        $AttemptsTable.$convertermode.toJson(mode),
      ),
      'selected': serializer.toJson<int?>(selected),
      'correct': serializer.toJson<bool>(correct),
      'answeredAt': serializer.toJson<DateTime>(answeredAt),
      'mockId': serializer.toJson<int?>(mockId),
      'elapsedMs': serializer.toJson<int?>(elapsedMs),
    };
  }

  AttemptRow copyWith({
    int? id,
    String? questionId,
    AttemptMode? mode,
    Value<int?> selected = const Value.absent(),
    bool? correct,
    DateTime? answeredAt,
    Value<int?> mockId = const Value.absent(),
    Value<int?> elapsedMs = const Value.absent(),
  }) => AttemptRow(
    id: id ?? this.id,
    questionId: questionId ?? this.questionId,
    mode: mode ?? this.mode,
    selected: selected.present ? selected.value : this.selected,
    correct: correct ?? this.correct,
    answeredAt: answeredAt ?? this.answeredAt,
    mockId: mockId.present ? mockId.value : this.mockId,
    elapsedMs: elapsedMs.present ? elapsedMs.value : this.elapsedMs,
  );
  AttemptRow copyWithCompanion(AttemptsCompanion data) {
    return AttemptRow(
      id: data.id.present ? data.id.value : this.id,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      mode: data.mode.present ? data.mode.value : this.mode,
      selected: data.selected.present ? data.selected.value : this.selected,
      correct: data.correct.present ? data.correct.value : this.correct,
      answeredAt: data.answeredAt.present
          ? data.answeredAt.value
          : this.answeredAt,
      mockId: data.mockId.present ? data.mockId.value : this.mockId,
      elapsedMs: data.elapsedMs.present ? data.elapsedMs.value : this.elapsedMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttemptRow(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('mode: $mode, ')
          ..write('selected: $selected, ')
          ..write('correct: $correct, ')
          ..write('answeredAt: $answeredAt, ')
          ..write('mockId: $mockId, ')
          ..write('elapsedMs: $elapsedMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    questionId,
    mode,
    selected,
    correct,
    answeredAt,
    mockId,
    elapsedMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttemptRow &&
          other.id == this.id &&
          other.questionId == this.questionId &&
          other.mode == this.mode &&
          other.selected == this.selected &&
          other.correct == this.correct &&
          other.answeredAt == this.answeredAt &&
          other.mockId == this.mockId &&
          other.elapsedMs == this.elapsedMs);
}

class AttemptsCompanion extends UpdateCompanion<AttemptRow> {
  final Value<int> id;
  final Value<String> questionId;
  final Value<AttemptMode> mode;
  final Value<int?> selected;
  final Value<bool> correct;
  final Value<DateTime> answeredAt;
  final Value<int?> mockId;
  final Value<int?> elapsedMs;
  const AttemptsCompanion({
    this.id = const Value.absent(),
    this.questionId = const Value.absent(),
    this.mode = const Value.absent(),
    this.selected = const Value.absent(),
    this.correct = const Value.absent(),
    this.answeredAt = const Value.absent(),
    this.mockId = const Value.absent(),
    this.elapsedMs = const Value.absent(),
  });
  AttemptsCompanion.insert({
    this.id = const Value.absent(),
    required String questionId,
    required AttemptMode mode,
    this.selected = const Value.absent(),
    required bool correct,
    required DateTime answeredAt,
    this.mockId = const Value.absent(),
    this.elapsedMs = const Value.absent(),
  }) : questionId = Value(questionId),
       mode = Value(mode),
       correct = Value(correct),
       answeredAt = Value(answeredAt);
  static Insertable<AttemptRow> custom({
    Expression<int>? id,
    Expression<String>? questionId,
    Expression<String>? mode,
    Expression<int>? selected,
    Expression<bool>? correct,
    Expression<DateTime>? answeredAt,
    Expression<int>? mockId,
    Expression<int>? elapsedMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (questionId != null) 'question_id': questionId,
      if (mode != null) 'mode': mode,
      if (selected != null) 'selected': selected,
      if (correct != null) 'correct': correct,
      if (answeredAt != null) 'answered_at': answeredAt,
      if (mockId != null) 'mock_id': mockId,
      if (elapsedMs != null) 'elapsed_ms': elapsedMs,
    });
  }

  AttemptsCompanion copyWith({
    Value<int>? id,
    Value<String>? questionId,
    Value<AttemptMode>? mode,
    Value<int?>? selected,
    Value<bool>? correct,
    Value<DateTime>? answeredAt,
    Value<int?>? mockId,
    Value<int?>? elapsedMs,
  }) {
    return AttemptsCompanion(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      mode: mode ?? this.mode,
      selected: selected ?? this.selected,
      correct: correct ?? this.correct,
      answeredAt: answeredAt ?? this.answeredAt,
      mockId: mockId ?? this.mockId,
      elapsedMs: elapsedMs ?? this.elapsedMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(
        $AttemptsTable.$convertermode.toSql(mode.value),
      );
    }
    if (selected.present) {
      map['selected'] = Variable<int>(selected.value);
    }
    if (correct.present) {
      map['correct'] = Variable<bool>(correct.value);
    }
    if (answeredAt.present) {
      map['answered_at'] = Variable<DateTime>(
        $AttemptsTable.$converteransweredAt.toSql(answeredAt.value),
      );
    }
    if (mockId.present) {
      map['mock_id'] = Variable<int>(mockId.value);
    }
    if (elapsedMs.present) {
      map['elapsed_ms'] = Variable<int>(elapsedMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttemptsCompanion(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('mode: $mode, ')
          ..write('selected: $selected, ')
          ..write('correct: $correct, ')
          ..write('answeredAt: $answeredAt, ')
          ..write('mockId: $mockId, ')
          ..write('elapsedMs: $elapsedMs')
          ..write(')'))
        .toString();
  }
}

class $SrsStateTable extends SrsState
    with TableInfo<$SrsStateTable, SrsStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SrsStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boxMeta = const VerificationMeta('box');
  @override
  late final GeneratedColumn<int> box = GeneratedColumn<int>(
    'box',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> dueAt =
      GeneratedColumn<DateTime>(
        'due_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SrsStateTable.$converterdueAt);
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, DateTime>
  lastAnsweredAt = GeneratedColumn<DateTime>(
    'last_answered_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  ).withConverter<DateTime?>($SrsStateTable.$converterlastAnsweredAtn);
  @override
  List<GeneratedColumn> get $columns => [
    questionId,
    box,
    dueAt,
    reps,
    lapses,
    lastAnsweredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'srs_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SrsStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('box')) {
      context.handle(
        _boxMeta,
        box.isAcceptableOrUnknown(data['box']!, _boxMeta),
      );
    } else if (isInserting) {
      context.missing(_boxMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    } else if (isInserting) {
      context.missing(_repsMeta);
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    } else if (isInserting) {
      context.missing(_lapsesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {questionId};
  @override
  SrsStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SrsStateRow(
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      box: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}box'],
      )!,
      dueAt: $SrsStateTable.$converterdueAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}due_at'],
        )!,
      ),
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
      lastAnsweredAt: $SrsStateTable.$converterlastAnsweredAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}last_answered_at'],
        ),
      ),
    );
  }

  @override
  $SrsStateTable createAlias(String alias) {
    return $SrsStateTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $converterdueAt =
      const LocalUtcDateTimeConverter();
  static TypeConverter<DateTime, DateTime> $converterlastAnsweredAt =
      const LocalUtcDateTimeConverter();
  static TypeConverter<DateTime?, DateTime?> $converterlastAnsweredAtn =
      NullAwareTypeConverter.wrap($converterlastAnsweredAt);
}

class SrsStateRow extends DataClass implements Insertable<SrsStateRow> {
  final String questionId;
  final int box;
  final DateTime dueAt;
  final int reps;
  final int lapses;
  final DateTime? lastAnsweredAt;
  const SrsStateRow({
    required this.questionId,
    required this.box,
    required this.dueAt,
    required this.reps,
    required this.lapses,
    this.lastAnsweredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['question_id'] = Variable<String>(questionId);
    map['box'] = Variable<int>(box);
    {
      map['due_at'] = Variable<DateTime>(
        $SrsStateTable.$converterdueAt.toSql(dueAt),
      );
    }
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    if (!nullToAbsent || lastAnsweredAt != null) {
      map['last_answered_at'] = Variable<DateTime>(
        $SrsStateTable.$converterlastAnsweredAtn.toSql(lastAnsweredAt),
      );
    }
    return map;
  }

  SrsStateCompanion toCompanion(bool nullToAbsent) {
    return SrsStateCompanion(
      questionId: Value(questionId),
      box: Value(box),
      dueAt: Value(dueAt),
      reps: Value(reps),
      lapses: Value(lapses),
      lastAnsweredAt: lastAnsweredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAnsweredAt),
    );
  }

  factory SrsStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SrsStateRow(
      questionId: serializer.fromJson<String>(json['questionId']),
      box: serializer.fromJson<int>(json['box']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
      lastAnsweredAt: serializer.fromJson<DateTime?>(json['lastAnsweredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'questionId': serializer.toJson<String>(questionId),
      'box': serializer.toJson<int>(box),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
      'lastAnsweredAt': serializer.toJson<DateTime?>(lastAnsweredAt),
    };
  }

  SrsStateRow copyWith({
    String? questionId,
    int? box,
    DateTime? dueAt,
    int? reps,
    int? lapses,
    Value<DateTime?> lastAnsweredAt = const Value.absent(),
  }) => SrsStateRow(
    questionId: questionId ?? this.questionId,
    box: box ?? this.box,
    dueAt: dueAt ?? this.dueAt,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    lastAnsweredAt: lastAnsweredAt.present
        ? lastAnsweredAt.value
        : this.lastAnsweredAt,
  );
  SrsStateRow copyWithCompanion(SrsStateCompanion data) {
    return SrsStateRow(
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      box: data.box.present ? data.box.value : this.box,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      lastAnsweredAt: data.lastAnsweredAt.present
          ? data.lastAnsweredAt.value
          : this.lastAnsweredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SrsStateRow(')
          ..write('questionId: $questionId, ')
          ..write('box: $box, ')
          ..write('dueAt: $dueAt, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastAnsweredAt: $lastAnsweredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(questionId, box, dueAt, reps, lapses, lastAnsweredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SrsStateRow &&
          other.questionId == this.questionId &&
          other.box == this.box &&
          other.dueAt == this.dueAt &&
          other.reps == this.reps &&
          other.lapses == this.lapses &&
          other.lastAnsweredAt == this.lastAnsweredAt);
}

class SrsStateCompanion extends UpdateCompanion<SrsStateRow> {
  final Value<String> questionId;
  final Value<int> box;
  final Value<DateTime> dueAt;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<DateTime?> lastAnsweredAt;
  final Value<int> rowid;
  const SrsStateCompanion({
    this.questionId = const Value.absent(),
    this.box = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.lastAnsweredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SrsStateCompanion.insert({
    required String questionId,
    required int box,
    required DateTime dueAt,
    required int reps,
    required int lapses,
    this.lastAnsweredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : questionId = Value(questionId),
       box = Value(box),
       dueAt = Value(dueAt),
       reps = Value(reps),
       lapses = Value(lapses);
  static Insertable<SrsStateRow> custom({
    Expression<String>? questionId,
    Expression<int>? box,
    Expression<DateTime>? dueAt,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<DateTime>? lastAnsweredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (questionId != null) 'question_id': questionId,
      if (box != null) 'box': box,
      if (dueAt != null) 'due_at': dueAt,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (lastAnsweredAt != null) 'last_answered_at': lastAnsweredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SrsStateCompanion copyWith({
    Value<String>? questionId,
    Value<int>? box,
    Value<DateTime>? dueAt,
    Value<int>? reps,
    Value<int>? lapses,
    Value<DateTime?>? lastAnsweredAt,
    Value<int>? rowid,
  }) {
    return SrsStateCompanion(
      questionId: questionId ?? this.questionId,
      box: box ?? this.box,
      dueAt: dueAt ?? this.dueAt,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      lastAnsweredAt: lastAnsweredAt ?? this.lastAnsweredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (box.present) {
      map['box'] = Variable<int>(box.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(
        $SrsStateTable.$converterdueAt.toSql(dueAt.value),
      );
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (lastAnsweredAt.present) {
      map['last_answered_at'] = Variable<DateTime>(
        $SrsStateTable.$converterlastAnsweredAtn.toSql(lastAnsweredAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SrsStateCompanion(')
          ..write('questionId: $questionId, ')
          ..write('box: $box, ')
          ..write('dueAt: $dueAt, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastAnsweredAt: $lastAnsweredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MocksTable extends Mocks with TableInfo<$MocksTable, MockRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> startedAt =
      GeneratedColumn<DateTime>(
        'started_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($MocksTable.$converterstartedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, DateTime> finishedAt =
      GeneratedColumn<DateTime>(
        'finished_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($MocksTable.$converterfinishedAtn);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  questionIds = GeneratedColumn<String>(
    'question_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<String>>($MocksTable.$converterquestionIds);
  @override
  late final GeneratedColumnWithTypeConverter<List<int?>, String> answers =
      GeneratedColumn<String>(
        'answers',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<int?>>($MocksTable.$converteranswers);
  static const VerificationMeta _correctCountMeta = const VerificationMeta(
    'correctCount',
  );
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
    'correct_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passedMeta = const VerificationMeta('passed');
  @override
  late final GeneratedColumn<bool> passed = GeneratedColumn<bool>(
    'passed',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("passed" IN (0, 1))',
    ),
  );
  static const VerificationMeta _timedMeta = const VerificationMeta('timed');
  @override
  late final GeneratedColumn<bool> timed = GeneratedColumn<bool>(
    'timed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("timed" IN (0, 1))',
    ),
  );
  static const VerificationMeta _passMarkMeta = const VerificationMeta(
    'passMark',
  );
  @override
  late final GeneratedColumn<int> passMark = GeneratedColumn<int>(
    'pass_mark',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> flagged =
      GeneratedColumn<String>(
        'flagged',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($MocksTable.$converterflagged);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    finishedAt,
    questionIds,
    answers,
    correctCount,
    passed,
    timed,
    passMark,
    flagged,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<MockRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('correct_count')) {
      context.handle(
        _correctCountMeta,
        correctCount.isAcceptableOrUnknown(
          data['correct_count']!,
          _correctCountMeta,
        ),
      );
    }
    if (data.containsKey('passed')) {
      context.handle(
        _passedMeta,
        passed.isAcceptableOrUnknown(data['passed']!, _passedMeta),
      );
    }
    if (data.containsKey('timed')) {
      context.handle(
        _timedMeta,
        timed.isAcceptableOrUnknown(data['timed']!, _timedMeta),
      );
    } else if (isInserting) {
      context.missing(_timedMeta);
    }
    if (data.containsKey('pass_mark')) {
      context.handle(
        _passMarkMeta,
        passMark.isAcceptableOrUnknown(data['pass_mark']!, _passMarkMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MockRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MockRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startedAt: $MocksTable.$converterstartedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}started_at'],
        )!,
      ),
      finishedAt: $MocksTable.$converterfinishedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}finished_at'],
        ),
      ),
      questionIds: $MocksTable.$converterquestionIds.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}question_ids'],
        )!,
      ),
      answers: $MocksTable.$converteranswers.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}answers'],
        )!,
      ),
      correctCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_count'],
      ),
      passed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}passed'],
      ),
      timed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}timed'],
      )!,
      passMark: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pass_mark'],
      ),
      flagged: $MocksTable.$converterflagged.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}flagged'],
        )!,
      ),
    );
  }

  @override
  $MocksTable createAlias(String alias) {
    return $MocksTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $converterstartedAt =
      const LocalUtcDateTimeConverter();
  static TypeConverter<DateTime, DateTime> $converterfinishedAt =
      const LocalUtcDateTimeConverter();
  static TypeConverter<DateTime?, DateTime?> $converterfinishedAtn =
      NullAwareTypeConverter.wrap($converterfinishedAt);
  static TypeConverter<List<String>, String> $converterquestionIds =
      const StringListConverter();
  static TypeConverter<List<int?>, String> $converteranswers =
      const NullableIntListConverter();
  static TypeConverter<List<String>, String> $converterflagged =
      const StringListConverter();
}

class MockRow extends DataClass implements Insertable<MockRow> {
  final int id;
  final DateTime startedAt;
  final DateTime? finishedAt;

  /// JSON array of question ids, in exam order.
  final List<String> questionIds;

  /// JSON array, same length as [questionIds]; null = unanswered.
  final List<int?> answers;
  final int? correctCount;
  final bool? passed;
  final bool timed;

  /// The pass mark in force when the mock was handed in (schema v2). Null for
  /// unfinished mocks and for the ones finished before v2, which do not know
  /// it. The verdict of an old mock must not change with a later pass mark.
  final int? passMark;

  /// JSON array of the ids of the questions the user marked as doubtful
  /// (schema v4); empty for every mock made before. Ids, not positions, so
  /// the mark follows the question.
  final List<String> flagged;
  const MockRow({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    required this.questionIds,
    required this.answers,
    this.correctCount,
    this.passed,
    required this.timed,
    this.passMark,
    required this.flagged,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['started_at'] = Variable<DateTime>(
        $MocksTable.$converterstartedAt.toSql(startedAt),
      );
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(
        $MocksTable.$converterfinishedAtn.toSql(finishedAt),
      );
    }
    {
      map['question_ids'] = Variable<String>(
        $MocksTable.$converterquestionIds.toSql(questionIds),
      );
    }
    {
      map['answers'] = Variable<String>(
        $MocksTable.$converteranswers.toSql(answers),
      );
    }
    if (!nullToAbsent || correctCount != null) {
      map['correct_count'] = Variable<int>(correctCount);
    }
    if (!nullToAbsent || passed != null) {
      map['passed'] = Variable<bool>(passed);
    }
    map['timed'] = Variable<bool>(timed);
    if (!nullToAbsent || passMark != null) {
      map['pass_mark'] = Variable<int>(passMark);
    }
    {
      map['flagged'] = Variable<String>(
        $MocksTable.$converterflagged.toSql(flagged),
      );
    }
    return map;
  }

  MocksCompanion toCompanion(bool nullToAbsent) {
    return MocksCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      questionIds: Value(questionIds),
      answers: Value(answers),
      correctCount: correctCount == null && nullToAbsent
          ? const Value.absent()
          : Value(correctCount),
      passed: passed == null && nullToAbsent
          ? const Value.absent()
          : Value(passed),
      timed: Value(timed),
      passMark: passMark == null && nullToAbsent
          ? const Value.absent()
          : Value(passMark),
      flagged: Value(flagged),
    );
  }

  factory MockRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MockRow(
      id: serializer.fromJson<int>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      questionIds: serializer.fromJson<List<String>>(json['questionIds']),
      answers: serializer.fromJson<List<int?>>(json['answers']),
      correctCount: serializer.fromJson<int?>(json['correctCount']),
      passed: serializer.fromJson<bool?>(json['passed']),
      timed: serializer.fromJson<bool>(json['timed']),
      passMark: serializer.fromJson<int?>(json['passMark']),
      flagged: serializer.fromJson<List<String>>(json['flagged']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'questionIds': serializer.toJson<List<String>>(questionIds),
      'answers': serializer.toJson<List<int?>>(answers),
      'correctCount': serializer.toJson<int?>(correctCount),
      'passed': serializer.toJson<bool?>(passed),
      'timed': serializer.toJson<bool>(timed),
      'passMark': serializer.toJson<int?>(passMark),
      'flagged': serializer.toJson<List<String>>(flagged),
    };
  }

  MockRow copyWith({
    int? id,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    List<String>? questionIds,
    List<int?>? answers,
    Value<int?> correctCount = const Value.absent(),
    Value<bool?> passed = const Value.absent(),
    bool? timed,
    Value<int?> passMark = const Value.absent(),
    List<String>? flagged,
  }) => MockRow(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    questionIds: questionIds ?? this.questionIds,
    answers: answers ?? this.answers,
    correctCount: correctCount.present ? correctCount.value : this.correctCount,
    passed: passed.present ? passed.value : this.passed,
    timed: timed ?? this.timed,
    passMark: passMark.present ? passMark.value : this.passMark,
    flagged: flagged ?? this.flagged,
  );
  MockRow copyWithCompanion(MocksCompanion data) {
    return MockRow(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      questionIds: data.questionIds.present
          ? data.questionIds.value
          : this.questionIds,
      answers: data.answers.present ? data.answers.value : this.answers,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
      passed: data.passed.present ? data.passed.value : this.passed,
      timed: data.timed.present ? data.timed.value : this.timed,
      passMark: data.passMark.present ? data.passMark.value : this.passMark,
      flagged: data.flagged.present ? data.flagged.value : this.flagged,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MockRow(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('questionIds: $questionIds, ')
          ..write('answers: $answers, ')
          ..write('correctCount: $correctCount, ')
          ..write('passed: $passed, ')
          ..write('timed: $timed, ')
          ..write('passMark: $passMark, ')
          ..write('flagged: $flagged')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    finishedAt,
    questionIds,
    answers,
    correctCount,
    passed,
    timed,
    passMark,
    flagged,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MockRow &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.questionIds == this.questionIds &&
          other.answers == this.answers &&
          other.correctCount == this.correctCount &&
          other.passed == this.passed &&
          other.timed == this.timed &&
          other.passMark == this.passMark &&
          other.flagged == this.flagged);
}

class MocksCompanion extends UpdateCompanion<MockRow> {
  final Value<int> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<List<String>> questionIds;
  final Value<List<int?>> answers;
  final Value<int?> correctCount;
  final Value<bool?> passed;
  final Value<bool> timed;
  final Value<int?> passMark;
  final Value<List<String>> flagged;
  const MocksCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.questionIds = const Value.absent(),
    this.answers = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.passed = const Value.absent(),
    this.timed = const Value.absent(),
    this.passMark = const Value.absent(),
    this.flagged = const Value.absent(),
  });
  MocksCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
    required List<String> questionIds,
    required List<int?> answers,
    this.correctCount = const Value.absent(),
    this.passed = const Value.absent(),
    required bool timed,
    this.passMark = const Value.absent(),
    this.flagged = const Value.absent(),
  }) : startedAt = Value(startedAt),
       questionIds = Value(questionIds),
       answers = Value(answers),
       timed = Value(timed);
  static Insertable<MockRow> custom({
    Expression<int>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<String>? questionIds,
    Expression<String>? answers,
    Expression<int>? correctCount,
    Expression<bool>? passed,
    Expression<bool>? timed,
    Expression<int>? passMark,
    Expression<String>? flagged,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (questionIds != null) 'question_ids': questionIds,
      if (answers != null) 'answers': answers,
      if (correctCount != null) 'correct_count': correctCount,
      if (passed != null) 'passed': passed,
      if (timed != null) 'timed': timed,
      if (passMark != null) 'pass_mark': passMark,
      if (flagged != null) 'flagged': flagged,
    });
  }

  MocksCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<List<String>>? questionIds,
    Value<List<int?>>? answers,
    Value<int?>? correctCount,
    Value<bool?>? passed,
    Value<bool>? timed,
    Value<int?>? passMark,
    Value<List<String>>? flagged,
  }) {
    return MocksCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      questionIds: questionIds ?? this.questionIds,
      answers: answers ?? this.answers,
      correctCount: correctCount ?? this.correctCount,
      passed: passed ?? this.passed,
      timed: timed ?? this.timed,
      passMark: passMark ?? this.passMark,
      flagged: flagged ?? this.flagged,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(
        $MocksTable.$converterstartedAt.toSql(startedAt.value),
      );
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(
        $MocksTable.$converterfinishedAtn.toSql(finishedAt.value),
      );
    }
    if (questionIds.present) {
      map['question_ids'] = Variable<String>(
        $MocksTable.$converterquestionIds.toSql(questionIds.value),
      );
    }
    if (answers.present) {
      map['answers'] = Variable<String>(
        $MocksTable.$converteranswers.toSql(answers.value),
      );
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (passed.present) {
      map['passed'] = Variable<bool>(passed.value);
    }
    if (timed.present) {
      map['timed'] = Variable<bool>(timed.value);
    }
    if (passMark.present) {
      map['pass_mark'] = Variable<int>(passMark.value);
    }
    if (flagged.present) {
      map['flagged'] = Variable<String>(
        $MocksTable.$converterflagged.toSql(flagged.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MocksCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('questionIds: $questionIds, ')
          ..write('answers: $answers, ')
          ..write('correctCount: $correctCount, ')
          ..write('passed: $passed, ')
          ..write('timed: $timed, ')
          ..write('passMark: $passMark, ')
          ..write('flagged: $flagged')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $QuestionsTable questions = $QuestionsTable(this);
  late final $AttemptsTable attempts = $AttemptsTable(this);
  late final $SrsStateTable srsState = $SrsStateTable(this);
  late final $MocksTable mocks = $MocksTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index questionsTema = Index(
    'questions_tema',
    'CREATE INDEX questions_tema ON questions (tema)',
  );
  late final Index attemptsQuestionAnswered = Index(
    'attempts_question_answered',
    'CREATE INDEX attempts_question_answered ON attempts (question_id, answered_at)',
  );
  late final Index attemptsMock = Index(
    'attempts_mock',
    'CREATE INDEX attempts_mock ON attempts (mock_id)',
  );
  late final QuestionsDao questionsDao = QuestionsDao(this as AppDatabase);
  late final AttemptsDao attemptsDao = AttemptsDao(this as AppDatabase);
  late final SrsDao srsDao = SrsDao(this as AppDatabase);
  late final MocksDao mocksDao = MocksDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    questions,
    attempts,
    srsState,
    mocks,
    settings,
    questionsTema,
    attemptsQuestionAnswered,
    attemptsMock,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$QuestionsTableCreateCompanionBuilder = QuestionsCompanion Function({
  required String id,
  required int tema,
  Value<String?> section,
  required String stem,
  required List<String> options,
  required int answer,
  Value<String?> explanation,
  Value<String?> article,
  required List<String> flags,
  required String edition,
  required bool reviewed,
  Value<bool> retired,
  Value<String?> notice,
  Value<int> rowid,
});
typedef $$QuestionsTableUpdateCompanionBuilder = QuestionsCompanion Function({
  Value<String> id,
  Value<int> tema,
  Value<String?> section,
  Value<String> stem,
  Value<List<String>> options,
  Value<int> answer,
  Value<String?> explanation,
  Value<String?> article,
  Value<List<String>> flags,
  Value<String> edition,
  Value<bool> reviewed,
  Value<bool> retired,
  Value<String?> notice,
  Value<int> rowid,
});

class $$QuestionsTableFilterComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tema => $composableBuilder(
    column: $table.tema,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stem => $composableBuilder(
    column: $table.stem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get options => $composableBuilder(
    column: $table.options,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get article => $composableBuilder(
    column: $table.article,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get flags => $composableBuilder(
    column: $table.flags,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get edition => $composableBuilder(
    column: $table.edition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reviewed => $composableBuilder(
    column: $table.reviewed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get retired => $composableBuilder(
    column: $table.retired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notice => $composableBuilder(
    column: $table.notice,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuestionsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tema => $composableBuilder(
    column: $table.tema,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stem => $composableBuilder(
    column: $table.stem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get options => $composableBuilder(
    column: $table.options,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get article => $composableBuilder(
    column: $table.article,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flags => $composableBuilder(
    column: $table.flags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get edition => $composableBuilder(
    column: $table.edition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reviewed => $composableBuilder(
    column: $table.reviewed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get retired => $composableBuilder(
    column: $table.retired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notice => $composableBuilder(
    column: $table.notice,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuestionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get tema =>
      $composableBuilder(column: $table.tema, builder: (column) => column);

  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<String> get stem =>
      $composableBuilder(column: $table.stem, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get options =>
      $composableBuilder(column: $table.options, builder: (column) => column);

  GeneratedColumn<int> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get article =>
      $composableBuilder(column: $table.article, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get flags =>
      $composableBuilder(column: $table.flags, builder: (column) => column);

  GeneratedColumn<String> get edition =>
      $composableBuilder(column: $table.edition, builder: (column) => column);

  GeneratedColumn<bool> get reviewed =>
      $composableBuilder(column: $table.reviewed, builder: (column) => column);

  GeneratedColumn<bool> get retired =>
      $composableBuilder(column: $table.retired, builder: (column) => column);

  GeneratedColumn<String> get notice =>
      $composableBuilder(column: $table.notice, builder: (column) => column);
}

class $$QuestionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuestionsTable,
          QuestionRow,
          $$QuestionsTableFilterComposer,
          $$QuestionsTableOrderingComposer,
          $$QuestionsTableAnnotationComposer,
          $$QuestionsTableCreateCompanionBuilder,
          $$QuestionsTableUpdateCompanionBuilder,
          (
            QuestionRow,
            BaseReferences<_$AppDatabase, $QuestionsTable, QuestionRow>,
          ),
          QuestionRow,
          PrefetchHooks Function()
        > {
  $$QuestionsTableTableManager(_$AppDatabase db, $QuestionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> tema = const Value.absent(),
                Value<String?> section = const Value.absent(),
                Value<String> stem = const Value.absent(),
                Value<List<String>> options = const Value.absent(),
                Value<int> answer = const Value.absent(),
                Value<String?> explanation = const Value.absent(),
                Value<String?> article = const Value.absent(),
                Value<List<String>> flags = const Value.absent(),
                Value<String> edition = const Value.absent(),
                Value<bool> reviewed = const Value.absent(),
                Value<bool> retired = const Value.absent(),
                Value<String?> notice = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestionsCompanion(
                id: id,
                tema: tema,
                section: section,
                stem: stem,
                options: options,
                answer: answer,
                explanation: explanation,
                article: article,
                flags: flags,
                edition: edition,
                reviewed: reviewed,
                retired: retired,
                notice: notice,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int tema,
                Value<String?> section = const Value.absent(),
                required String stem,
                required List<String> options,
                required int answer,
                Value<String?> explanation = const Value.absent(),
                Value<String?> article = const Value.absent(),
                required List<String> flags,
                required String edition,
                required bool reviewed,
                Value<bool> retired = const Value.absent(),
                Value<String?> notice = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestionsCompanion.insert(
                id: id,
                tema: tema,
                section: section,
                stem: stem,
                options: options,
                answer: answer,
                explanation: explanation,
                article: article,
                flags: flags,
                edition: edition,
                reviewed: reviewed,
                retired: retired,
                notice: notice,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QuestionsTable, QuestionRow>(table),
                  BaseReferences<_$AppDatabase, $QuestionsTable, QuestionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuestionsTable,
      QuestionRow,
      $$QuestionsTableFilterComposer,
      $$QuestionsTableOrderingComposer,
      $$QuestionsTableAnnotationComposer,
      $$QuestionsTableCreateCompanionBuilder,
      $$QuestionsTableUpdateCompanionBuilder,
      (
        QuestionRow,
        BaseReferences<_$AppDatabase, $QuestionsTable, QuestionRow>,
      ),
      QuestionRow,
      PrefetchHooks Function()
    >;
typedef $$AttemptsTableCreateCompanionBuilder = AttemptsCompanion Function({
  Value<int> id,
  required String questionId,
  required AttemptMode mode,
  Value<int?> selected,
  required bool correct,
  required DateTime answeredAt,
  Value<int?> mockId,
  Value<int?> elapsedMs,
});
typedef $$AttemptsTableUpdateCompanionBuilder = AttemptsCompanion Function({
  Value<int> id,
  Value<String> questionId,
  Value<AttemptMode> mode,
  Value<int?> selected,
  Value<bool> correct,
  Value<DateTime> answeredAt,
  Value<int?> mockId,
  Value<int?> elapsedMs,
});

class $$AttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableFilterComposer({
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

  ColumnFilters<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AttemptMode, AttemptMode, String> get mode =>
      $composableBuilder(
        column: $table.mode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get selected => $composableBuilder(
    column: $table.selected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get answeredAt =>
      $composableBuilder(
        column: $table.answeredAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get mockId => $composableBuilder(
    column: $table.mockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableOrderingComposer({
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

  ColumnOrderings<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get selected => $composableBuilder(
    column: $table.selected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mockId => $composableBuilder(
    column: $table.mockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<AttemptMode, String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get selected =>
      $composableBuilder(column: $table.selected, builder: (column) => column);

  GeneratedColumn<bool> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, DateTime> get answeredAt =>
      $composableBuilder(
        column: $table.answeredAt,
        builder: (column) => column,
      );

  GeneratedColumn<int> get mockId =>
      $composableBuilder(column: $table.mockId, builder: (column) => column);

  GeneratedColumn<int> get elapsedMs =>
      $composableBuilder(column: $table.elapsedMs, builder: (column) => column);
}

class $$AttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttemptsTable,
          AttemptRow,
          $$AttemptsTableFilterComposer,
          $$AttemptsTableOrderingComposer,
          $$AttemptsTableAnnotationComposer,
          $$AttemptsTableCreateCompanionBuilder,
          $$AttemptsTableUpdateCompanionBuilder,
          (
            AttemptRow,
            BaseReferences<_$AppDatabase, $AttemptsTable, AttemptRow>,
          ),
          AttemptRow,
          PrefetchHooks Function()
        > {
  $$AttemptsTableTableManager(_$AppDatabase db, $AttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> questionId = const Value.absent(),
                Value<AttemptMode> mode = const Value.absent(),
                Value<int?> selected = const Value.absent(),
                Value<bool> correct = const Value.absent(),
                Value<DateTime> answeredAt = const Value.absent(),
                Value<int?> mockId = const Value.absent(),
                Value<int?> elapsedMs = const Value.absent(),
              }) => AttemptsCompanion(
                id: id,
                questionId: questionId,
                mode: mode,
                selected: selected,
                correct: correct,
                answeredAt: answeredAt,
                mockId: mockId,
                elapsedMs: elapsedMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String questionId,
                required AttemptMode mode,
                Value<int?> selected = const Value.absent(),
                required bool correct,
                required DateTime answeredAt,
                Value<int?> mockId = const Value.absent(),
                Value<int?> elapsedMs = const Value.absent(),
              }) => AttemptsCompanion.insert(
                id: id,
                questionId: questionId,
                mode: mode,
                selected: selected,
                correct: correct,
                answeredAt: answeredAt,
                mockId: mockId,
                elapsedMs: elapsedMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttemptsTable, AttemptRow>(table),
                  BaseReferences<_$AppDatabase, $AttemptsTable, AttemptRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttemptsTable,
      AttemptRow,
      $$AttemptsTableFilterComposer,
      $$AttemptsTableOrderingComposer,
      $$AttemptsTableAnnotationComposer,
      $$AttemptsTableCreateCompanionBuilder,
      $$AttemptsTableUpdateCompanionBuilder,
      (AttemptRow, BaseReferences<_$AppDatabase, $AttemptsTable, AttemptRow>),
      AttemptRow,
      PrefetchHooks Function()
    >;
typedef $$SrsStateTableCreateCompanionBuilder = SrsStateCompanion Function({
  required String questionId,
  required int box,
  required DateTime dueAt,
  required int reps,
  required int lapses,
  Value<DateTime?> lastAnsweredAt,
  Value<int> rowid,
});
typedef $$SrsStateTableUpdateCompanionBuilder = SrsStateCompanion Function({
  Value<String> questionId,
  Value<int> box,
  Value<DateTime> dueAt,
  Value<int> reps,
  Value<int> lapses,
  Value<DateTime?> lastAnsweredAt,
  Value<int> rowid,
});

class $$SrsStateTableFilterComposer
    extends Composer<_$AppDatabase, $SrsStateTable> {
  $$SrsStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get box => $composableBuilder(
    column: $table.box,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get dueAt =>
      $composableBuilder(
        column: $table.dueAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, DateTime>
  get lastAnsweredAt => $composableBuilder(
    column: $table.lastAnsweredAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$SrsStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SrsStateTable> {
  $$SrsStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get box => $composableBuilder(
    column: $table.box,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAnsweredAt => $composableBuilder(
    column: $table.lastAnsweredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SrsStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SrsStateTable> {
  $$SrsStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get box =>
      $composableBuilder(column: $table.box, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, DateTime> get lastAnsweredAt =>
      $composableBuilder(
        column: $table.lastAnsweredAt,
        builder: (column) => column,
      );
}

class $$SrsStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SrsStateTable,
          SrsStateRow,
          $$SrsStateTableFilterComposer,
          $$SrsStateTableOrderingComposer,
          $$SrsStateTableAnnotationComposer,
          $$SrsStateTableCreateCompanionBuilder,
          $$SrsStateTableUpdateCompanionBuilder,
          (
            SrsStateRow,
            BaseReferences<_$AppDatabase, $SrsStateTable, SrsStateRow>,
          ),
          SrsStateRow,
          PrefetchHooks Function()
        > {
  $$SrsStateTableTableManager(_$AppDatabase db, $SrsStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SrsStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SrsStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SrsStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> questionId = const Value.absent(),
                Value<int> box = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<DateTime?> lastAnsweredAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SrsStateCompanion(
                questionId: questionId,
                box: box,
                dueAt: dueAt,
                reps: reps,
                lapses: lapses,
                lastAnsweredAt: lastAnsweredAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String questionId,
                required int box,
                required DateTime dueAt,
                required int reps,
                required int lapses,
                Value<DateTime?> lastAnsweredAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SrsStateCompanion.insert(
                questionId: questionId,
                box: box,
                dueAt: dueAt,
                reps: reps,
                lapses: lapses,
                lastAnsweredAt: lastAnsweredAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SrsStateTable, SrsStateRow>(table),
                  BaseReferences<_$AppDatabase, $SrsStateTable, SrsStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SrsStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SrsStateTable,
      SrsStateRow,
      $$SrsStateTableFilterComposer,
      $$SrsStateTableOrderingComposer,
      $$SrsStateTableAnnotationComposer,
      $$SrsStateTableCreateCompanionBuilder,
      $$SrsStateTableUpdateCompanionBuilder,
      (SrsStateRow, BaseReferences<_$AppDatabase, $SrsStateTable, SrsStateRow>),
      SrsStateRow,
      PrefetchHooks Function()
    >;
typedef $$MocksTableCreateCompanionBuilder = MocksCompanion Function({
  Value<int> id,
  required DateTime startedAt,
  Value<DateTime?> finishedAt,
  required List<String> questionIds,
  required List<int?> answers,
  Value<int?> correctCount,
  Value<bool?> passed,
  required bool timed,
  Value<int?> passMark,
  Value<List<String>> flagged,
});
typedef $$MocksTableUpdateCompanionBuilder = MocksCompanion Function({
  Value<int> id,
  Value<DateTime> startedAt,
  Value<DateTime?> finishedAt,
  Value<List<String>> questionIds,
  Value<List<int?>> answers,
  Value<int?> correctCount,
  Value<bool?> passed,
  Value<bool> timed,
  Value<int?> passMark,
  Value<List<String>> flagged,
});

class $$MocksTableFilterComposer extends Composer<_$AppDatabase, $MocksTable> {
  $$MocksTableFilterComposer({
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

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get startedAt =>
      $composableBuilder(
        column: $table.startedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, DateTime>
  get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get questionIds => $composableBuilder(
    column: $table.questionIds,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<int?>, List<int>, String> get answers =>
      $composableBuilder(
        column: $table.answers,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get passed => $composableBuilder(
    column: $table.passed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get timed => $composableBuilder(
    column: $table.timed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get passMark => $composableBuilder(
    column: $table.passMark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get flagged => $composableBuilder(
    column: $table.flagged,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$MocksTableOrderingComposer
    extends Composer<_$AppDatabase, $MocksTable> {
  $$MocksTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionIds => $composableBuilder(
    column: $table.questionIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answers => $composableBuilder(
    column: $table.answers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get passed => $composableBuilder(
    column: $table.passed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get timed => $composableBuilder(
    column: $table.timed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get passMark => $composableBuilder(
    column: $table.passMark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flagged => $composableBuilder(
    column: $table.flagged,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $MocksTable> {
  $$MocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, DateTime> get finishedAt =>
      $composableBuilder(
        column: $table.finishedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>, String> get questionIds =>
      $composableBuilder(
        column: $table.questionIds,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<int?>, String> get answers =>
      $composableBuilder(column: $table.answers, builder: (column) => column);

  GeneratedColumn<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get passed =>
      $composableBuilder(column: $table.passed, builder: (column) => column);

  GeneratedColumn<bool> get timed =>
      $composableBuilder(column: $table.timed, builder: (column) => column);

  GeneratedColumn<int> get passMark =>
      $composableBuilder(column: $table.passMark, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get flagged =>
      $composableBuilder(column: $table.flagged, builder: (column) => column);
}

class $$MocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MocksTable,
          MockRow,
          $$MocksTableFilterComposer,
          $$MocksTableOrderingComposer,
          $$MocksTableAnnotationComposer,
          $$MocksTableCreateCompanionBuilder,
          $$MocksTableUpdateCompanionBuilder,
          (MockRow, BaseReferences<_$AppDatabase, $MocksTable, MockRow>),
          MockRow,
          PrefetchHooks Function()
        > {
  $$MocksTableTableManager(_$AppDatabase db, $MocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<List<String>> questionIds = const Value.absent(),
                Value<List<int?>> answers = const Value.absent(),
                Value<int?> correctCount = const Value.absent(),
                Value<bool?> passed = const Value.absent(),
                Value<bool> timed = const Value.absent(),
                Value<int?> passMark = const Value.absent(),
                Value<List<String>> flagged = const Value.absent(),
              }) => MocksCompanion(
                id: id,
                startedAt: startedAt,
                finishedAt: finishedAt,
                questionIds: questionIds,
                answers: answers,
                correctCount: correctCount,
                passed: passed,
                timed: timed,
                passMark: passMark,
                flagged: flagged,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                required List<String> questionIds,
                required List<int?> answers,
                Value<int?> correctCount = const Value.absent(),
                Value<bool?> passed = const Value.absent(),
                required bool timed,
                Value<int?> passMark = const Value.absent(),
                Value<List<String>> flagged = const Value.absent(),
              }) => MocksCompanion.insert(
                id: id,
                startedAt: startedAt,
                finishedAt: finishedAt,
                questionIds: questionIds,
                answers: answers,
                correctCount: correctCount,
                passed: passed,
                timed: timed,
                passMark: passMark,
                flagged: flagged,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MocksTable, MockRow>(table),
                  BaseReferences<_$AppDatabase, $MocksTable, MockRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MocksTable,
      MockRow,
      $$MocksTableFilterComposer,
      $$MocksTableOrderingComposer,
      $$MocksTableAnnotationComposer,
      $$MocksTableCreateCompanionBuilder,
      $$MocksTableUpdateCompanionBuilder,
      (MockRow, BaseReferences<_$AppDatabase, $MocksTable, MockRow>),
      MockRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db, _db.questions);
  $$AttemptsTableTableManager get attempts =>
      $$AttemptsTableTableManager(_db, _db.attempts);
  $$SrsStateTableTableManager get srsState =>
      $$SrsStateTableTableManager(_db, _db.srsState);
  $$MocksTableTableManager get mocks =>
      $$MocksTableTableManager(_db, _db.mocks);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}

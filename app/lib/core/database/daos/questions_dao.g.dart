// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'questions_dao.dart';

// ignore_for_file: type=lint
mixin _$QuestionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $QuestionsTable get questions => attachedDatabase.questions;
  QuestionsDaoManager get managers => QuestionsDaoManager(this);
}

class QuestionsDaoManager {
  final _$QuestionsDaoMixin _db;
  QuestionsDaoManager(this._db);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db.attachedDatabase, _db.questions);
}

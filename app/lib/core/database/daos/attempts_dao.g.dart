// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attempts_dao.dart';

// ignore_for_file: type=lint
mixin _$AttemptsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AttemptsTable get attempts => attachedDatabase.attempts;
  AttemptsDaoManager get managers => AttemptsDaoManager(this);
}

class AttemptsDaoManager {
  final _$AttemptsDaoMixin _db;
  AttemptsDaoManager(this._db);
  $$AttemptsTableTableManager get attempts =>
      $$AttemptsTableTableManager(_db.attachedDatabase, _db.attempts);
}

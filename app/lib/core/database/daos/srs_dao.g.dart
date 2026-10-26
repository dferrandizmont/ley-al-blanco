// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'srs_dao.dart';

// ignore_for_file: type=lint
mixin _$SrsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SrsStateTable get srsState => attachedDatabase.srsState;
  SrsDaoManager get managers => SrsDaoManager(this);
}

class SrsDaoManager {
  final _$SrsDaoMixin _db;
  SrsDaoManager(this._db);
  $$SrsStateTableTableManager get srsState =>
      $$SrsStateTableTableManager(_db.attachedDatabase, _db.srsState);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mocks_dao.dart';

// ignore_for_file: type=lint
mixin _$MocksDaoMixin on DatabaseAccessor<AppDatabase> {
  $MocksTable get mocks => attachedDatabase.mocks;
  MocksDaoManager get managers => MocksDaoManager(this);
}

class MocksDaoManager {
  final _$MocksDaoMixin _db;
  MocksDaoManager(this._db);
  $$MocksTableTableManager get mocks =>
      $$MocksTableTableManager(_db.attachedDatabase, _db.mocks);
}

import 'package:drift/drift.dart';

/// Producteurs en cache local (annuaire + créations hors ligne).
class LocalProducers extends Table {
  TextColumn get clientId => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get code => text()();
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get village => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get sex => text().withDefault(const Constant(''))();
  TextColumn get org => text().withDefault(const Constant(''))();
  IntColumn get age => integer().withDefault(const Constant(0))();
  BoolColumn get isNew => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {clientId};
}

/// File d’attente des mutations à envoyer (MO-40).
class OutboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientMutationId => text()();
  TextColumn get entity => text()(); // producer | plot | crop | commerce | correction
  TextColumn get operation => text()(); // create | update | validate
  TextColumn get payloadJson => text()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // pending | sent | error
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

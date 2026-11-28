import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [LocalProducers, OutboxEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'mbay_diaay_tech'));

  @override
  int get schemaVersion => 1;

  Future<List<OutboxEntry>> pendingOutbox() => (select(outboxEntries)
        ..where((t) => t.status.equals('pending') | t.status.equals('error'))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .get();

  Future<void> enqueueOutbox({
    required String clientMutationId,
    required String entity,
    required String operation,
    required String payloadJson,
  }) {
    final now = DateTime.now();
    return into(outboxEntries).insert(
      OutboxEntriesCompanion.insert(
        clientMutationId: clientMutationId,
        entity: entity,
        operation: operation,
        payloadJson: payloadJson,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> markOutbox(int id, {required String status, String? error}) {
    return (update(outboxEntries)..where((t) => t.id.equals(id))).write(
      OutboxEntriesCompanion(
        status: Value(status),
        lastError: Value(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> upsertProducer(LocalProducersCompanion row) =>
      into(localProducers).insertOnConflictUpdate(row);

  Future<List<LocalProducer>> allProducers() => select(localProducers).get();

  Future<void> clearAll() async {
    await delete(outboxEntries).go();
    await delete(localProducers).go();
  }
}

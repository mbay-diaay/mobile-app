# Offline Drift + synchro réelle (technicien)

## Drift

- Base : `AppDatabase` (`lib/app/data/local/app_database.dart`)
- Tables : `local_producers`, `outbox_entries`
- Génération : `dart run build_runner build`

## Outbox (MO-40)

- `OutboxService.enqueueProducerCreate(...)` quand création hors ligne
- `OutboxService.flush()` appelé depuis l’écran Synchronisation dès que le réseau est « en ligne »
- Dispatch actuel : `POST /producers` via `ProducersService`
- À étendre : plots, crops, photos, commerce, validations

## Révocation

`SessionService.revoke()` vide aussi la base Drift (`clearAll()`).

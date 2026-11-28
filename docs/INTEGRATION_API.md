# Intégration API · Mbay Diaay

API : `https://api.mbaydiaay.com/v1` (production).  
Surcharge : `flutter run --dart-define=API_URL=http://10.0.2.2:3000/v1` (émulateur Android) ou `http://localhost:3000/v1` (simulateur iOS).

**Contrat de référence prod** : [OpenAPI Swagger](https://api.mbaydiaay.com/v1/docs) · JSON `GET /v1/docs-json` (126 paths, audit **25 nov. 2026**).  
**Auth technicien** : [authentification-mobile.html](https://www.mbaydiaay.com/docs/authentification-mobile.html) · `docs/AUTHENTIFICATION_TECHNICIEN.md`.

---

## Matrice contrat OpenAPI prod ↔ mobile (25/11)

| Domaine | OpenAPI prod | Mobile |
|---|---|---|
| Auth technicien | `POST /auth/technician/activate`, `sign-in`, `refresh`, `logout` · `GET /me` | Branché |
| Auth e-mail (test) | `sign-in` + `otp/*` | Conservé (mode test) |
| Auth producteur | **absent** | Seed local + message 404 |
| Annuaire | `GET /producers` (page/limit), `GET /producers/{id}` | Lecture + cache ; mapping `ProducerDto` |
| Édition fiche | `PATCH /producers/{id}` (`UpdateProducerDto`) | Branché (fiches avec `remoteId`) |
| Création fiche | **pas de `POST /producers`** | Local + outbox ; pas de faux succès serveur |
| Parcelles | `GET /plots?producerId=` · `GET /plots/{id}` | Lecture branchée ; **pas** de POST write |
| Cultures | dans `PlotDto.crops` (`sharePct`, saisons) | Lecture ; édition locale + outbox |
| Corrections | `POST /producers/{id}/corrections` | Branché |
| Photo | `PUT /producers/{id}/photo` (multipart) | Branché (remplace `/cni/photo`) |
| Devices | `POST /devices/register` | Branché |
| CNI reveal | `POST /producers/{id}/cni/reveal` | Pas encore UI terrain |

---

## Ce qui est fait (client)

| Domaine | Détail | Fichier |
|---|---|---|
| Client HTTP | Bearer, timeout 20 s, `ApiException.userMessage`, `NETWORK`, refresh sur 401 (pas de déco sur 429/5xx/réseau) | `services/api_client.dart` |
| Session | Jetons `flutter_secure_storage` ; refresh refusé → reconnexion | `api_client.dart`, `main.dart` |
| Connexion tech | activate / sign-in / me / PIN / download | `auth_service.dart`, `modules/activation/` |
| Producteurs | `GET /producers` paginé + cache offline | `producer_repository.dart` |
| Parcelles | `GET /plots?producerId=` | `session_service.dart` `loadPlots` |
| Sync | Outbox Drift ; `markSent` seulement si flush N > 0 | `outbox_service.dart`, `sync.dart` |

---

## Limites API prod (bloquantes terrain write)

1. **Pas de `POST /producers`** — nouvelle fiche reste locale / outbox en erreur `NOT_FOUND`.
2. **Pas de write plots/crops** — relevé GPS et cultures restent sur l’appareil jusqu’à déploiement.
3. **Pas de `/auth/producer/*`** — parcours producteur = seed / aperçu design.
4. `/auth/logout` ne révoque toujours pas le refresh côté serveur (point ouvert doc auth).

---

## Message Aldrich

> Priorités API bloquantes mobile : (1) `POST /producers` (+ write plots/crops alignés `PlotDto`), (2) `/auth/producer/register` + `sign-in`, (3) reseeder comptes démo tech/prod. Sans ça, le terrain reste **lecture + PATCH/corrections + outbox locale**.

---

## Compte de test (réf.)

- Technicien e-mail (si seed prod OK) : `fatou.sarr@cradesc.example` / `Demonstration2026` / OTP `000000`
- Seed local app : Fatou Sarr, PIN `1234` (sans API)

---

## Suite mobile (hors ce lot)

- Connectivité réelle (`connectivity_plus`)
- Permissions UI depuis `GET /me`
- Révélation CNI / téléphone
- Réconciliation `remoteId` après flush quand create existera
- Tests auto client HTTP / refresh

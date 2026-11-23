# État du projet — Mbay Diaay (23 nov. 2026 — soir)

Document de reprise + **brief CTO** (copiable dans Notion).  
À lire en premier avant de reprendre le code ou d’arbitrer une priorisation.

**Périmètre agent mobile** : `mbay-diaay-mobile` uniquement. Web Angular = Aldrich (ne pas toucher).

**Session du soir** : app macOS arrêtée · revue Bugbot · commit branche `chore/phase2-auth-cleanup` · reprise demain sur findings P1 (outbox / cold start producteur / switch rôle).

---

## Brief CTO — contexte à coller dans Notion

> **Rôle** : CTO — arbitrage tech, priorités, découpage Mobile / API / Web.  
> **Date** : 23 novembre 2026 (soir)  
> **Périmètre** : Phase 2 terrain (app technicien + producteur) + Module 1 web SCOOP + API Nest.

### Situation en une phrase

Le **design et les parcours UI** de l’app mobile sont prêts pour une démo terrain (seed local) ; le **vrai goulot reste l’alignement API prod** (auth producteur, CRUD) et la **synchro offline réelle** (réconciliation outbox).

### Décisions tech déjà prises (ne pas rouvrir sans raison)

| Décision | Statut | Implication |
|---|---|---|
| **Une seule app mobile** (technicien + producteur via `role_gate`) | Actée | Proto `mbay-diaay-producer` = archive uniquement |
| Stack mobile | Flutter 3.27+ / GetX / Drift (outbox) / secure storage | Continuer ; pas de rewrite |
| API cible | `https://api.mbaydiaay.com/v1` | Aldrich owner back ; Mobile consomme le contrat OpenAPI **déployé** |
| Front admin | Analog (`web-angular/`) = production ; React = archive | Ne plus développer dans `src/` React |
| i18n FR / WO | GetX Translations ; WO = FR + brouillons (pas de pseudo `~~~`) | Relecture locuteur obligatoire avant « officiel » |
| Offline démo | Simulation Profil › Réseau (coupe API + outbox) | Connectivité réelle = axe P2 |

### Ce qui est solide aujourd’hui (démo OK)

- Auth **technicien** (activate / sign-in / refresh / PIN local / download annuaire)
- Shell 5 onglets, maquette forêt / citron / crème, GPS réel, cultures locales
- **Seed local** Fatou Sarr (PIN `1234`) — charge le catalogue démo ; boot API = annuaire vide puis cache/API
- Parcours **changer PIN** : vérification du PIN actuel d’abord
- **Recherche producteurs** (nom / village / téléphone)
- Bascule **FR ↔ WO** lisible + mode **hors ligne** simulé (Accueil / Sync / API)
- **Espace producteur** densifié (écran 23) : KPIs, 3 parcelles, alertes, calendrier, actions, SwipeCta correction
- Accès Profil → aperçu maquette 23 + shell seed producteur
- **Session dual-rôle** corrigée (splash / jetons / expiration / OTP tech)
- **Création fiche** : plus de double envoi immédiat (API *ou* outbox)

### Ce qui bloque encore (hors mobile / Aldrich)

1. **API prod ≠ code API local** — `POST` producteurs, plots, crops absents (ou non déployés) sur OpenAPI prod.
2. **Auth producteur** — routes `/auth/producer/*` à livrer.
3. **Comptes seed prod** — `INVALID_CREDENTIALS` ; démo = seed local.
4. **Outbox / sync** — flush ≠ réconciliation id serveur (P1 ouvert, confirmé revue 23/11 soir).

### Axes d’amélioration — arbitrage CTO

| Prio | Axe | Owner | Décision attendue |
|---|---|---|---|
| **P0** | ~~Session dual-rôle~~ | Mobile | **Fait** (23/11) |
| **P0** | Livrer `/auth/producer/register` + `sign-in` | **Aldrich** | Bloquant parcours producteur |
| **P0** | Aligner **prod** sur CRUD producteurs + plots/crops *ou* retirer les appels mobile | **Aldrich + CTO** | Choisir : déployer le contrat **ou** geler les features mobile |
| **P1** | Réconciliation outbox + `markSent` honnête + persist `LocalProducers` | Mobile | **Demain** (revue Bugbot) |
| **P1** | Cold start producteur : `GET /me` si jetons ; switch rôle → logout | Mobile | **Demain** |
| **P1** | Brancher corrections (`POST …/corrections`) | Mobile + API | Valeur producteur |
| **P2** | Connectivité réelle (`connectivity_plus`) | Mobile | Remplacer la seule simulation |
| **P2** | Chiffrement Drift (SQLCipher) | Mobile | Sécurité données terrain |
| **P2** | Permissions UI depuis `GET /me` | Mobile | Aligner rôles serveur |
| **P2** | ~~Commit WIP~~ | Mobile | **Fait** (23/11 soir) |
| **P3** | Compte technicien pré-activé (App Review) | Produit | Store |
| **P3** | i18n complète + relecture wolof ; masquer seed en release | Mobile + locuteur | Qualité / stores |

### Questions ouvertes (CTO)

1. **Priorité sprint** : débloquer producteur API **ou** durcir sync technicien offline d’abord ?
2. **Contrat API** : on force le déploiement du CRUD local vers prod, ou on downgrade le mobile en « lecture + outbox locale » jusqu’à alignement ?
3. **Stores** : une app dual-rôle suffit-elle pour Review, ou faudra-t-il 2 binaires (proto archive déjà prêt) ?
4. **Web** : Aldrich continue seul sur `main` Angular ; interventions Mobile/Front seulement sur accord explicite.

### Message type à Aldrich (si ping)

> Priorités API bloquantes mobile : (1) reseeder comptes démo prod, (2) déployer auth producteur, (3) aligner OpenAPI prod sur POST/PATCH producers + plots + crops. Sans ça, la démo reste en seed local / offline simulé.

---

## 1. Décisions produit actives (détail)

| Décision | Détail |
|---|---|
| **Une seule app mobile** | `mbay-diaay-mobile` : choix **Technicien / Producteur** (`role_gate`). |
| **Proto producteur séparé** | `~/Dev/mbay-diaay-producer` = **archive** (2ᵉ store si exigée). |
| **Répartition équipe** | **CTO + agent** : mobile + front. **Aldrich** : back API (+ web Angular sur `main`). |
| **API cible mobile** | `https://api.mbaydiaay.com/v1` (`--dart-define=API_URL=…`). |
| **Front web** | `mbay-diaay` → `web-angular/` (Analog) ; `origin/main` = travail Aldrich. |

---

## 2. Dépôts & branches

| Dépôt | Chemin | Branche | Notes |
|---|---|---|---|
| Mobile | `/Users/moha/Dev/mbay-diaay-mobile` | `chore/phase2-auth-cleanup` | Commit soir 23/11 (Phase 2 UI + dual-rôle + seed + Drift). **Pas encore push** vers `origin`. |
| Web | `/Users/moha/Dev/mbay-diaay` | `main` (= `origin/main`) | Aldrich. Ne pas toucher. |
| API | `/Users/moha/Dev/mbay-diaay-api` | `chore/t1-livrables-architecture` | CRUD local ; **prod OpenAPI ≠ tout ce code**. |
| Producer (proto) | `/Users/moha/Dev/mbay-diaay-producer` | `main` (pas de remote) | Archive. |

---

## 3. Relancer / se connecter

```bash
cd /Users/moha/Dev/mbay-diaay-mobile
flutter pub get
flutter run -d macos          # aperçu design (recommandé)
# iOS si Simulator.app dispo :
flutter run -d iPhone
```

Cibles : iOS pods ≥ 15.0 · macOS ≥ 12.0.

| Mode | Comment |
|---|---|
| **Seed local (démo)** | Écran 01 → **« Accès seed local · Fatou Sarr (PIN 1234) »** — sans API |
| Technicien e-mail (quand seed API OK) | `fatou.sarr@cradesc.example` / `Demonstration2026` / OTP `000000` |
| Admin web (réf.) | `aissatou.ndiaye@cradesc.example` / `Demonstration2026` / OTP `000000` |
| Technicien téléphone | Code 5 chiffres gestionnaire + MDP |
| Producteur | Profil → « Aperçu espace producteur » (maquette 23) ; seed shell via « Compte seed » ; API `/auth/producer/*` absente |

API health : `GET https://api.mbaydiaay.com/v1/health`  
Comptes : `mbay-diaay-api/docs/COMPTES_RECETTE.md` (prod : souvent `INVALID_CREDENTIALS`).

---

## 4. Fait récemment (session 22–23/11)

- Une app dual-rôle + charte producteur alignée technicien  
- i18n FR/WO sans pseudo tirets ; Accueil / Producteurs / Profil branchés  
- Changer PIN → vérif PIN actuel  
- Recherche producteurs + clear champ  
- Offline simulé : coupe `ApiClient` + outbox ; toast ; Accueil A/B  
- Seed local pour démo sans dépendre de prod  
- **Finalisation mobile** : splash / jetons / expiration par rôle ; OTP refuse producteur ; annuaire vide hors seed ; `queueRemote: false` après API/outbox ; auth producteur 404 → message clair  
- **Espace producteur (23)** densifié : DarkHeader, KPIs, 3 parcelles, alertes, calendrier oignon, prochaines actions, SwipeCta  
- Cible **macOS** debug pour revue design  
- **Commit** WIP sur `chore/phase2-auth-cleanup` (soir 23/11)

### Déjà en place (socle)

- Auth technicien, PIN secure storage, devices, shell 01–25 + vente/charge (design)  
- `GET /producers` + cache ; outbox Drift (partiel)  
- Survey GPS réel, cultures locales  
- Docs auth tech/producteur, `PHASE2`, `OFFLINE_SYNC`, `AUDIT_ECRANS`

---

## 5. Pas fait / goulots

1. Auth producteur API (Aldrich)  
2. CRUD producers / plots / crops **sur prod** (Aldrich)  
3. Seed comptes démo prod (Aldrich)  
4. Sync : réconciliation id serveur après flush + `LocalProducers` au boot  
5. Connectivité réelle  
6. Correction / commerce branchés API  
7. Tests auto  
8. Findings revue soir (voir §7) : cold start producteur, switch rôle sans logout, todo = MockData, `markSent` trop agressif  
9. ~~Dettes session dual-rôle~~ → **corrigées** (23/11)  
10. ~~Commit WIP~~ → **fait** (23/11 soir) ; push = à décider demain  

**Web** : Aldrich seul — ne pas toucher depuis le chantier mobile.

---

## 6. Axes d’amélioration (tableau opérationnel)

Voir aussi le **Brief CTO** en tête de document.

| Priorité | Axe | Owner |
|---|---|---|
| P0 | ~~Session dual-rôle~~ | Mobile (**fait**) |
| P0 | `/auth/producer/register` + `sign-in` | Aldrich |
| P0 | Aligner prod API CRUD producers + plots/crops | Aldrich + Mobile |
| P1 | Réconciliation outbox + markSent + LocalProducers | Mobile (**demain**) |
| P1 | Cold start producteur + logout au switch rôle | Mobile (**demain**) |
| P1 | Corrections producteur + fiche | Mobile + API |
| P2 | `connectivity_plus` | Mobile |
| P2 | SQLCipher Drift | Mobile |
| P2 | Permissions depuis `/me` | Mobile |
| P2 | ~~Commit WIP~~ | Mobile (**fait**) |
| P3 | App Review (compte pré-activé) ; masquer seed en release | Produit / Mobile |
| P3 | i18n complète + relecture WO | Mobile + locuteur |

---

## 7. Revue code (Bugbot — 23/11 soir)

Périmètre : changements non commités Phase 2 (dual-rôle, seed, outbox, i18n, shell producteur).  
Agent : [Bugbot Mobile](2ca36dca-fcc9-4801-8d11-ba128d813822).

### Confirmés OK

| Point | Note |
|---|---|
| `clearTokens` / garde `appRole` (`main.dart`) | Ne casse plus la session producteur au cold start |
| `queueRemote: false` après create | Évite le double POST *immédiat* |
| `loadDemoCatalog()` | Uniquement via seed explicite |
| Parcours tech refuse producteur | `clearTokens` + message |

### Findings ouverts (reprendre demain)

| Sévérité | Finding | Fichier (indicatif) |
|---|---|---|
| Critique | Cold start `appRole=producer` + jetons → `producerHome` sans `GET /me` → UI seed si `user.id` vide | `splash.dart`, `producer_home.dart` |
| Critique | Flush outbox « sent » sans réconcilier `SessionService` (`remoteId` / `code`) → risque 2ᵉ POST / UI non sync | `outbox_service.dart`, `session_service.dart` |
| Élevée | Sync `markSent()` vide tout `pending` même si flush a envoyé 0 | `sync.dart` |
| Élevée | « Changer de rôle » = `clearAppRole()` seulement → JWT de l’autre parcours reste | `profile.dart` |
| Élevée | Onglet À compléter = toujours `MockData.todos` | `todo.dart` |
| Élevée | Création offline : Drift outbox oui, `LocalProducers` jamais écrit → cold start fiche absente + fantôme serveur | `new_producer.dart` + Drift |
| Moyenne | Identifiants seed pré-remplis / annoncés (OK démo, risque release) | `producer_login.dart`, i18n |
| Moyenne | Compteur SCOOP biaisé + boutons seed sans garde `kReleaseMode` | `producers.dart`, `phone.dart` |
| Ouvert (ancien) | Entitlements macOS Release | `macos/` |
| Faible (ancien) | Unlock affiche PIN en clair | Proto OK |

### Analyze

`dart analyze` sur modules critiques : **0 erreur**, quelques infos style (`prefer_const`, braces).

---

## 8. Design vs données

### Technicien
| Zone | Design | Données |
|---|---|---|
| Auth + PIN + download | ✅ | API + trousseau |
| Annuaire / recherche | ✅ | API + cache ; mock seulement via seed local |
| Fiche / nouveau | ✅ | Mix API / local / outbox |
| GPS / cultures / carte / todo / sync UI | ✅ | Local + mock (todo = MockData) |
| Commerce / correction | ✅ UI | Pas d’API métier complète |

### Producteur
| Zone | Design | Données |
|---|---|---|
| Role gate + auth UI | ✅ | API absente ; seed / aperçu |
| Espace producteur (23) | ✅ densifié | Contenu maquette (MockData) |
| Shell Accueil / Parcelles / Calendrier / Profil | ✅ | Placeholders / seed |

---

## 9. Checklist reprise demain (30 min)

1. Relire §7 findings Bugbot (surtout outbox + cold start producteur + switch rôle).  
2. `git status` / `git log -1` — vérifier commit ; **push seulement si OK CTO**.  
3. Ping Aldrich (auth producteur + OpenAPI prod + reseeding) si sprint API.  
4. `flutter run -d macos` — seed + aperçu Espace producteur + offline + PIN.  
5. Web : **ne pas toucher** (`web-angular` = Aldrich).

---

## 10. Liens

- Auth tech : `docs/AUTHENTIFICATION_TECHNICIEN.md` · https://www.mbaydiaay.com/docs/authentification-mobile.html  
- Auth producteur : `docs/AUTHENTIFICATION_PRODUCTEUR.md`  
- Écrans : `docs/ECRANS.md`  
- Audit design + i18n : `docs/AUDIT_ECRANS.md`  
- Offline : `docs/OFFLINE_SYNC.md`  
- Intégration : `docs/INTEGRATION_API.md`  
- Swagger : https://api.mbaydiaay.com/v1/docs  
- Front : `/Users/moha/Dev/mbay-diaay/web-angular`  
- API : `/Users/moha/Dev/mbay-diaay-api`

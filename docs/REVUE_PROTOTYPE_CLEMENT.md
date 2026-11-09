# Revue prototype mobile — retour à Clément

| | |
|---|---|
| **Date** | 9 novembre 2026 |
| **Dépôt** | `mbay-diaay/mobile-app` (branche `main` au moment de la revue) |
| **Revue** | Direction technique (API / sécurité / PRD Mobile) |
| **Références** | PRD Mobile v0.1 · PRD Backend · `docs/GUIDE_MOBILE.md` (API) |

Objectif de cette note : après dépôt GitHub du prototype, un **retour écrit** classé par importance, sur les quatre axes demandés.

---

## Synthèse

Le prototype Flutter + GetX est **riche côté parcours UI** (activation, PIN, producteurs, relevé GPS, cultures, synchro simulée) et déjà proche de la maquette v2. En revanche, pour un passage « terrain / L4 », il reste **hors critères** sur le stockage protégé, la synchro réelle, et l’autorité serveur. Ce n’est pas un rejet : c’est un plan de corrections ordonné.

État utile aujourd’hui :

- Création producteur **locale** : oui (écran 11).
- Création producteur **serveur** : possible si session API ouverte (Profil → « Session API ») puis Nouveau producteur — branchement `POST /v1/producers` + upload CNI.
- Auth API : client présent ; OTP corrigé (`code`) ; pas encore le flux téléphone/OTP métier du PRD.

---

## 1. Fonctionnement sans réseau et stockage local protégé

### Constats

| Point | État observé |
|---|---|
| Offline UX | Bonne intention : `NetworkService` (simulation), file `pending`, écrans synchro 20/21, principe « hors ligne = normal ». |
| Persistance métier | Fiches / parcelles / cultures **en mémoire GetX** uniquement → perte au kill process. README l’assume. |
| Persistance sensible | `SharedPreferences` stocke **PIN en clair** (`session_service.dart` : clés `pin`, `account_phone`, `activated`). |
| Base chiffrée | Aucun Drift / SQLite chiffré / `flutter_secure_storage` / Keystore-Keychain. |
| Tokens API | `ApiClient` garde access/refresh **en RAM** seulement (OK pour prototype, insuffisant pour reprise session). |

### Corrections

#### Critique

1. **Ne plus stocker le PIN (ni futurs secrets) en clair dans SharedPreferences.**  
   Utiliser `flutter_secure_storage` (Android Keystore / iOS Keychain). À la révocation : effacer aussi le coffre sécurisé.
2. **Interdire toute persistance de CNI en clair** sur disque (voir §4) — y compris photos CNI hors sandbox chiffrée / envoi différé.

#### Haute

3. Introduire un **store local offline-first** (Drift ou équivalent) pour producteurs, outbox de mutations, parcelles, cultures — avec schéma versionné.
4. Remplacer la bascule « Réseau (simulation) » par la **connectivité réelle** (`connectivity_plus` / équivalent) tout en gardant un mode démo documenté.
5. Outbox : chaque création/modification locale = mutation **idempotente** (UUID client) prête pour `POST` serveur (alignement PRD Backend offline).

#### Moyenne

6. Indicateur discret synchro / en attente / erreur (PRD M2) — déjà esquissé, à brancher sur l’outbox réelle.
7. Durée max hors connexion avant reconnexion obligatoire (MO-02 / BE-15) : absente.

---

## 2. Relevé GPS des parcelles

### Constats

| Point | État observé |
|---|---|
| GPS réel | `geolocator` : stream position, précision affichée, seuils « faible », settings Android/iOS différenciés — **solide pour un proto**. |
| Parcours | Ajout de points, surface estimée dès 3 points (`maps_toolkit`), détection d’auto-intersection → écran reprise — aligné MO-20 à MO-23. |
| Persistance géométrie | Locale session + mock ; **pas d’envoi** polygone / précision par sommet vers l’API. |
| Autorité superficie | Surface calculée **sur l’appareil** ; pas encore la superficie serveur UTM 28N (MO-26 / BE-30). |
| Fonds carte offline | Canvas custom, pas de tuiles Niayes empaquetées (MO-27). |

### Corrections

#### Haute

1. Persister chaque sommet avec **lat/lng + accuracy + timestamp** dans le store local, puis outbox vers endpoints parcelles API (`POST /producers/:id/plots` aujourd’hui stub géométrie simple ; évoluer vers GeoJSON / PostGIS côté serveur).
2. Afficher clairement que la superficie mobile est **indicative** ; après synchro, afficher superficie serveur + écart déclaré.

#### Moyenne

3. Mode cheminement / moyenne multi-mesures (MO-22) : partiel (précision oui, moyenne non).
4. Fonds carte zone Niayes offline (MO-27).
5. Versionnement géométrie « validée / à reprendre » (MO-25) : UI partielle, pas de contrat serveur.

#### Basse

6. Photo parcelle / document foncier différés (MO-28).

---

## 3. Cohérence avec les règles et droits du serveur (dernier mot serveur)

### Constats

| Point | État observé |
|---|---|
| Principe M6 / BE P1 | Encore **largement local** : comptes test téléphone, SMS `482913`, listes mock, synchro qui « envoie » sans HTTP métier. |
| Client API | `ApiClient` + `AuthService` + `ProducersService` (création + photo CNI). |
| Droits | Pas de lecture de `GET /me` → `permissions[]` pour masquer des actions ; le serveur renverra 403 si appel, mais l’UI ne s’aligne pas encore. |
| Doublons / CNI | Suggestion doublon **locale** (nom+village) ; comparaison CNI serveur absente (voulu hors ligne — OK) mais pas de traitement des erreurs serveur à la synchro. |
| OTP API | Corps verify doit utiliser **`code`** (corrigé dans `AuthService`) — pas `otp`. |

### Corrections

#### Critique

1. Toute mutation métier réussie **uniquement** si le serveur l’accepte (ou file outbox jusqu’à acceptation / rejet avec motif). Ne jamais marquer « membre » / « validée » côté client sans confirmation serveur.
2. Après login API : charger `GET /me` et **dériver l’UI** des `permissions` + `scoopId` (ne pas inventer le périmètre).

#### Haute

3. Brancher la file « À envoyer » sur les vrais endpoints (producteurs, plots, crops, photos).
4. Afficher et traiter les codes d’erreur API (`FORBIDDEN`, `VALIDATION_ERROR`, doublon CNI à la synchro).
5. Ne pas hardcoder des rôles dans l’UI au-delà d’un mode démo clairement étiqueté.

#### Moyenne

6. Unifier activation PRD (téléphone + OTP SMS) avec auth API actuelle (email + OTP) — décision produit ; en attendant, documenter les deux chemins (déjà : Profil → Session API).

---

## 4. Aucune donnée sensible en clair sur le téléphone

### Constats

| Donnée | Risque actuel |
|---|---|
| PIN | **Clair** dans SharedPreferences — non conforme. |
| N° CNI saisi | Champ formulaire ; peut rester en mémoire process ; pas de chiffrement au repos. |
| Photos CNI | Fichiers caméra / chemins locaux non chiffrés. |
| Tokens JWT | RAM seulement (mieux que prefs) ; à terme coffre sécurisé. |
| Affichage PIN | Écran unlock affiche le PIN prototype en clair dans le libellé (`prototype : ${session.pin}`) — à retirer hors démo. |
| Listes producteurs | Pas de CNI en clair dans les listes mock (bien) ; masquer toujours `cniMasked` serveur. |

### Corrections

#### Critique

1. PIN + refresh token + éventuel secret appareil → **secure storage** uniquement.
2. Ne jamais logger CNI, OTP, tokens, photos (y compris `print` / crash reporting non filtré).
3. Retirer l’affichage du PIN en clair sur l’écran de déverrouillage hors build démo explicite.

#### Haute

4. Photos CNI : dossier app sandbox + chiffrement fichier ou upload immédiat puis purge locale après ACK serveur.
5. Champ CNI : ne pas persister la valeur brute hors outbox chiffrée ; à l’affichage, uniquement masque serveur.

#### Moyenne

6. Capture d’écran / recents : flag `FLAG_SECURE` sur écrans PIN / CNI (Android).
7. Révocation appareil : wipe secure storage + DB locale (MO-04).

---

## Tableau récapitulatif (par importance)

| Sévérité | ID | Correction |
|---|---|---|
| Critique | C1 | PIN / secrets hors SharedPreferences → secure storage |
| Critique | C2 | Mutations métier = verdict serveur (ou outbox jusqu’au verdict) |
| Critique | C3 | Pas de CNI / OTP / tokens en logs ni PIN affiché en clair |
| Haute | H1 | Store local offline (Drift…) + outbox idempotente |
| Haute | H2 | Synchro réelle producteurs / parcelles / cultures / photos |
| Haute | H3 | UI pilotée par `GET /me` (permissions, scoop) |
| Haute | H4 | Géométrie GPS persistée + superficie serveur après sync |
| Haute | H5 | Photos CNI chiffrées ou purgées après ACK |
| Moyenne | M1 | Connectivité réelle vs simulation |
| Moyenne | M2 | Fonds carte offline Niayes |
| Moyenne | M3 | Durée max offline / révocation wipe complet |
| Moyenne | M4 | Unifier parcours auth téléphone vs email API |
| Basse | B1 | Moyenne multi-GPS, photos parcelle, polish indicateurs |

---

## Déjà en place / en cours (pour éviter le double travail)

- Parcours UI activation → shell → producteur → GPS → cultures : **conservable**.
- Détection contour croisé + précision GPS : **base bonne**.
- `ProducersService.create` + upload CNI + Profil « Session API » : permet déjà de **créer un producteur sur l’API prod** une fois connecté (technicien démo).
- Compte démo API : `fatou.sarr@cradesc.example` / `Demonstration2026` / OTP `000000`.

---

## Comment on saura que c’est « terminé » (critères de clôture de cette revue)

1. Ce document reste dans le dépôt (`docs/REVUE_PROTOTYPE_CLEMENT.md`) avec historique git.
2. Les items **Critique** sont corrigés ou explicitement acceptés par écrit (risque résiduel).
3. Les items **Haute** ont un ticket / PR chacun, ou sont planifiés datés avant L4.
4. Une démo hors ligne (mode avion) : créer producteur → relever parcelle → file outbox → retour réseau → acceptation serveur visible (et rejet visible).

---

*Fin du retour — merci Clément pour le dépôt du prototype ; on itère sur C1–C3 en priorité.*

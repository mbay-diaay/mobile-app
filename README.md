# Mbay Diaay · application technicien

Application Flutter + GetX tirée de la maquette **Mbay Diaay Mobile v2** (Claude Design) : vert forêt, accent citron, fond crème, gros chiffres, cartes très arrondies, et des animations très expressives entre les écrans et les éléments.

C'est un **prototype hors ligne** (données mock en mémoire). La connexion se fait par téléphone + code à 5 chiffres (première fois) puis téléphone + mot de passe ; voir `docs/AUTHENTIFICATION_TECHNICIEN.md`.

**Créer un producteur sur le serveur** : Profil → « Session API (technicien) » (ex. `fatou.sarr@cradesc.example` / `Demonstration2026` / OTP `000000`) → Producteurs → Nouveau. Si la session API est ouverte et le réseau simulé « Connecté », la fiche part en `POST /v1/producers` (sinon elle reste en attente locale).

Revue technique : [`docs/REVUE_PROTOTYPE_CLEMENT.md`](docs/REVUE_PROTOTYPE_CLEMENT.md).

## Lancer

```bash
flutter pub get
flutter run          # Android ou iOS
```

Flutter 3.27 ou plus récent (Dart ≥ 3.6). Les polices (Plus Jakarta Sans, JetBrains Mono) sont fournies dans `assets/fonts/`, donc rien n'est téléchargé au premier lancement.

## Données de test

| Étape | Valeur |
|---|---|
| Technicien (01) | Créé par un gestionnaire depuis le web : il remet un code à **5 chiffres** (72 h, une seule fois). Première connexion : téléphone + code + nouveau mot de passe ; ensuite téléphone + mot de passe. |
| Compte e-mail de test (01 › « Compte e-mail (test) », puis 02) | `fatou.sarr@cradesc.example` / `Demonstration2026`, code e-mail `000000` tant que `TEST_ACCOUNTS_OTP=true` sur le serveur. |
| PIN (03 → 05) | Celui que vous choisissez. Si l'activation est sautée, c'est `1234`. Trois erreurs bloquent le téléphone (06). |
| Doublon (12) | Créez « Aliou Ba » à Mboro. |
| Relevé de parcelle (14 à 16) | GPS réel uniquement : marchez jusqu'à chaque angle et touchez +. Un contour dont deux côtés se coupent ouvre l'écran 16. |
| Réseau | Profil › « Réseau (simulation) », ou la pastille « Hors ligne » de l'accueil. |
| Révocation (25) | Profil › « Simuler une révocation ». |

## Parcours et liens entre écrans

```
Démarrage ─► 01 Connexion (téléphone + code 5 chiffres / mot de passe) ─► 03 PIN + confirmation ─► 04 Téléchargement ─► 05 PIN
                                                                                               │
                         06 PIN bloqué ◄── 3 erreurs ──────────────────────────────────────────┤
                                                                                               ▼
  ┌──────────── Coquille à 5 onglets (barre flottante) ────────────┐
  │ Accueil 07 (hors ligne) / 08 (en ligne) · Producteurs 09 ·     │
  │ Carte 13 · À compléter 22 · Profil 24                          │
  └────────────────────────────────────────────────────────────────┘
   Nouveau producteur 11 ─(doublon)─► 12 ─► Réussite ─► Relevé 14/15/16a/16 ─► 17 ─► Cultures 18/19 ─► Réussite
   Fiche 10 (Infos · Parcelles · Alertes) ─► Relevé · Cultures · Corriger
   Synchronisation 20 (hors ligne) / 21 (envoi) ─► Corriger ─► Réussite
   Profil ─► Changer le PIN · Espace producteur 23 · Verrouiller (05) · Révocation 25 ─► 01
```

Les écrans 01 à 25 suivent la maquette. Le chat de conception prévoyait d'ajouter le démarrage, la confirmation du PIN, les onglets Parcelles et Alertes de la fiche, la correction d'une erreur et l'écran de réussite ; ils sont tous là.


## Données créées

`SessionService` garde ces données en mémoire (`RxList` et `RxMap` GetX) :

- **nouvelle fiche** : elle s'ajoute en tête de la liste des producteurs avec la pastille « Nouveau », passe dans « Vus récemment » et dans les éléments en attente d'envoi ;
- **parcelle relevée** : elle est rattachée au producteur et s'affiche dans l'onglet Parcelles de sa fiche ;
- **cultures** : elles sont enregistrées sur la parcelle ;
- **correction** : elle sort de « À corriger » et passe en attente d'envoi ;
- **réseau rétabli** : l'écran Synchronisation envoie tout, élément par élément, puis vide la file.

Tout repart des données de test au redémarrage. Pour une sauvegarde durable, il suffira de brancher `get_storage` ou une base locale dans `SessionService`.

## Structure

```
lib/
  main.dart                    GetMaterialApp, services permanents
  app/core/                    couleurs, typo (jakarta(), mono(), display()), thème, durées et courbes (Motion)
  app/data/mock_data.dart      producteurs, alertes, contours GPS… (fictifs)
  app/services/                NetworkService (réseau simulé), SessionService (compte, données en mémoire)
  app/routes/                  routes + transitions propres à chaque famille d'écran
  app/widgets/                 animations (FadeSlideIn, Pressable, Shake, PulseDot, CountUp…),
                               boutons, clavier PIN, barre flottante, carte et contours, anneau
  app/modules/<domaine>/       un fichier par écran : contrôleur GetX + vue
```



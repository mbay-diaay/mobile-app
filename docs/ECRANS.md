# Inventaire des écrans — app technicien

Références : maquette PDF « Mbay Diaay Mobile » (01–25) · PRD Mobile v0.1 · Phase 2.

| # | Écran | Route / module | État |
|---|---|---|---|
| — | Splash | `/` | OK |
| — | Choix de rôle | `/role` | OK (Technicien / Producteur — une seule app) |
| 01 | Connexion téléphone / code / MDP | `/activation/phone` | OK (stratégie téléphone, pas SMS métier) |
| P·auth | Welcome / login / register producteur | `/producer-app/*` | OK (+ fallback local) |
| P·home | Shell producteur (5 onglets) | `/producer-app/home` | OK — Accueil / Parcelles / Calendrier / Alertes / Profil |
| 02 | Code e-mail (test) | `/activation/code` | OK (parcours test seulement) |
| 03 | Choix PIN + confirmation | `/activation/pin` | OK |
| 04 | Téléchargement annuaire | `/activation/download` | OK |
| 05 | Déverrouillage PIN | `/unlock` | OK |
| 06 | PIN bloqué | `/blocked` | OK |
| 07/08 | Accueil hors ligne / en ligne | shell · HomeTab | OK (+ saisies rapides vente/charge) |
| 09 | Producteurs / recherche | shell · ProducersTab | OK |
| 10 | Fiche producteur | `/producer` | OK |
| 11/12 | Nouveau + doublon | `/producer/new` | OK |
| 13 | Carte | shell · MapTab | OK |
| 14–16 | Relevé GPS | `/survey` | OK |
| 17 | Relevé terminé | `/survey/done` | OK |
| 18/19 | Cultures | `/crops` | OK |
| 20/21 | Synchronisation | `/sync` | OK |
| 22 | À compléter | shell · TodoTab | OK |
| 23 | Espace producteur | `/producer/space` | OK |
| 24 | Profil | shell · ProfileTab | OK |
| 25 | Appareil révoqué | `/revoked` | OK |
| — | Correction sync | `/sync/fix` | OK |
| — | Succès générique | `/success` | OK |
| **MO-25** | Valider géométrie | `/survey/validate` | Ajouté |
| **MO-33** | Calendrier cultural | `/crops/calendar` | Ajouté |
| **MO-61** | Demande de correction | `/producer/correction` | Ajouté |
| **§3.8** | Vente rapide | `/commerce/sale` | Ajouté |
| **§3.8** | Charge rapide | `/commerce/expense` | Ajouté |

Hors cet inventaire UI (pas des écrans) : Drift offline, tuiles carte offline, synchro différentielle réelle, app producteur séparée.

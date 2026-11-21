# Intégration API · Mbay Diaay

API : `https://api.mbaydiaay.com/v1` (production). Pour viser une API locale : `flutter run --dart-define=API_URL=http://10.0.2.2:3000/v1` (émulateur Android) ou `http://localhost:3000/v1` (simulateur iOS). Contrat de référence : `docs/openapi.json` du dépôt `mbay-diaay/mbay-diaay-api`.

### Ce qui est fait

| Domaine | Détail | Fichier |
|---|---|---|
| Client HTTP | En-tête `Authorization: Bearer`, délai de 20 s, erreurs `{code, message}` converties en messages français (`ApiException.userMessage`), réseau coupé = code `NETWORK`. | `services/api_client.dart` |
| Session | Jetons gardés dans le stockage sécurisé de l'appareil (`flutter_secure_storage`). Sur 401, renouvellement automatique via `/auth/refresh` puis nouvel essai. Si le renouvellement échoue, retour à l'écran de connexion. | `services/api_client.dart`, `main.dart` |
| Connexion | Parcours technicien (voir `AUTHENTIFICATION_TECHNICIEN.md`) : `POST /auth/technician/activate` (téléphone + code à 5 chiffres + mot de passe) puis `POST /auth/technician/sign-in` (téléphone + mot de passe), puis `GET /me`. Ancien parcours conservé pour les comptes de test : `POST /auth/sign-in`, `POST /auth/otp/verify`, `/auth/otp/resend`. | `services/auth_service.dart`, `modules/activation/phone.dart`, `sms_code.dart` |
| Écrans | Écran 01 : trois modes (première connexion, connexion, compte e-mail de test). Écran 02 : code e-mail, ancien parcours seulement. Les écrans 03 (PIN) et 04 (téléchargement) restent identiques. Le profil affiche l'e-mail. | `modules/activation/`, `modules/shell/profile.dart` |
| Producteurs | `GET /producers` et `GET /scoops`, mis en cache dans `shared_preferences` : l'annuaire reste consultable hors ligne. Rafraîchi à l'écran 04 et à l'ouverture de l'accueil. Les fiches créées sur le téléphone restent en tête. | `services/producer_repository.dart`, `services/session_service.dart` |
| Révocation | Prévient l'API (`/auth/logout`), supprime les jetons et le cache. | `services/session_service.dart` |
| Android | Permission `INTERNET` ajoutée au manifeste. | `android/app/src/main/AndroidManifest.xml` |

### Limites actuelles de l'API

- La fiche producteur ne contient que : `id`, `code`, prénom, nom, `scoopId`, statut, CNI masquée. Village, âge, téléphone, sexe et organisation s'affichent donc vides ou par défaut.
- `PATCH /producers/:id` est un « stub » : il ne sauvegarde rien.
- Aucune route pour créer un producteur, ni pour les parcelles, les cultures, les photos CNI ou la synchronisation hors ligne.
- Le compte de démonstration est un admin sans SCOOP : le rôle « technicien » n'a pas été vu.
- Le code d'erreur d'une session invalide est `UNAUTHORIZED` (le guide annonce `UNAUTHENTICATED`) : l'app gère les deux.

### Ce qui reste à faire

**Côté mobile, dès que l'API le permet**
1. Créer un producteur (écran « Nouveau producteur ») : envoyer la fiche et les photos CNI.
2. Modifier et archiver un producteur : brancher `PATCH /producers/:id` quand il enregistrera vraiment.
3. Parcelles : envoyer le contour GPS et la surface relevés.
4. Cultures : envoyer les cultures déclarées par saison.
5. File d'envoi hors ligne : aujourd'hui « En attente d'envoi » et « À corriger » sont des données de démonstration. Il faut une vraie file (stockée sur l'appareil), envoyée au retour du réseau, avec gestion des conflits.
6. Réseau réel : remplacer la simulation « Réseau (simulation) » par la vraie détection de connexion.
7. Accueil, « À compléter » et « Carte » : brancher les compteurs et listes sur de vraies données (ils utilisent encore `MockData`).
8. Détail du producteur : afficher les champs réels (statut, CNI masquée), et la révélation de la CNI (`POST /producers/:id/cni/reveal`, avec motif) si le rôle le permet.
9. Permissions : adapter les écrans selon `permissions[]` de `/me` (accès refusé = `FORBIDDEN`).
10. Liste des producteurs : pagination par curseur côté interface (le curseur est déjà géré en lecture).
11. PIN : déjà conservé dans le stockage sécurisé (`flutter_secure_storage`) ; l'ancien PIN en clair de `shared_preferences` est migré au démarrage. Fait.
12. Tests : aucun test automatique à ce jour (client HTTP, renouvellement de session, cache).
13. Vérification sur appareils réels, Android et iOS, puis build iOS (non compilé depuis l'ajout du stockage sécurisé).

**À demander à l'équipe backend**
- Connexion technicien : l'API fournit téléphone + code à 5 chiffres puis téléphone + mot de passe. Reste côté API : révocation du jeton de renouvellement à la déconnexion, rotation, blocage après essais faux sur `technician/sign-in`.
- Une fiche producteur complète (village, âge, téléphone, sexe, organisation).
- Routes de création et de modification de producteur, de parcelles et de cultures.
- Routes de synchronisation hors ligne.
- Un compte de test avec le rôle technicien et une SCOOP.

### Mise à jour (compte technicien et CRUD producteurs)

Compte technicien : `fatou.sarr@cradesc.example` (rôle `technicien`, SCOOP `s1`).

**Branché**
- Nom de la SCOOP lu dans `GET /me` (`scoopName`), affiché dans le profil.
- Fiches complètes : téléphone, village, date de création, identifiant API (`Producer.remoteId`).
- Nouvelle fiche : enregistrée sur le téléphone, puis envoyée par `POST /producers` (prénom, nom, téléphone, village). Hors ligne ou refusée, elle reste « En attente d'envoi ».
- Modification : `PATCH /producers/:id` pour les fiches déjà connues de l'API.

**Pas encore branché**
- Parcelles (`/producers/:id/plots`) : l'API garde un point (`lat`, `lng`) et `areaHa`, notre relevé produit un contour. Format du contour à confirmer.
- Cultures (`/producers/:id/crops`) : pas de part en %, saison en texte (« 2025-2026 »).
- Archivage : l'API n'a que `DELETE`, pas d'état « archivé ».
- Photos CNI (`/cni/photo`, multipart) et révélation de la CNI.
- Renvoi automatique des envois en attente quand le réseau revient.
- Le contrat `docs/openapi.json` du dépôt API n'est pas à jour pour ces routes : les champs ont été vérifiés par les erreurs de validation.

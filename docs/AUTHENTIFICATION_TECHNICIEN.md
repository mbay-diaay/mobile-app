# Authentification du technicien (mobile)

Périmètre : connexion, session et déverrouillage uniquement. API : `https://api.mbaydiaay.com/v1` (surcharge : `--dart-define=API_URL=…`).

> Conception décidée ; le code du mobile suit cette page (activate / sign-in / refresh / me / logout branchés). Page publique : https://www.mbaydiaay.com/docs/authentification-mobile.html. Les points de la section « Points ouverts » ne sont **pas** tous réglés côté API.

## Parcours

```
Ouverture de l'app
├── Appareil neuf ─► Écran 01, trois modes
│     ├── « Première connexion » (défaut)  téléphone + code à 5 chiffres + nouveau mot de passe
│     │       POST /auth/technician/activate ─► jetons + utilisateur
│     ├── « Connexion »                    téléphone + mot de passe
│     │       POST /auth/technician/sign-in ─► jetons + utilisateur
│     └── « Compte e-mail (test) »         e-mail + mot de passe ─► écran 02 (code e-mail)
│             POST /auth/sign-in ─► POST /auth/otp/verify (renvoi : /auth/otp/resend)
│   puis GET /me ─► rôle ≠ technicien : accès refusé
│                └─► 03 création du PIN (local, trousseau) ─► 04 téléchargement de l'annuaire
├── Appareil déjà activé ─► écran PIN (3 erreurs = blocage temporaire) ─► accueil
├── Jeton d'accès expiré (401, il vaut 1 h) ─► POST /auth/refresh
│     ├── réussi ─► on continue
│     ├── 429 ou 5xx ─► session gardée, pas de déconnexion
│     ├── réseau coupé ─► session gardée, mode hors ligne
│     └── refus 401 ─► écran 01 en mode « Connexion » (reconnexion)
│           ├── même utilisateur ─► PIN et données locales conservés
│           └── autre utilisateur ─► révocation complète, parcours « appareil neuf »
└── Déconnexion volontaire ─► POST /auth/logout, puis effacement local
```

Un technicien dont le gestionnaire a généré un nouveau code est inactif et son ancien mot de passe est annulé : il repasse par « Première connexion ».

## Endpoints (préfixe `/v1`)

| Méthode | Route | Envoie | Reçoit | Erreurs |
|---|---|---|---|---|
| POST | `/auth/technician/activate` | `{phone, code, password}` | jetons + `user` | `INVALID_ACTIVATION`, `ACTIVATION_LOCKED`, `RATE_LIMITED` |
| POST | `/auth/technician/sign-in` | `{phone, password}` | jetons + `user` | `INVALID_CREDENTIALS`, `RATE_LIMITED` |
| POST | `/auth/refresh` | `{refreshToken}` | jetons | `REFRESH_INVALID`, `RATE_LIMITED` |
| GET | `/me` | jeton d'accès | rôle, SCOOP, permissions | `UNAUTHORIZED` |
| POST | `/auth/logout` | jeton d'accès | `{ok:true}` | |
| POST | `/auth/sign-in` | `{email, password}` | `challengeId` | `INVALID_CREDENTIALS` (ancien parcours) |
| POST | `/auth/otp/verify` | `{challengeId, code}` | jetons + `user` | `OTP_INVALID`, `OTP_EXPIRED`, `OTP_ATTEMPTS` |
| POST | `/auth/otp/resend` | `{challengeId}` | `challengeId` | `RATE_LIMITED` |

Réseau coupé : code local `NETWORK`.

Règles de saisie, identiques à l'API :
- Code d'activation : **5 chiffres**, valable 72 h, usage unique, bloqué après 5 essais faux.
- Mot de passe : 8 caractères au moins, une lettre et un chiffre.
- Jeton d'accès : 1 h. Jeton de renouvellement : 7 jours. Les deux sont dans le trousseau (`access_token`, `refresh_token`).

## Points ouverts

- Côté API : `/auth/logout` ne révoque pas le jeton de renouvellement (il reste valable jusqu'à 7 jours) ; pas de rotation à chaque renouvellement ; pas de blocage après essais faux sur `technician/sign-in` (seule la limite de 10 requêtes par minute s'applique).
- PIN oublié : aucun parcours prévu.
- Session hors ligne : 7 jours aujourd'hui, au-delà il faut se reconnecter.
- Revue Apple : prévoir un compte technicien déjà activé (le code d'activation expire en 72 h) et ses identifiants dans les notes de soumission.
- Un technicien créé par téléphone a l'e-mail technique `tel-…@technicien.mbaydiaay.local` : ne jamais l'afficher.

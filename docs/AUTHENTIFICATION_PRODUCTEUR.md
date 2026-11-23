# Authentification producteur (même app)

| | |
|---|---|
| **App** | `mbay-diaay-mobile` — écran de rôle → parcours producteur |
| **API cible** | `https://api.mbaydiaay.com/v1` |
| **Principe** | Téléphone + mot de passe — **pas d’e-mail** |

## Parcours

```
Splash
├── Rôle mémorisé « producteur » ─► Accueil auth producteur
├── Sinon ─► Choix de rôle (Technicien / Producteur)
└── Producteur
      ├── Inscription ─► POST /auth/producer/register → GET /me → Accueil producteur
      ├── Connexion ─► POST /auth/producer/sign-in → GET /me → Accueil producteur
      └── Déconnexion ─► logout + retour au choix de rôle
```

## Endpoints (à livrer côté API — Aldrich / back)

| Méthode | Route | Corps | Statut |
|---|---|---|---|
| POST | `/auth/producer/register` | `{phone, password, firstName, lastName, invitationCode?}` | **À créer** |
| POST | `/auth/producer/sign-in` | `{phone, password}` | **À créer** |
| POST | `/auth/refresh` | `{refreshToken}` | Existe |
| GET | `/me` | — | Existe |
| POST | `/auth/logout` | — | Existe |

## Écrans

- `lib/app/modules/activation/role_gate.dart`
- `lib/app/modules/producer_app/producer_welcome.dart`
- `lib/app/modules/producer_app/producer_login.dart`
- `lib/app/modules/producer_app/producer_register.dart`
- `lib/app/modules/producer_app/producer_home.dart`

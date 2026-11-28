# Phase 2 — livrables L3 → L4

| | |
|---|---|
| **Intervalle de build** | 20 novembre → 21 décembre 2026 |
| **Tests réels + formation admins CRADESC** | dès ~15 décembre → 29 décembre 2026 |
| **Réunion client (indicatif)** | entre le 29 décembre et le 11 janvier |
| **Formations coopératives** | janvier |

## Périmètre fonctionnel

Modules **tous fonctionnels** pour L3–L4 :

1. M1 Administratif  
2. M2 Commercial (stocks, ventes, crédits)  
3. M3 Compte d’exploitation  
4. M4 Agronomique  
5. M5 Cartographie  

Prototypes design **validés** en réunion client.

## Application mobile (une seule)

**Décision** : une seule app (`mbay-diaay-mobile`) avec écran de choix **Technicien / Producteur**.  
Le dépôt `mbay-diaay-producer` est conservé en proto/archive au cas où une 2ᵉ store serait exigée.

| Parcours | Auth |
|---|---|
| **Technicien** | Téléphone + code 5 chiffres (1ʳᵉ fois) puis téléphone + mot de passe — [AUTHENTIFICATION_TECHNICIEN.md](./AUTHENTIFICATION_TECHNICIEN.md) |
| **Producteur** | Inscription + connexion téléphone — [AUTHENTIFICATION_PRODUCTEUR.md](./AUTHENTIFICATION_PRODUCTEUR.md) (`/auth/producer/*` encore à livrer côté API) |

Swagger API : https://api.mbaydiaay.com/v1/docs

## Données M1 (base métier)

La base chargée pour la phase doit coller au MCD et couvrir au minimum : coopératives, GIE / organisations, producteurs, coordonnées et infos parcelles.

## Priorité immédiate (technicien)

1. Auth téléphone branchée sur l’API prod (`/auth/technician/activate`, `/auth/technician/sign-in`, refresh, `/me`).  
2. Nettoyage sécurité (PIN dans le trousseau, pas SharedPreferences).  
3. **Drift + outbox** : `lib/app/data/local/` + `OutboxService.flush()` à la synchro (créations producteurs hors ligne).  
4. Parcours producteur intégré dans la même app (`role_gate` + `producer_app/` ; endpoints `/auth/producer/*` encore à livrer côté API).

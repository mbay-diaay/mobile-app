# Audit écrans mobile — design + i18n (22 nov. 2026)

Périmètre : **technicien** + **producteur** (`producer_app/`).  
Objectif : challenger chaque écran ensuite, avec la langue FR/WO déjà branchée.

## Patterns attendus

| Élément | Règle |
|---|---|
| Couleurs / typo / motion | `AppColors.*`, `jakarta`/`display`/`mono`, `Motion.*` |
| CTA primaire | `SwipeCta` / `SwipeCta.dark` |
| Entrées / activ. | `StatusBarStyle` + forêt + `RisingSheet` |
| Shell | `DarkHeader` + `FloatingNavBar` + `ShellView.bottomInset` |
| i18n | Clés `.tr` — FR source, WO brouillon/pseudo (relecture humaine obligatoire) |

## Infra i18n (faite)

| Fichier | Rôle |
|---|---|
| `lib/app/i18n/messages_fr.dart` | Source FR |
| `lib/app/i18n/messages_wo.dart` | Pseudo + `reviewedWo` + `brouillonsWo` |
| `lib/app/i18n/app_translations.dart` | GetX `Translations` |
| `lib/app/services/locale_service.dart` | Persistance + bascule |
| Profil › Langue | Bascule FR ↔ WO |

**Règle wolof** (alignée web) : pas de traduction « définitive » sans locuteur. Les brouillons sont dans `brouillonsWo` ; les clés manquantes retombent sur le FR (lisible en démo — **pas** de pseudo `[~~~]`).

## Écrans déjà branchés i18n (v1)

- Choix de rôle  
- Welcome producteur  
- Shell producteur (accueil / onglets / profil)  
- Cultures › CTA enregistrer  
- Profil › langue  

À étendre écran par écran lors des challenges.

## Goulots / écarts design (priorisés)

| Priorité | Écran | Problème | Action |
|---|---|---|---|
| P0 | `crops.dart` | CTA custom ≠ SwipeCta | **Corrigé** → `SwipeCta.dark` |
| P0 | `producer_home` | Nav dupliquée | **Corrigé** → `FloatingNavBar.producerIcons` |
| P1 | `producer_space` (23) | Aperçu mock désaligné du vrai shell producteur | Réutiliser `producerHome` ou unifier |
| P1 | Auth tech (`phone`, `pin`, `sms`, `download`) | Strings FR hardcodées | Extraire clés `auth.tech.*` |
| P1 | Shell tech (`home`, `producers`, `todo`, `map`) | FR hardcodé + mock counters | i18n + données réelles |
| P1 | Survey / sync / commerce / correction | FR hardcodé | Challenge par écran |
| P2 | `survey.dart`, `map_tab`, `revoked` | Couleurs littérales | Tokens `AppColors` |
| P2 | Login/register producteur | Retours `IconButton` Material | `SquareIconButton.onDark` |
| P2 | Placeholders parcelles / calendrier producteur | Contenu vide | Maquettes offline mini |

## Checklist challenge (ordre proposé)

### Commun
- [ ] Splash  
- [ ] Role gate (déjà i18n)  

### Technicien
- [ ] 01 Phone / modes  
- [ ] 02 OTP e-mail  
- [ ] 03 PIN  
- [ ] 04 Download  
- [ ] 05 Unlock / 06 Blocked / 25 Revoked  
- [ ] 07–08 Accueil  
- [ ] 09 Producteurs  
- [ ] 10 Fiche  
- [ ] 11–12 Nouveau  
- [ ] 13 Carte  
- [ ] 14–19 Survey + cultures + calendrier  
- [ ] 20–22 Sync / todo  
- [ ] 23 Espace producteur (aperçu)  
- [ ] 24 Profil  
- [ ] Commerce vente / charge  
- [ ] Correction  

### Producteur
- [ ] Welcome (déjà i18n + charte)  
- [ ] Login / Register (charte OK, i18n partielle)  
- [ ] Home / Parcelles / Calendrier / Profil (charte + i18n v1)  
- [ ] Correction depuis home  

Pour chaque écran : **design** (SwipeCta, tokens, motion) → **copy FR** → **brouillon WO** → **données API/mock**.

## Comment tester la langue

1. Seed local ou aperçu producteur.  
2. Profil › **Langue** (technicien) — bascule FR/WO.  
3. Repasser par le choix de rôle pour voir les clés producteur en WO.

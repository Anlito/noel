# Évolution multi-familles — procédure pour Thomas

Le code est préparé ; la base de production n’a pas été modifiée par l’assistant.
La suppression des cadeaux est déjà fonctionnelle : aucun ancien script de suppression
n’est à relancer. Ne pas réexécuter `schema.sql`.

## Fonctionnement

- Un compte global, avec identifiant stable distinct du prénom affiché. Les comptes
  actuels gardent leur identifiant habituel, leur UUID et leur code personnel.
- Une liste globale par adulte et par enfant. Le propriétaire choisit les familles
  qui la voient ; rejoindre une famille ne partage jamais automatiquement les enfants.
- Une réservation unique par cadeau. Un membre extérieur est désigné anonymement.
- Rôles, invitations, repas, participants et tirages Secret Santa propres à la famille.
- Le dernier administrateur ne peut pas être retiré. Retirer un membre ne supprime pas
  son compte. Un administrateur familial ne réinitialise pas les comptes globaux.
- La famille actuelle conserve sa boule photo. Les autres choisissent une palette
  et une boule neutre ; les textes et photos ne sont pas personnalisables.
- La récupération utilise une adresse facultative vérifiée. Sans adresse, récupération
  manuelle par l’opérateur après vérification de l’identité, jamais par le simple code famille.

## Ordre de déploiement

1. Faire une sauvegarde Supabase complète et restaurable (base **et Auth**). Répéter
   d’abord toute la procédure sur une copie du projet. Ne pas tester avec des identités
   réelles ou envoyer des e-mails de test aux membres.
2. Exécuter `supabase/migrations/2026102801_multifamily.sql` dans le SQL Editor.
   Il crée un schéma privé neuf, sans importer ni modifier les données actuelles.
   Il s’exécute une seule fois : si ce schéma existe déjà, identifier son état avant toute suite.
   `select public.mf_status();` doit retourner `enabled: false`.
3. Déployer `family-auth` (avec son fichier `v2.ts`), `family-account` et la nouvelle
   version de `admin-set-password`. Le fichier `supabase/config.toml` documente le
   contrôle JWT : `family-auth` et `family-account` sont publics, mais chaque action
   sensible est contrôlée dans le code ; `admin-set-password` reste protégé.
   La fonction `family-auth` continue à utiliser l’ancien parcours tant que le mode
   multi-familles n’est pas activé. Conserver `FAMILY_INVITE_CODE` pendant cette période.
4. Pour les e-mails, configurer côté serveur `RESEND_API_KEY`, `RECOVERY_FROM_EMAIL`
   (adresse d’un domaine vérifié chez Resend), et `APP_URL=https://anlito.github.io/noel/`.
   Les secrets Supabase restent exclusivement côté serveur. Sans ces trois paramètres,
   la récupération retourne un message d’indisponibilité ; elle ne prétend pas envoyer de mail.
5. Publier tous les fichiers web ensemble : `index.html`, `legacy.html`, `avatars.js`,
   `multi-boot.js`, `multi-app.js`, `multi-family.css`, `legacy-guard.js` ainsi que les assets
   existants. Sans activation, l’accueil renvoie vers `legacy.html`, avec la même session.
6. Sur la copie, exécuter `supabase/migrations/2026102802_activate_multifamily.sql`.
   Il verrouille les tables de l’application, importe les données à jour, vérifie les
   comptes et comptages, révoque les anciens accès globaux puis active le nouveau site
   dans une transaction unique. Une erreur annule toute la bascule.
7. Valider avec plusieurs comptes sur cette copie : ancien code de connexion, création/
   ajout de famille, partage explicite adulte/enfant, réservation croisée, anonymat extérieur,
   retrait d’un accès partagé, suppression cadeau/enfant, repas et tirages existants,
   lien de récupération réellement reçu, expiré et déjà utilisé.
8. Après validation sur copie, répéter les étapes de préparation/déploiement en production,
   puis activer pendant un court créneau annoncé. Demander aux membres de rafraîchir
   les onglets ouverts. Les anciennes pages ne doivent plus accéder aux données globales.

## Contrôles avant activation

Les migrations enfants, gestionnaires, Secret Santa enfants et organisateurs doivent
déjà exister. Le partage des réservations historique est facultatif ; s’il existe, il est
importé. Les tirages adultes anciens sont conservés ; deux modèles de tirage contradictoires
font échouer la bascule plutôt que de choisir silencieusement.

Détecter les identifiants historiques en doublon avant activation :

```sql
select lower(normalize(trim(display_name),NFKC)) identifiant, array_agg(id) comptes
from public.profiles group by 1 having count(*) > 1;
```

Un doublon demande un choix d’identifiant avec les personnes concernées, sans recréer
leur compte. Les champs cadeaux doivent respecter les limites existantes (titre 120,
description 1000, lien 2048). Les anciens liens non HTTP(S) ne sont jamais rendus cliquables :
la migration les garde dans la description et s’arrête si cela dépasse sa limite.

Comparer les comptages et les attributions sur la copie, puis sur la production.
Vérifier explicitement les droits `anon` et `authenticated` des anciennes tables et
fonctions. Le schéma `noel_private` ne doit **pas** être ajouté aux schémas exposés de l’API.

## Revenir en arrière

Avant activation, le site historique reste la référence. Après activation, les tables
historiques sont figées et conservées, mais les nouvelles modifications vivent dans
le schéma privé. **Ne pas repasser simplement `enabled` à false** : cela masquerait les
changements récents. Un retour implique de réconcilier ces modifications ou de restaurer
la sauvegarde avec une décision explicite sur les écritures postérieures.

## Support et tests

`supabase/support-reset.mjs` est réservé à l’opérateur du projet. Il exige une vérification
d’identité, un motif d’audit, une clé serveur et un nouveau code transmis hors du site.
Il invalide les sessions. Ne jamais partager la clé serveur ni enregistrer le nouveau code
dans un ticket, un journal ou une commande versionnée.

Tests locaux : Node 24+, `npm ci`, `npx playwright install chromium`, puis `npm test`.
`CHROME_PATH` peut désigner un Chrome existant et `NOEL_SCREENSHOTS` le dossier de captures.
Les tests SQL utilisent PostgreSQL embarqué via PGlite avec une représentation du schéma
historique ; les tests navigateur exécutent ces vraies fonctions SQL avec une session simulée.
Les tests Edge simulent Auth et l’envoi de mail : ils ne remplacent pas les validations
sur une copie Supabase et ne prouvent pas la délivrabilité des e-mails.

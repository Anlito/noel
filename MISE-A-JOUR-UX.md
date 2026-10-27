# Mise à jour UX — 27 octobre 2026

L'application existante est conservée : navigation, connexion familiale, enfants,
partage de gestion, repas, Secret Santa et administration.

## Action dans Supabase

Dans **SQL Editor**, exécuter le contenu de `migration-modification-cadeaux.sql`.
La migration de partage des listes d'enfants doit déjà être installée
(`migration-partage-listes-enfants.sql`). Le nouveau script peut être réexécuté.

Cette fonction autorise le parent et les gestionnaires partagés à modifier
uniquement le titre, la description et le lien d'un cadeau de l'enfant indiqué.
Elle vérifie l'identité, les droits sur l'enfant et l'appartenance du cadeau.
Elle ne change ni le propriétaire, ni les réservations, ni les règles RLS.
Sans ce script, la modification des cadeaux personnels fonctionne, mais celle
des cadeaux d'enfants renvoie une erreur et le formulaire reste ouvert.

Ne pas réexécuter `schema.sql` : il s'agit du schéma initial, pas d'une migration.

## Vérifications effectuées

- Chrome avec fenêtres de 360, 412 et 1 280 pixels, simulation tactile sur mobile.
- Profil : ouverture, fermeture extérieure, choix d'avatar, déconnexion.
- Recherche sans distinction de casse et d'accents, sections exclusives et liste personnelle en premier.
- Bandeau limité à l'accueil, titres H1 et navigation vers enfants, repas, Secret Santa et administration.
- Ajout de cadeau, formulaire fermé après ajout, formulaire ouvert pour une liste vide.
- Modification personnelle et appel de la fonction dédiée pour une liste partagée.
- Descriptions longues dépliables, descriptions courtes sans bouton.
- Actions de gestion absentes des listes consultées ; affichage de la réservation existante.
- Absence de débordement horizontal et d'erreurs JavaScript pendant ces parcours.
- Fonction SQL exécutée sur un moteur PostgreSQL local : parent et gestionnaire autorisés ; autre membre, visiteur anonyme, accès révoqué et mauvais cadeau refusés ; titre vide refusé ; réservations conservées.

Les parcours utilisent des données fictives. Aucun cadeau, compte ou repas réel
n'a été créé ou modifié. La base Supabase en production et un appareil Android
physique n'ont pas été testés. Les règles de confidentialité existantes ont été
inspectées dans les scripts du dépôt, sans présumer de leur installation réelle.

## Suppression : comportement historique conservé

Les appels de suppression existants sont conservés avec confirmation.
Le schéma initial contient le trigger `no_gift_delete`, qui interdit toute
suppression pour protéger les surprises. S'il est toujours installé, Supabase
refusera la suppression ; cette mise à jour ne le retire pas. Ne pas enlever ce
verrou sans revoir les garanties de confidentialité.

## Contrôle après installation

Avec un compte parent, modifier un cadeau d'enfant ; refaire le même contrôle
avec un gestionnaire partagé. Vérifier qu'un autre adulte ne voit aucun bouton
de gestion pour cet enfant. Depuis le compte destinataire, vérifier que les
réservations restent masquées ; depuis un autre compte autorisé, vérifier leur
affichage et l'annulation de sa propre réservation.

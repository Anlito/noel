# Activer la suppression des idées cadeaux

Dans Supabase, ouvrir **SQL Editor**, coller le contenu de
`migration-suppression-cadeaux.sql`, puis cliquer sur **Run**.
Les migrations enfants et partage des listes doivent déjà être installées.
Ne pas relancer `schema.sql`.

Cette migration est nécessaire : le schéma initial bloque les suppressions.
Sans elle, le nouveau site conserve le cadeau et affiche un message indiquant
que la suppression doit être activée.

Le script remplace ce blocage global par une fonction contrôlée :

- Suppression d'un cadeau personnel réservée à son propriétaire.
- Suppression d'un cadeau d'enfant réservée au parent ou gestionnaire partagé.
- Suppressions directes de la table toujours interdites aux comptes du site.
- Les réservations associées sont supprimées dans la même transaction, sans
  retourner leur existence, leur nombre ou leur auteur au destinataire.
- Aucun changement aux règles de lecture des réservations.
- Compatibilité avec l'ancien appel de suppression des cadeaux d'enfants.

Un cadeau réservé et un cadeau non réservé ont le même résultat de suppression.
La fenêtre de confirmation ne mentionne jamais le statut de réservation.

La migration a été testée sur un moteur PostgreSQL local, y compris les accès
refusés, le retrait de partage, les suppressions réservées/non réservées et sa
réexécution. Elle n'a pas été exécutée sur la base Supabase de production.

Après installation, tester la suppression d'une idée personnelle, puis d'une
idée d'enfant depuis le parent et un gestionnaire partagé. Vérifier que les
autres membres ne disposent d'aucun bouton de gestion.

Cette notice remplace la note historique sur le verrou de suppression dans
`MISE-A-JOUR-UX.md`. Les scripts des anciennes versions restent dans le dépôt
pour l'historique ; seul ce nouveau script active la correction.

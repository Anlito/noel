# Reprise — Lé Kdo 2 Noyel

## Évolution multi-familles — 28 octobre 2026

Implémentation préparée avec listes adultes/enfants communes, publication explicite
par famille, réservation globale et anonymat extérieur, rôles et invitations par famille,
repas et Secret Santa cloisonnés, thèmes neutres et récupération par e-mail vérifié.
Les comptes et codes personnels historiques restent les mêmes ; le prénom historique
devient l’identifiant stable, distinct du prénom affiché modifiable.

IMPORTANT : la base Supabase de production n’a pas été modifiée par l’assistant.
La publication du code ne vaut pas activation : l’accueil conserve l’application
historique dans `legacy.html` tant que `mf_status().enabled` n’est pas vrai.
Voir `INSTALLATION-MULTIFAMILLES.md` : préparation SQL, déploiement des trois fonctions
Edge et configuration des e-mails, répétition sur copie, puis activation transactionnelle.
Ne pas exécuter l’activation avant ces étapes. Ne pas simplement désactiver le drapeau
après la bascule : les écritures nouvelles doivent être réconciliées pour un retour arrière.

Tests locaux : fonctions SQL réelles sur PostgreSQL embarqué (PGlite), parcours navigateur
sur 390/820/1180/1440 pixels avec sessions simulées, fonctions Edge avec Auth et mail simulés.
Les tests de production, le comportement réel Supabase Auth et la réception des e-mails
restent à valider sur copie avant activation.

## Suppression des cadeaux : fonctionnement confirmé

Le 28 octobre 2026, Thomas indique avoir mis à jour la base de données et confirme
que la suppression d'un cadeau personnel ou d'un enfant fonctionne.
Le rappel d'activation de la suppression est donc clos. Ne pas lui redemander
d'exécuter le script comme si cette intervention était toujours en attente.

Cette confirmation vient de Thomas ; l'assistant n'a pas effectué les tests sur
la base de production. Le nom exact des scripts exécutés n'a pas été précisé.

## Vérifications non encore confirmées

- Suppression d'un cadeau d'enfant depuis un compte gestionnaire partagé.
- Modification d'un cadeau d'enfant, notamment par un gestionnaire partagé
  (`migration-modification-cadeaux.sql` : installation non explicitement confirmée).
- Refus des actions de gestion aux comptes non autorisés et confidentialité des
  réservations pour leur destinataire après la mise à jour.

Ne pas relancer `schema.sql`. Les informations d'installation restent disponibles
dans `INSTALLATION-SUPPRESSION-CADEAUX.md` pour référence historique.

## Nouvelle fonctionnalité — réservations partagées

« Mes cadeaux à offrir », installation sur l'écran d'accueil et aide à la
connexion ajoutées le 28 octobre 2026. Une nouvelle action technique reste à
réaliser pour le partage : exécuter `migration-partage-reservations.sql` dans
Supabase (non exécuté par l'assistant), puis vérifier avec deux comptes réels
que le lecteur ne voit ni ses cadeaux ni ceux de ses enfants, et que le retrait
d'accès bloque la consultation. Voir `INSTALLATION-PARTAGE-RESERVATIONS.md`.
La vue des réservations personnelles fonctionne sans cette nouvelle migration.
Ne pas confondre ce script avec ceux de suppression déjà validés par Thomas.

### Ajustements précédents

Accueil « Cher Père Noël… », champ « Trouver une liste », sous-titres raccourcis,
message pour les listes vides, retrait du message de surprise de la liste personnelle.

# Cadeaux à offrir, partage et installation — 28 octobre 2026

## Fonctionnement

Le menu « Mes cadeaux à offrir » regroupe les réservations de l'utilisateur par
destinataire, avec description, lien boutique et annulation avec confirmation.
Cette vue fonctionne avec les tables et règles existantes.

Le partage se fait avec un membre déjà inscrit. Le lecteur ne peut ni modifier
les réservations de l'auteur, ni annuler ses réservations, ni gérer ses partages.
Les cadeaux pour le lecteur et ses enfants sont filtrés côté serveur, y compris
les titres, liens, descriptions et décomptes de ces cadeaux. L'accès est vérifié
à chaque lecture et peut être retiré par l'auteur. Un contenu déjà consulté ne
peut pas être effacé rétroactivement de la mémoire d'une personne.

## Action Supabase à réaliser

Dans Supabase → SQL Editor, exécuter **`migration-partage-reservations.sql`**.
Le script suppose que `profiles`, `gifts`, `reservations` et `children` existent.
Il est réexécutable. Ne pas relancer `schema.sql`.

Ce nouveau script n'a pas été exécuté sur la base de production par l'assistant.
Sans lui, la vue des réservations personnelles fonctionne ; le bloc de partage
indique que la fonctionnalité n'est pas encore activée.

Les migrations de suppression précédentes ne sont pas à refaire : Thomas a
confirmé leur bon fonctionnement le 28 octobre.

## Installation sur téléphone ou tablette

- Icône de cadeau et manifeste adaptés au chemin `/noel/` de GitHub Pages.
- Bouton « Installer l'application » dans le menu, proposition discrète sur les
  appareils compatibles, fermeture mémorisée pendant 30 jours sur cet appareil.
- Le navigateur ouvre son dialogue d'installation lorsqu'il le permet ; sinon
  une aide indique comment ajouter l'application à l'écran d'accueil.
- Sur iPhone/iPad, l'installation passe par le menu de partage du navigateur.
- L'application installée nécessite toujours Internet. Le service worker ne met
  en cache ni les listes, ni les réservations, ni les réponses Supabase. La
  conservation de session de connexion existante reste inchangée.

Sources d'implémentation : [installation PWA](https://web.dev/learn/pwa/installation)
et [invite d'installation](https://web.dev/learn/pwa/installation-prompt).
Icônes dérivées des illustrations Twemoji déjà utilisées (CC BY 4.0).

## Connexion

En cas de prénom ou code incorrect : « Connexion impossible. Vérifie ton prénom
et ton code personnel. » Puis « Pas encore de compte ? Créer mon compte ».
Le lien conserve le prénom saisi, vide les codes et ouvre la création de compte.
Le message n'affirme pas qu'un compte n'existe pas et les erreurs de service ne
sont pas présentées comme des erreurs d'identifiants.

## Vérifications réalisées

- PostgreSQL local : RLS des partages, refus d'usurpation, lecteur en lecture
  seule, tiers/anonyme refusés, retrait d'accès, cadeaux pour le lecteur et ses
  enfants masqués, même si une ancienne ligne a un propriétaire incohérent.
- Interface Chrome à 360, 820 et 1 280 pixels avec données fictives : regroupement,
  annulation et conservation d'une réservation, ajout/retrait du partage, vue
  reçue sans boutons de gestion, fonctionnement sans la nouvelle migration.
- Installation : manifeste et icônes, simulation d'acceptation/refus de l'invite,
  aide manuelle iOS, fermeture persistante de la proposition d'installation.
- Service worker réel sur serveur local : portée limitée à `/noel/`, écran hors
  connexion sans données privées et absence de cache de données familiales.
- Échec de connexion puis passage à la création de compte avec prénom conservé.

Les opérations Supabase réelles et l'installation sur appareils Android/iOS
physiques n'ont pas été testées. Après migration, contrôler le partage avec deux
comptes réels, puis retirer l'accès et vérifier que la lecture est refusée.

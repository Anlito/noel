# Reprise — Lé Kdo 2 Noyel

## Ajustements suivants — codes famille et bandeau

Thomas demande un code famille de quatre chiffres au maximum, le nom de famille dans
le surtitre du bandeau (retiré à côté du menu) et une année réglable par l’admin de famille.
Les migrations incrémentales 2026102803_short_family_codes.sql et 2026102804_family_year.sql
sont préparées et testées. Leur exécution par Thomas reste à confirmer. Ne pas annoncer
les codes courts et le réglage d’année comme activés avant cette confirmation.
Le site reste compatible avec la base avant ces deux migrations ; il détecte leurs capacités
via mf_status. Le nom du bandeau et le retrait du nom à côté du menu sont des changements web.
L’entrée « Mon compte » du menu affiche désormais l’avatar actuel du compte.
Le doublon du nom de famille sous « Cher Père Noël… », absent de l’ancien accueil,
est également retiré à la demande de Thomas.
Les codes existants sont convertis sans recréer les familles ni modifier les listes/comptes.
L’année concerne l’affichage de chaque famille ; sa modification n’efface aucun cadeau ni tirage.

## Évolution multi-familles — 28 octobre 2026

Implémentation préparée avec listes adultes/enfants communes, publication explicite
par famille, réservation globale et anonymat extérieur, rôles et invitations par famille,
repas et Secret Santa cloisonnés, thèmes neutres et récupération par e-mail vérifié.
Les comptes et codes personnels historiques restent les mêmes ; le prénom historique
devient l’identifiant stable, distinct du prénom affiché modifiable.

Activation de production confirmée par Thomas le 28 octobre 2026, après déploiement
manuel des trois fonctions Edge et exécution des deux scripts SQL. Thomas a explicitement
choisi de poursuivre sans sauvegarde : le site n’est pas encore annoncé officiellement et
les listes ne sont pas encore saisies selon lui. Ne pas redemander de sauvegarde ni relancer
les migrations déjà exécutées.

Vérification assistant en lecture seule : mf_status retourne enabled=true, version=2 ;
la nouvelle connexion s’affiche à la racine du site sur mobile, sans erreur JavaScript.
La connexion avec un ancien compte et les données authentifiées restent à vérifier par Thomas.

Pas de domaine d’expédition : les e-mails de récupération sont reportés. Le parcours visible
oriente vers Thomas pour une récupération manuelle après vérification d’identité. Les formulaires
d’envoi/vérification e-mail sont masqués par défaut. Pour une future activation des e-mails,
configurer les secrets Resend et définir window.NOEL_EMAIL_RECOVERY_ENABLED=true dans config.js,
puis tester la réception réelle avant de l’annoncer. Les fonctions serveur sont conservées.
La récupération manuelle opérateur utilise supabase/support-reset.mjs avec clé serveur locale,
jamais un droit de réinitialisation accordé aux administrateurs de famille.

Les tests SQL, Edge et navigateur sont locaux/automatisés ; ne pas les présenter comme des
vérifications réalisées avec les comptes réels de production. Les tests de réception e-mail
ne sont pas applicables tant que l’envoi est reporté.

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

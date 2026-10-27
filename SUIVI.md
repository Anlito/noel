# Reprise — Lé Kdo 2 Noyel

## Action technique en attente pour Thomas

Note enregistrée le 27 octobre 2026, pour la reprise prévue le 28 octobre.
À rappeler lors de la prochaine session technique sur le projet.

**La suppression des idées cadeaux nécessite encore une intervention Supabase.**
Le code et la confirmation stylisée sont publiés, mais le script SQL n'a pas
été exécuté par l'assistant sur la base de production. Son installation reste
à vérifier par Thomas ; la personne chargée de l'UX ne gère pas cette opération.

1. Consulter `INSTALLATION-SUPPRESSION-CADEAUX.md`.
2. Vérifier que les migrations enfants et partage sont déjà installées.
3. Exécuter `migration-suppression-cadeaux.sql` dans Supabase → SQL Editor → Run.
4. Vérifier les suppressions personnelles et celles des enfants par le parent
   et un gestionnaire partagé ; contrôler les refus pour les autres comptes.
5. Vérifier que les réservations restent secrètes pour leur destinataire.
6. Mettre à jour cette note avec le résultat et la date d'exécution.

Ne pas relancer `schema.sql`. Le nouveau script maintient l'interdiction des
suppression directes et utilise une fonction qui vérifie les droits, sans
révéler si le cadeau était réservé.

Vérifier également `migration-modification-cadeaux.sql` si la modification des
cadeaux d'enfants n'est pas encore activée (migration précédente, exécution non
confirmée dans cette conversation).

## Dernier ajustement UX

Retrait du surtitre « On se retrouve » sur la page « Les repas de famille ».

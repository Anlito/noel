# Activer l'accès familial sans e-mail

Le site utilise désormais la fonction Edge **family-auth**. Tant qu'elle n'est pas déployée, les nouvelles connexions par prénom ne fonctionneront pas. Les sessions déjà ouvertes peuvent rester actives.

## 1. Choisir le code d'invitation
Choisir un code familial difficile à deviner (12 caractères ou plus), à communiquer seulement aux proches. Il est **différent** des codes personnels.

## 2. Configurer Supabase
Dans **Edge Functions → Secrets**, ajouter :
- Nom : `FAMILY_INVITE_CODE`
- Valeur : votre code d'invitation familial (ne pas le publier sur GitHub).

Les secrets `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` doivent aussi être disponibles côté serveur (généralement fournis automatiquement).

## 3. Créer et déployer la fonction
Dans **Edge Functions**, créer une fonction nommée exactement `family-auth`. Remplacer son `index.ts` par le contenu de `supabase/functions/family-auth/index.ts`, puis déployer.

Dans **Settings**, désactiver **Verify JWT with legacy secret** : la fonction doit accepter les demandes d'inscription sans session. Elle contrôle elle-même le code d'invitation, et vérifie le code personnel lors de la connexion. Le code d'invitation n'est jamais exposé dans le navigateur.

## 4. Comptes existants
Les membres déjà inscrits peuvent se connecter avec leur **prénom actuel** et leur **ancien mot de passe** (qui devient leur code personnel). Les prénoms doivent être uniques, sans distinction entre majuscules et minuscules.

Un membre ayant oublié son code peut demander au super-admin de le changer dans l'onglet Comptes (fonction `admin-set-password`).

## 5. Vérifier
1. Créer un compte test avec un prénom inédit, un avatar, un code personnel d'au moins 8 caractères et le code d'invitation.
2. Se déconnecter et se reconnecter avec prénom + code personnel.
3. Vérifier que le prénom et l'avatar sont bien affichés.

## Sécurité
Ne pas désactiver les règles RLS des tables. Ne jamais mettre la clé `service_role` dans le HTML. Le code personnel est géré par Supabase Auth, sans stockage en clair dans les tables. Le code d'invitation est conservé dans un secret serveur.

Pour une application familiale, ne pas partager le code d'invitation publiquement. Les tentatives de connexion sont également soumises aux limites de Supabase Auth.

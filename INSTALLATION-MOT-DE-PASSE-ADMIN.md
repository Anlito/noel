# Activer le changement de mot de passe administrateur

Le site GitHub Pages ne doit jamais contenir la clé `service_role` de Supabase.

## Déploiement

1. Dans Supabase Dashboard, ouvrir **Edge Functions**.
2. Créer une fonction nommée exactement **admin-set-password**.
3. Coller le contenu de `supabase/functions/admin-set-password/index.ts` depuis ce dépôt.
4. Déployer la fonction avec **Verify JWT** activé. Si le tableau de bord propose une option de vérification JWT, elle doit rester activée. Pour les projets utilisant les nouvelles clés publishable, la fonction effectue aussi elle-même la vérification de la session et du rôle super-admin.
5. Vérifier que les secrets serveur `SUPABASE_URL`, `SUPABASE_ANON_KEY` et `SUPABASE_SERVICE_ROLE_KEY` sont disponibles dans l'environnement Edge Functions (Supabase les fournit habituellement par défaut).
6. Dans l'application, se connecter comme super-admin, puis **Comptes → Changer le mot de passe**.

## Sécurité
- La fonction authentifie le demandeur via `auth.getUser()`.
- Elle vérifie l'appartenance à `santa_admins` côté serveur.
- Elle modifie le mot de passe via l'API Admin Auth, jamais depuis le navigateur.
- Elle n'enregistre ni ne renvoie le mot de passe.
- Aucun nouveau script SQL n'est nécessaire pour cette fonctionnalité.

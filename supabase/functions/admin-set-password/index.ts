// Supabase Edge Function: admin-set-password
// Déployer avec vérification JWT activée. Ne jamais exposer SERVICE_ROLE_KEY côté navigateur.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const headers = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json",
  };
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
  const reply = (status: number, message: string) =>
    new Response(JSON.stringify({ message }), { status, headers });
  if (req.method !== "POST") return reply(405, "Méthode non autorisée");
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return reply(500, "Configuration serveur manquante");
  const authorization = req.headers.get("Authorization") || "";
  if (!authorization.startsWith("Bearer ")) return reply(401, "Connexion requise");
  const caller = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: auth, error: authError } = await caller.auth.getUser();
  if (authError || !auth.user) return reply(401, "Session invalide");
  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const {data:state,error:stateError}=await admin.rpc("mf_status");
  if(state?.enabled || (stateError && !["PGRST202","42883"].includes(stateError.code)))return reply(403,"Utilise la récupération par e-mail ou contacte le support. Un administrateur de famille ne peut pas modifier le code d'un compte.");
  const { data: allowed, error: accessError } = await admin.from("santa_admins").select("user_id").eq("user_id", auth.user.id).maybeSingle();
  if (accessError || !allowed) return reply(403, "Réservé au super-administrateur");
  let payload: { user_id?: string; password?: string };
  try { payload = await req.json(); } catch { return reply(400, "Requête invalide"); }
  const userId = payload.user_id;
  const password = payload.password;
  if (!userId || !/^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(userId)) return reply(400, "Compte invalide");
  if (typeof password !== "string" || password.length < 8 || password.length > 128)
    return reply(400, "Le mot de passe doit comporter entre 8 et 128 caractères");
  const { data: target, error: targetError } = await admin.from("profiles").select("id").eq("id", userId).maybeSingle();
  if (targetError || !target) return reply(404, "Compte introuvable");
  const { error } = await admin.auth.admin.updateUserById(userId, { password });
  if (error) return reply(400, "Impossible de modifier le mot de passe : " + error.message);
  return reply(200, "Mot de passe mis à jour");
});

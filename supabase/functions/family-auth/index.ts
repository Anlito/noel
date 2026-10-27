import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS","Content-Type":"application/json"};
const reply=(status:number,message:string,extra:Record<string,unknown>={})=>new Response(JSON.stringify({message,...extra}),{status,headers:cors});
const normalize=(s:string)=>s.trim().normalize("NFKC").toLocaleLowerCase("fr");
const validName=(s:string)=>s.length>=2&&s.length<=60&&!/[<>@]/.test(s);
Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers:cors});
 if(req.method!=="POST")return reply(405,"Méthode non autorisée");
 const url=Deno.env.get("SUPABASE_URL"),anon=Deno.env.get("SUPABASE_ANON_KEY"),service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),invitation=Deno.env.get("FAMILY_INVITE_CODE");
 if(!url||!anon||!service||!invitation)return reply(503,"Configuration de l'accès familial incomplète");
 let body:Record<string,unknown>;try{body=await req.json()}catch{return reply(400,"Requête invalide")}
 const action=body.action,firstName=typeof body.name==="string"?body.name.trim():"",code=typeof body.code==="string"?body.code:"";
 if(!validName(firstName)||code.length<8||code.length>128)return reply(400,"Prénom invalide ou code personnel trop court (8 caractères minimum)");
 const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:profiles,error:searchError}=await admin.from("profiles").select("id,display_name").ilike("display_name",firstName);
 if(searchError)return reply(500,"Impossible de rechercher le membre");
 const matching=(profiles||[]).filter(p=>normalize(p.display_name)===normalize(firstName));
 if(action==="signup"){
  if(body.invitation!==invitation)return reply(403,"Code d'invitation incorrect");
  if(matching.length)return reply(409,"Ce prénom est déjà utilisé. Choisis un prénom distinct.");
  const avatar=typeof body.avatar==="string"?body.avatar:"🎅";
  const email="famille-"+crypto.randomUUID()+"@accounts.noel.invalid";
  const {data,error}=await admin.auth.admin.createUser({email,password:code,email_confirm:true,user_metadata:{display_name:firstName,avatar}});
  if(error)return reply(400,"Impossible de créer le compte : "+error.message);
  return reply(200,"Compte créé. Connecte-toi avec ton prénom et ton code personnel.");
 }
 if(action==="login"){
  if(matching.length!==1)return reply(401,"Prénom ou code incorrect");
  const {data:authUser,error:userError}=await admin.auth.admin.getUserById(matching[0].id);
  if(userError||!authUser.user?.email)return reply(401,"Prénom ou code incorrect");
  const auth=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data,error}=await auth.auth.signInWithPassword({email:authUser.user.email,password:code});
  if(error||!data.session)return reply(401,"Prénom ou code incorrect");
  return reply(200,"Connexion réussie",{session:data.session});
 }
 return reply(400,"Action inconnue");
});

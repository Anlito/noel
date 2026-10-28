import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
export async function v2Auth(req: Request, body: Record<string, unknown>, admin: any, url: string, anon: string, headers: Record<string,string>) {
 const reply=(status:number,message:string,extra={})=>new Response(JSON.stringify({message,...extra}),{status,headers});
 const rpc=async(action:string,data:any)=>{const r=await admin.rpc('mf_service',{p_action:action,p_data:data});if(r.error)throw r.error;return r.data;};
 const login=String(body.name||'').trim().normalize('NFKC'),password=String(body.code||'');
 const ip=(req.headers.get('x-forwarded-for')||'unknown').split(',')[0];
 const ipBytes=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(ip));
 const ipHash=Array.from(new Uint8Array(ipBytes),x=>x.toString(16).padStart(2,'0')).join('');
 if(!await rpc('limit',{key:'auth-ip:'+ipHash,max:40,seconds:900}))return reply(429,'Trop de tentatives. Réessaie dans quelques minutes.');
 const key=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(login.toLocaleLowerCase('fr')+'|'+ip));
 const hash=Array.from(new Uint8Array(key),x=>x.toString(16).padStart(2,'0')).join('');
 if(!await rpc('limit',{key:'auth:'+hash,max:20,seconds:900}))return reply(429,'Trop de tentatives. Réessaie dans quelques minutes.');
 if(login.length<2||login.length>60||password.length<8||password.length>128)return reply(400,'Identifiant ou code personnel invalide (8 caractères minimum).');
 const account=await rpc('resolve',{login});
 if(body.action==='signup'){
  if(!/^[a-zA-Z0-9_.-]{3,40}$/.test(login))return reply(400,'Identifiant : 3 à 40 lettres sans accent, chiffres, points ou tirets.');
  if(account)return reply(409,'Cet identifiant est déjà utilisé.');
  const name=String(body.display_name||login).trim();
  if(name.length<1||name.length>60)return reply(400,'Prénom invalide.');
  const email='famille-'+crypto.randomUUID()+'@accounts.noel.invalid';
  const {data,error}=await admin.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{display_name:name,avatar:String(body.avatar||'🎅').slice(0,32)}});
  if(error||!data.user)return reply(400,'Impossible de créer le compte.');
  try{await rpc('register',{user_id:data.user.id,login});}catch{await admin.auth.admin.deleteUser(data.user.id);return reply(409,'Cet identifiant vient d’être choisi. Essaie un autre identifiant.');}
  return reply(200,'Compte créé. Tu peux maintenant te connecter, puis rejoindre ou créer une famille.');
 }
 if(body.action!=='login')return reply(400,'Action inconnue');
 if(!account)return reply(401,'Identifiant ou code personnel incorrect.');
 const {data:u}=await admin.auth.admin.getUserById(account.user_id);
 if(!u.user?.email)return reply(401,'Identifiant ou code personnel incorrect.');
 const client=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data,error}=await client.auth.signInWithPassword({email:u.user.email,password});
 if(error||!data.session)return reply(401,'Identifiant ou code personnel incorrect.');
 return reply(200,'Connexion réussie',{session:data.session});
}

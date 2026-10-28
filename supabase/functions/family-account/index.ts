// Public endpoint: JWT checked explicitly for email changes; one-use tokens for recovery.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, x-client-info, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Content-Type':'application/json'};
const reply=(status:number,message:string)=>new Response(JSON.stringify({message}),{status,headers});
const digest=async(s:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s))),x=>x.toString(16).padStart(2,'0')).join('');
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='POST')return reply(405,'Méthode non autorisée');
 const url=Deno.env.get('SUPABASE_URL'),service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),anon=Deno.env.get('SUPABASE_ANON_KEY'),app=Deno.env.get('APP_URL'),mailKey=Deno.env.get('RESEND_API_KEY'),from=Deno.env.get('RECOVERY_FROM_EMAIL');
 if(!url||!service||!anon||!app||!mailKey||!from)return reply(503,'La récupération par e-mail n’est pas encore disponible. Contacte le support.');
 try{
  const b=await req.json();if(JSON.stringify(b).length>4096)return reply(400,'Requête invalide');
  const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
  const rpc=async(action:string,data:any)=>{const r=await admin.rpc('mf_service',{p_action:action,p_data:data});if(r.error)throw r.error;return r.data;};
  const {data:state,error}=await admin.rpc('mf_status');if(error||!state?.enabled)return reply(503,'Fonction non activée');
  const ip=await digest((req.headers.get('x-forwarded-for')||'unknown').split(',')[0]);
  if(!await rpc('limit',{key:'recovery-ip:'+ip,max:15,seconds:3600}))return reply(429,'Réessaie plus tard.');
  if(b.action==='confirm'){
   if(!['verify','reset'].includes(b.purpose)||typeof b.token!=='string'||b.token.length!==64||typeof b.id!=='string')return reply(400,'Lien invalide');
   if(b.purpose==='reset'&&(typeof b.password!=='string'||b.password.length<8||b.password.length>128))return reply(400,'Code personnel : 8 à 128 caractères.');
   const result=await rpc('consume',{id:b.id,hash:await digest(b.token),purpose:b.purpose});
   if(b.purpose==='reset'){
    const {error}=await admin.auth.admin.updateUserById(result.user_id,{password:b.password});if(error)return reply(503,'Le code n’a pas pu être modifié. Demande un nouveau lien.');
    // Revoke existing refresh sessions after recovery, including a lost device.
    await rpc('revoke-sessions',{user_id:result.user_id});
   }
   return reply(200,b.purpose==='verify'?'Adresse e-mail vérifiée.':'Code personnel modifié. Tu peux te reconnecter.');
  }
  let account:any,email:string,purpose:string;
  if(b.action==='set-email'){
   const jwt=(req.headers.get('Authorization')||'').replace(/^Bearer /,'');
   const {data,error}=await admin.auth.getUser(jwt);if(error||!data.user)return reply(401,'Connexion requise');
   const client=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false}});
   const check=await client.auth.signInWithPassword({email:data.user.email!,password:String(b.password||'')});if(check.error)return reply(403,'Code personnel incorrect');
   await client.auth.signOut();
   account={user_id:data.user.id};email=String(b.email||'').trim().toLowerCase();purpose='verify';
   if(email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))return reply(400,'Adresse e-mail invalide');
  }else if(b.action==='forgot'){
   account=await rpc('resolve',{login:String(b.login||'').slice(0,60)});email=account?.recovery_email;purpose='reset';
  }else return reply(400,'Action inconnue');
  const generic='Si ce compte possède une adresse vérifiée, un lien de récupération lui sera envoyé.';
  if(!account||!email||(purpose==='reset'&&!account.verified_at))return reply(200,generic);
  if(!await rpc('limit',{key:'mail:'+account.user_id,max:3,seconds:3600}))return reply(200,generic);
  const token=Array.from(crypto.getRandomValues(new Uint8Array(32)),x=>x.toString(16).padStart(2,'0')).join('');
  const challenge=await rpc('issue',{user_id:account.user_id,purpose,email,hash:await digest(token)});
  const link=new URL(app);if(link.protocol!=='https:')throw Error('APP_URL must use HTTPS');
  // Fragment keeps secrets out of HTTP requests, logs and referrers.
  link.hash=new URLSearchParams({account:purpose,id:challenge.id,token}).toString();
  const sent=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+mailKey,'Content-Type':'application/json','Idempotency-Key':'noel/'+challenge.id},body:JSON.stringify({from,to:[email],subject:purpose==='verify'?'Vérifie ton adresse — Lé Kdo':'Ton code personnel — Lé Kdo',html:'<p>Ce lien est valable 30 minutes et utilisable une seule fois.</p><p><a href="'+link.href.replace(/&/g,'&amp;')+'">'+(purpose==='verify'?'Vérifier mon adresse':'Choisir un nouveau code personnel')+'</a></p><p>Si tu n’es pas à l’origine de cette demande, ignore cet e-mail.</p>'})});
  if(!sent.ok)return reply(purpose==='reset'?200:503,purpose==='reset'?generic:'E-mail non envoyé. Réessaie plus tard.');
  return reply(200,purpose==='reset'?generic:'Un lien de vérification vient d’être envoyé.');
 }catch{return reply(400,'Lien expiré, invalide ou demande impossible.');}
});

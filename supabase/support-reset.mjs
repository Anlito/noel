// Operator only. Never put the service key or this tool in a browser bundle.
// Set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, RESET_USER_ID, RESET_PASSWORD,
// RESET_REASON, IDENTITY_VERIFIED=YES in a private shell after identity checks.
const {SUPABASE_URL:url,SUPABASE_SERVICE_ROLE_KEY:key,RESET_USER_ID:id,RESET_PASSWORD:password,RESET_REASON:reason,IDENTITY_VERIFIED:verified}=process.env;
if(!url||!key||!id||!password||password.length<8||password.length>128||!reason||reason.length<10||verified!=='YES')throw Error('Identité vérifiée, motif précis et paramètres requis. Aucun changement effectué.');
if(new URL(url).protocol!=='https:'||!/^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/.test(id))throw Error('URL ou identifiant invalide.');
const headers={apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json'};
async function call(path,body,method='POST'){const r=await fetch(url+path,{method,headers,body:body?JSON.stringify(body):undefined});if(!r.ok)throw Error('Opération refusée ('+r.status+'). Consulter Supabase sans afficher de secret.');return r.json();}
await call('/auth/v1/admin/users/'+id,null,'GET');
// Audit the authorized attempt before changing the password.
await call('/rest/v1/rpc/mf_service',{p_action:'support-audit',p_data:{user_id:id,reason}});
await call('/auth/v1/admin/users/'+id,{password},'PUT');
await call('/rest/v1/rpc/mf_service',{p_action:'revoke-sessions',p_data:{user_id:id}});
console.log('Code personnel modifié et sessions révoquées. Transmettre le code par le canal convenu après vérification d’identité.');

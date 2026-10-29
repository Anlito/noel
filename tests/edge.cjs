const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {stripTypeScriptTypes}=require('node:module');
const base=path.join(__dirname,'../supabase/functions');
function compile(file,globals,expression){const source=stripTypeScriptTypes(fs.readFileSync(path.join(base,file),'utf8').replace(/^import .*;\r?\n/gm,'').replace('export async function','async function'));const context=vm.createContext({Request,Response,URL,URLSearchParams,TextEncoder,crypto,...globals});vm.runInContext(source,context);return expression?vm.runInContext(expression,context):context;}
(async()=>{
 let events=[],unknown=false,denied=false,consumed=false;const mails=[];
 const env={SUPABASE_URL:'https://example.supabase.co',SUPABASE_ANON_KEY:'anon',SUPABASE_SERVICE_ROLE_KEY:'service',APP_URL:'https://anlito.github.io/noel/',RESEND_API_KEY:'mail-test',RECOVERY_FROM_EMAIL:'test@example.invalid'};
 const account={user_id:'00000000-0000-0000-0000-000000000001',recovery_email:'test@example.invalid',verified_at:'2026-10-28'};
 const service={rpc:async(name,args)=>{
  events.push({name,args});if(name==='mf_status')return {data:{enabled:true}};
  const a=args.p_action;if(a==='limit')return {data:true};if(a==='resolve')return {data:unknown==='empty'?{user_id:null,login:null}:unknown?null:account};if(a==='issue')return {data:{id:'00000000-0000-0000-0000-000000000020'}};
  if(a==='consume'){if(consumed)return {error:{message:'used'}};consumed=true;return {data:{user_id:account.user_id}};}return {data:{}};
 },auth:{getUser:async token=>({data:{user:token==='valid'?{id:account.user_id,email:'synthetic@accounts.noel.invalid'}:null},error:token==='valid'?null:{message:'invalid'}}),admin:{updateUserById:async(id,payload)=>{events.push({update:id,payload});return {};},createUser:async()=>({data:{user:{id:account.user_id}}}),deleteUser:async id=>{events.push({delete:id})},getUserById:async()=>({data:{user:{email:'synthetic@accounts.noel.invalid'}}})}}};
 const anon={auth:{signInWithPassword:async payload=>{events.push({signin:payload});return denied?{error:{message:'wrong'}}:{data:{session:{access_token:'jwt',refresh_token:'refresh'}}};},signOut:async()=>({})}};
 const client=(url,key)=>key==='service'?service:anon;
 let handler;compile('family-account/index.ts',{createClient:client,Deno:{env:{get:k=>env[k]},serve:fn=>handler=fn},fetch:async(url,options)=>{mails.push({url,...JSON.parse(options.body)});return new Response('{}',{status:200});}});
 const call=(body,jwt='')=>handler(new Request('https://functions.example/family-account',{method:'POST',headers:{'Content-Type':'application/json',Authorization:jwt?'Bearer '+jwt:''},body:JSON.stringify(body)}));
 let response=await call({action:'set-email',email:'someone@example.invalid',password:'password'});assert.equal(response.status,401);assert.equal(mails.length,0);
 denied=true;response=await call({action:'set-email',email:'someone@example.invalid',password:'incorrect'},'valid');assert.equal(response.status,403);denied=false;
 response=await call({action:'set-email',email:'someone@example.invalid',password:'correct-password'},'valid');assert.equal(response.status,200);assert.equal(mails.length,1);assert.equal(mails[0].to[0],'someone@example.invalid');assert(mails[0].html.includes('#account=verify'));assert(!(await response.text()).includes('token'));
 consumed=false;response=await call({action:'confirm',purpose:'verify',id:'x',token:'a'.repeat(64)});assert.equal(response.status,200);response=await call({action:'confirm',purpose:'verify',id:'x',token:'a'.repeat(64)});assert.equal(response.status,400);
 unknown=true;const missing=await (await call({action:'forgot',login:'missing'})).json();unknown=false;const existing=await (await call({action:'forgot',login:'Thomas'})).json();assert.deepEqual(existing,missing);assert(mails.at(-1).html.includes('#account=reset'));assert.equal(mails.at(-1).to[0],account.recovery_email);
 consumed=false;events=[];response=await call({action:'confirm',purpose:'reset',id:'x',token:'b'.repeat(64),password:'short'});assert.equal(response.status,400);assert(!events.some(e=>e.args?.p_action==='consume'));
 response=await call({action:'confirm',purpose:'reset',id:'x',token:'b'.repeat(64),password:'a-new-password'});assert.equal(response.status,200);assert(events.some(e=>e.update===account.user_id));assert(events.some(e=>e.args?.p_action==='revoke-sessions'));
 const v2=compile('family-auth/v2.ts',{createClient:client},'v2Auth');events=[];
 response=await v2(new Request('https://example.com'),{action:'login',name:'Thomas',code:'correct-password'},service,'https://example.supabase.co','anon',{});assert.equal(response.status,200);assert.equal(events.find(e=>e.signin).signin.email,'synthetic@accounts.noel.invalid');
 response=await v2(new Request('https://example.com'),{action:'signup',name:'thomas.dupont',code:'password'},service,'https://example.supabase.co','anon',{});assert.equal(response.status,409);
 unknown=true;response=await v2(new Request('https://example.com'),{action:'login',name:'unknown',code:'password'},service,'https://example.supabase.co','anon',{});assert.equal(response.status,401);unknown=false;
 // Parse every Edge source, including the dual-mode legacy bridge and admin guard.
 unknown='empty';response=await v2(new Request('https://example.com'),{action:'signup',name:'nouveau.compte',display_name:'Nouveau',code:'password'},service,'https://example.supabase.co','anon',{});assert.equal(response.status,200);response=await v2(new Request('https://example.com'),{action:'login',name:'unknown',code:'password'},service,'https://example.supabase.co','anon',{});assert.equal(response.status,401);unknown=false;
 for(const file of ['family-auth/index.ts','admin-set-password/index.ts'])compile(file,{v2Auth:v2,createClient:client,Deno:{env:{get:k=>env[k]},serve:()=>{}}});
 console.log('PASS Edge: verified optional email, reauthentication, generic forgot response, one-use confirmation, password validation, session revocation, unchanged legacy identity and TS syntax');
})().catch(e=>{console.error(e);process.exit(1)});

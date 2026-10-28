(()=>{'use strict';
 async function boot(){
  if(!window.supabase||!window.NOEL_SUPABASE_URL){document.getElementById('screen').textContent='Connexion indisponible. Recharge la page.';return;}
  window.noelDB=supabase.createClient(NOEL_SUPABASE_URL,NOEL_SUPABASE_ANON_KEY);
  const {data,error}=await noelDB.rpc('mf_status');
  if((!error&&data?.enabled===false)||error&&['PGRST202','42883'].includes(error.code)){
   const target=new URL('legacy.html',location.href);target.search=location.search;target.hash=location.hash;location.replace(target);return;
  }
  if(error||!data?.enabled){document.getElementById('screen').textContent='Connexion temporairement indisponible. Recharge la page dans quelques instants.';return;}
  await new Promise((resolve,reject)=>{const avatars=document.createElement('script');avatars.src='avatars.js?v=2';avatars.onload=resolve;avatars.onerror=reject;document.body.append(avatars);});
  const script=document.createElement('script');script.src='multi-app.js?v=manual-20261028';script.onerror=()=>{document.getElementById('screen').textContent='Chargement impossible. Recharge la page.';};document.body.append(script);
 }
 boot().catch(()=>{document.getElementById('screen').textContent='Connexion indisponible. Recharge la page.';});
})();

(()=>{
 async function check(){try{const r=await fetch(window.NOEL_SUPABASE_URL+'/rest/v1/rpc/mf_status',{method:'POST',headers:{apikey:window.NOEL_SUPABASE_ANON_KEY,'Content-Type':'application/json'},body:'{}'});if(r.ok&&(await r.json()).enabled)location.replace(new URL('./',location.href));}catch{}}
 window.addEventListener('pageshow',check);document.addEventListener('visibilitychange',()=>{if(!document.hidden)check()});check();
})();

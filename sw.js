/* Aucune réservation ni donnée familiale n'est mise en cache. */
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('fetch',event=>{
 if(event.request.mode!=='navigate'||new URL(event.request.url).origin!==self.location.origin)return;
 event.respondWith(fetch(event.request).catch(()=>new Response(
  '<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="theme-color" content="#064936"><title>Lé Kdo — Hors connexion</title><style>body{font:18px system-ui;background:#fbf7ef;color:#245a49;padding:32px;max-width:540px;margin:10vh auto}button{font:inherit;background:#245a49;color:white;border:0;border-radius:12px;padding:14px 20px}</style><h1>Un petit souci de connexion…</h1><p>Connecte-toi à Internet pour retrouver les listes et les repas de la famille.</p><button onclick="location.reload()">Réessayer</button></html>',
  {status:503,headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'}}
 )));
});

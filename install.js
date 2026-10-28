(()=>{'use strict';
 let pendingPrompt=null,installed=false;
 const $=id=>document.getElementById(id),mode=matchMedia('(display-mode: standalone)');
 const isStandalone=()=>installed||mode.matches||navigator.standalone===true;
 const isAppleMobile=()=>/iPhone|iPad|iPod/i.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
 function refresh(){
  $('installApp').classList.toggle('hidden',isStandalone());
 }
 window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();pendingPrompt=event;refresh()});
 window.addEventListener('appinstalled',()=>{installed=true;pendingPrompt=null;refresh()});
 mode.addEventListener?.('change',refresh);window.addEventListener('resize',refresh);
 async function install(){
  if($('navigationDialog').open)$('closeNavigation').click();
  if(isStandalone())return;
  if(pendingPrompt){const prompt=pendingPrompt;pendingPrompt=null;try{await prompt.prompt();const choice=await prompt.userChoice;if(choice.outcome==='accepted')installed=true;refresh();return}catch{refresh()}}
  $('installInstructions').textContent=isAppleMobile()
   ?'Dans le menu de partage de ton navigateur, choisis « Sur l’écran d’accueil », puis « Ajouter ». Si l’option manque, ouvre ce site dans Safari.'
   :/Android/i.test(navigator.userAgent)
   ?'Ouvre le menu ⋮ de ton navigateur, puis choisis « Installer l’application » ou « Ajouter à l’écran d’accueil ». Si l’option manque, ouvre ce site dans Chrome.'
   :'Dans le menu de ton navigateur, cherche « Installer Lé Kdo 2 Noyel » ou « Installer cette page comme application ». Tu peux aussi utiliser l’icône d’installation à droite de la barre d’adresse, si elle est proposée.';
  $('installDialog').showModal();
 }
 $('installApp').onclick=install;
 refresh();
 if('serviceWorker' in navigator)window.addEventListener('load',()=>navigator.serviceWorker.register('./sw.js',{scope:'./',updateViaCache:'none'}).catch(error=>console.warn('Installation indisponible :',error.message)));
})();

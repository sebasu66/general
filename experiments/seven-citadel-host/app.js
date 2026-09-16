import './components/sc-game-table.js';
const table=document.querySelector('#table');
const hostStatus=document.querySelector('#host-status');
let cards=null,currentRevision=-1,lastActionKey='';
async function loadJson(path){const r=await fetch(`${path}?_=${Date.now()}`,{cache:'no-store'});if(!r.ok)throw new Error(`${path}: ${r.status}`);return r.json()}
async function refresh(){
  try{
    cards = await loadJson('./data/cards.json');
    const state=await loadJson('./data/state.json');
    if(state.revision!==currentRevision){currentRevision=state.revision;table.game={cards,state}}
    hostStatus.textContent=`HOST ACTIVO Â· REV ${state.revision} Â· ${state.hostMessage||state.phase}`;
  }catch(err){hostStatus.textContent=`SINCRONIZACIÃ“N INTERRUMPIDA Â· ${err.message}`}
}
async function sendAction(action){
  const key=`${action.action_type}:${action.turn}:${action.card_id}:${action.payload}`;if(key===lastActionKey)return;lastActionKey=key;
  try{
    const response=await fetch('./.herenow/data/actions',{method:'POST',headers:{'content-type':'application/json','Idempotency-Key':crypto.randomUUID()},body:JSON.stringify(action)});
    if(!response.ok)throw new Error(`HTTP ${response.status}`);
    hostStatus.textContent='ACCIÃ“N RECIBIDA Â· ESPERANDO RESOLUCIÃ“N DEL HOST';
  }catch(err){lastActionKey='';hostStatus.textContent=`NO SE PUDO ENVIAR LA ACCIÃ“N Â· ${err.message}`;table.showToast('No se pudo registrar la acciÃ³n. PodÃ©s reintentar.')}
}
table.actionHandler=sendAction;
await refresh();
setInterval(refresh,3000);


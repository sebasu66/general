import './sc-die.js';
import './sc-character-card.js';
import './sc-event-card.js';
import './sc-check-card.js';
export class SCGameTable extends HTMLElement{
  connectedCallback(){
    if(this.dataset.ready)return;this.dataset.ready='1';this.className='game-table';
    this.innerHTML=`<div class="table-logo">SEVEN CITADEL<small>LO QUE QUEDA, IMPORTA.</small></div><div class="table-location" id="location"></div><section class="slot character-slot" data-label="PERSONAJE"><sc-character-card id="character"></sc-character-card></section><section class="slot history-slot" data-label="SECUENCIA NARRATIVA"><div class="history-pile" id="history"></div></section><section class="slot evidence-slot" data-label="EVIDENCIA / OBJETOS"><div class="placeholder" id="evidence">SIN EVIDENCIA COLOCADA</div></section><section class="slot active-slot" data-label="CARTA ACTIVA"><div class="placeholder" id="activePlaceholder">SIN CHEQUEO PENDIENTE</div><sc-check-card id="check" hidden></sc-check-card></section><section class="slot deck-slot" data-label="MAZO DE EVENTOS"><div class="deck-back"><span>III<br>SEVEN<br>CITADEL</span></div></section><section class="slot discard-slot" data-label="DESCARTE"><div class="placeholder">DESCARTE VACÍO</div></section><section class="slot dice-slot" data-label="ÁREA DE DADOS"><div class="dice-zone"><div class="dice-stage" id="diceStage"></div><div class="check-panel"><div class="meta" id="checkMeta">SIN CHEQUEO</div><button class="roll-button" id="rollButton" disabled>TIRAR DADOS</button></div></div></section><div class="roll-result" id="rollResult"></div><div class="table-state" id="stateInfo"></div><div class="toast" id="toast"></div>`;
    this.querySelector('#rollButton').addEventListener('click',()=>this.rollCheck());
    this.addEventListener('sc-choice',e=>this.handleChoice(e.detail));
  }
  set game(value){this._game=value;this.render()}
  set actionHandler(fn){this._actionHandler=fn}
  showToast(text){const el=this.querySelector('#toast');el.textContent=text;el.classList.add('show');clearTimeout(this._toastTimer);this._toastTimer=setTimeout(()=>el.classList.remove('show'),2200)}
  render(){
    if(!this._game||!this.isConnected)return;
    const {cards,state}=this._game;this._cards=cards;this._state=state;
    this.querySelector('#location').innerHTML=`TURNO ${state.turn}<b>${state.location}</b>`;
    const character=cards.characters[state.characterId];this.querySelector('#character').data=character;
    this.renderHistory();this.renderCheck();
    this.querySelector('#stateInfo').innerHTML=`<span class="connection-dot live"></span><strong>HOST</strong> · revisión ${state.revision}<br>FASE · ${state.phase}<br>TENSIÓN · ${state.tension||0}`;
  }  renderHistory(){
    const {cards,state}=this._game,root=this.querySelector('#history');root.replaceChildren();
    for(const id of state.narrative){const card=cards.events[id];if(!card)continue;const el=document.createElement('sc-event-card');el.data=card;el.interactive=state.phase==='awaiting_choice'&&id===state.activeEventId;el.selectedOption=state.selectedOptionId||null;root.append(el)}
  }
  renderCheck(){
    const {cards,state}=this._game,checkEl=this.querySelector('#check'),placeholder=this.querySelector('#activePlaceholder'),button=this.querySelector('#rollButton'),stage=this.querySelector('#diceStage'),meta=this.querySelector('#checkMeta'),result=this.querySelector('#rollResult');
    const check=state.activeCheckId?cards.checks[state.activeCheckId]:null;stage.replaceChildren();result.className='roll-result';result.textContent='';
    if(!check){checkEl.hidden=true;placeholder.hidden=false;button.disabled=true;meta.textContent='SIN CHEQUEO';return}
    checkEl.hidden=false;placeholder.hidden=true;checkEl.data=check;const stat=this._cards.characters[state.characterId].stats[check.attribute]||1;
    meta.innerHTML=`<b>${check.attribute.toUpperCase()} ${stat}</b><br>${check.dice}D8 · DIFICULTAD <b>${check.difficulty}</b>`;
    for(let i=0;i<check.dice;i++){const die=document.createElement('sc-die');die.value=1;stage.append(die)}
    button.disabled=state.phase!=='awaiting_roll';if(state.phase==='awaiting_roll')result.textContent='CHEQUEO PENDIENTE';
  }
  handleChoice(detail){
    if(this._state.phase!=='awaiting_choice')return;
    const card=this._cards.events[detail.cardId],option=card?.options?.find(o=>o.id===detail.optionId);if(!option)return;
    this._actionHandler?.({action_type:'choice',turn:this._state.turn,card_id:detail.cardId,payload:JSON.stringify({optionId:detail.optionId,label:option.label})});
    this.showToast(`Elección enviada al host: ${option.label}`);this.querySelectorAll('sc-event-card').forEach(c=>c.interactive=false);
  }  async rollCheck(){
    const {cards,state}=this._game;if(state.phase!=='awaiting_roll')return;
    const check=cards.checks[state.activeCheckId],character=cards.characters[state.characterId],threshold=character.stats[check.attribute]||1,button=this.querySelector('#rollButton'),dice=[...this.querySelectorAll('#diceStage sc-die')],result=this.querySelector('#rollResult');
    button.disabled=true;result.className='roll-result waiting';result.textContent='TIRANDO…';const rolls=await Promise.all(dice.map(d=>d.roll()));
    let successes=0,tension=0;dice.forEach((die,i)=>{const v=rolls[i];die.setAttribute('state','');if(v===1){successes+=2;die.setAttribute('state','success')}else if(v<=threshold){successes++;die.setAttribute('state','success')}if(v===8){tension++;die.setAttribute('state','danger')}});
    const passed=successes>=check.difficulty;result.className=`roll-result ${passed?'success':'failure'}`;result.textContent=`${rolls.join(' · ')} — ${successes} éxito${successes===1?'':'s'}${tension?` · +${tension} Tensión`:''} — ${passed?'ÉXITO':'FALLO'}`;
    this._actionHandler?.({action_type:'roll',turn:state.turn,card_id:state.activeEventId||'',payload:JSON.stringify({checkId:check.id,rolls,threshold,successes,difficulty:check.difficulty,tension,passed})});
    this.showToast('Tirada enviada al host. La escena avanzará cuando el host la resuelva.');
  }
}
customElements.define('sc-game-table',SCGameTable);
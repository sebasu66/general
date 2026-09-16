const css=`:host{display:block}.card{height:100%;border:1px solid #69645b;border-radius:8px;background:linear-gradient(160deg,#171a1c,#0b0e10);overflow:hidden;box-shadow:0 8px 16px #000a;display:flex;flex-direction:column}.art{height:40%;min-height:30%;background:radial-gradient(circle at 65% 20%,#b34f6666,transparent 28%),linear-gradient(145deg,#283139,#111518);background-size:cover;background-position:center;position:relative}.zone{position:absolute;top:5%;left:5%;font-size:clamp(5px,.45vw,8px);letter-spacing:.12em;color:#c5d1d4}.zone b{display:block;color:#d26b61;font-size:1.15em}.body{padding:5% 5% 4%;display:flex;flex-direction:column;min-height:0;flex:1}.body h3{font-size:clamp(8px,.95vw,15px);letter-spacing:.05em;margin:0 0 3%}.text{font:clamp(6px,.53vw,9px)/1.32 Georgia,serif;color:#c2c0b8;overflow:hidden}.choices{display:grid;gap:2%;margin-top:auto}.choice{border:1px solid #465158;background:#121719;color:#dedbd3;border-radius:4px;text-align:left;padding:2.3% 3%;font-size:clamp(5px,.48vw,8px);cursor:pointer}.choice b{color:#fff;margin-right:4%}.choice[disabled]{opacity:.45;cursor:default}.selected{border-color:#d1a24f;background:#251f13}.footer{font-size:clamp(4px,.4vw,7px);color:#708087;letter-spacing:.11em;margin-top:2%}`;
export class SCEventCard extends HTMLElement{
  constructor(){super();this.attachShadow({mode:'open'});this._interactive=false}
  set data(value){this._data=value||{};this.render()}
  get data(){return this._data}
  set interactive(value){this._interactive=Boolean(value);this.render()}
  set selectedOption(value){this._selected=value;this.render()}
  render(){
    if(!this._data)return;
    const d=this._data;
    const root=document.createElement('article');root.className='card';
    const art=document.createElement('div');art.className='art';
    if(d.art)art.style.backgroundImage=`linear-gradient(to top,#000a,transparent 55%),url('${d.art}')`;
    art.innerHTML=`<div class="zone">${d.zone||''}<b>${d.location||''}</b></div>`;
    const body=document.createElement('div');body.className='body';
    body.innerHTML=`<h3>${d.title||''}</h3><div class="text">${d.text||''}</div>`;
    root.append(art,body);
    this.shadowRoot.replaceChildren(Object.assign(document.createElement('style'),{textContent:css}),root);
    this.renderChoices(body,d);
  }  renderChoices(body,d){
    const options=d.options||[];
    if(options.length){
      const box=document.createElement('div');box.className='choices';
      options.forEach((option,index)=>{
        const button=document.createElement('button');button.type='button';button.className='choice';
        if(this._selected===option.id)button.classList.add('selected');
        button.disabled=!this._interactive;
        button.innerHTML=`<b>${index+1}</b>${option.label}`;
        button.addEventListener('click',()=>this.dispatchEvent(new CustomEvent('sc-choice',{detail:{cardId:d.id,optionId:option.id},bubbles:true,composed:true})));
        box.append(button);
      });
      body.append(box);
    }
    const footer=document.createElement('div');footer.className='footer';footer.textContent=d.code||'SEVEN CITADEL';body.append(footer);
  }
}
customElements.define('sc-event-card',SCEventCard);
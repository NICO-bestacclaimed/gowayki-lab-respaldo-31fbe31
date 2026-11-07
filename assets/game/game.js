/* Wayki Combi: original game, no libraries, no network. */
(() => {
  'use strict';
  const lanes = [96, 180, 264], playerY = 462;
  class WaykiEngine {
    constructor(random = Math.random) { this.random = random; this.reset(); }
    reset() { Object.assign(this, { phase: 'idle', lane: 1, x: 180, elapsed: 0, score: 0, coins: 0, lives: 3, invincible: 0, spawn: 0, rows: 0, objects: [], distance: 0 }); }
    start() { this.reset(); this.phase = 'playing'; }
    move(delta) { if (this.phase === 'playing') this.lane = Math.max(0, Math.min(2, this.lane + delta)); }
    pause() { if (this.phase === 'playing') this.phase = 'paused'; }
    resume() { if (this.phase === 'paused') this.phase = 'playing'; }
    frame(milliseconds) {
      const events = [];
      for (let remaining = Math.min(250, Math.max(0, milliseconds)); remaining > 0; remaining -= 40) events.push(...this.step(Math.min(40, remaining)));
      return events;
    }
    step(milliseconds) {
      if (this.phase !== 'playing') return [];
      const dt = Math.min(40, Math.max(0, milliseconds)), seconds = dt / 1000, events = [];
      this.elapsed = Math.min(90000, this.elapsed + dt);
      this.invincible = Math.max(0, this.invincible - dt);
      this.x += (lanes[this.lane] - this.x) * Math.min(1, seconds * 18);
      const speed = 155 + this.elapsed / 90000 * 155;
      this.distance += speed * seconds;
      this.spawn += seconds;
      if (this.spawn >= Math.max(.65, 1.1 - this.elapsed / 240000)) {
        this.spawn = 0;
        const pick = this.random();
        const kind = this.rows === 0 ? 'passenger' : pick < .35 ? 'passenger' : pick < .55 ? 'coin' : ['cone', 'pothole', 'car'][Math.floor(this.random() * 3)];
        this.objects.push({ lane: this.rows === 0 ? 1 : Math.floor(this.random() * 3), y: 75, kind, hit: false });
        this.rows++;
      }
      for (const object of this.objects) {
        object.y += speed * seconds;
        if (!object.hit && Math.abs(object.y - playerY) < 30 && Math.abs(lanes[object.lane] - this.x) < 39) {
          object.hit = true;
          if (object.kind === 'passenger') { this.score += 10; events.push('passenger'); }
          else if (object.kind === 'coin') { this.score++; this.coins++; events.push('coin'); }
          else if (!this.invincible) { this.lives--; this.invincible = 1600; events.push('collision'); }
        }
      }
      this.objects = this.objects.filter(o => o.y < 620 && !o.hit);
      if (!this.lives || this.elapsed >= 90000) { this.phase = 'ended'; events.push('end'); }
      return events;
    }
  }
  globalThis.WaykiEngine = WaykiEngine;
  if (typeof document === 'undefined') return;
  const $ = id => document.getElementById(id), canvas = $('road'), ctx = canvas.getContext('2d');
  const engine = new WaykiEngine();
  const stems = ['albotran_cb','albotran_f2','albotran_r','albotran_s_terminal_terrestre','albotran_sin_letra','c10_megabus_m','c2_cono_norte_a','c2_cono_norte_c','c2_cono_norte_cima','c2_cono_norte_cima_s','c3_transcayma_embajada','c4_union_aqp_7a_huarangal','c7_aqpmasivo_05','c8_bus_characato_t_quequena','c8_bus_characato_t_san_antonio'];
  const names = ['Albotran CB','Albotran F2','Albotran R','Albotran Terminal','Albotran','Megabus M','Cono Norte A','Cono Norte C','Cono Norte Cima','Cono Norte Cima S','Transcayma Embajada','Unión AQP 7A','AQP Masivo 05','Characato Quequeña','Characato San Antonio'];
  let stored = {}, frame = 0, last = 0, selected = 0, reported = false, ready = false, audio;
  try { stored = JSON.parse(localStorage.getItem('wayki.combi.v1') || '{}'); } catch (_) { /* Storage can be unavailable for a local file. */ }
  if (!stored || typeof stored !== 'object') stored = {};
  let best = Number.isInteger(stored.best) && stored.best >= 0 && stored.best <= 5000 ? stored.best : 0;
  let sound = stored.sound === true, vibration = true, english = false;
  const labels = {
    es: {sound:'Sonido',yes:'sí',no:'no',play:'Jugar',pause:'Pausa',resume:'Continuar',restart:'Volver a jugar',ready:'Tu combi, tu camino',paused:'Una pausa en el camino',done:'¡Buen recorrido!',crash:'Una vuelta más',best:'Récord local',unlock:'Desbloquea con',available:'Combi disponible',hint:'Desliza o usa ← → / A D · hasta 90 segundos',info:'Pasajeros +10 · monedas S/ 1.\nEsquiva baches, conos y autos.',finish:'Recogiste',passengers:'puntos',player:'Conduce a tu ritmo'},
    en: {sound:'Sound',yes:'on',no:'off',play:'Play',pause:'Pause',resume:'Resume',restart:'Play again',ready:'Your combi, your road',paused:'A break on the road',done:'Great journey!',crash:'One more lap',best:'Local best',unlock:'Unlock at',available:'Combi available',hint:'Swipe or use ← → / A D · up to 90 seconds',info:'Passengers +10 · S/ 1 coins.\nAvoid potholes, cones and cars.',finish:'You earned',passengers:'points',player:'Drive at your own pace'}
  };
  const text = () => labels[english ? 'en' : 'es'];
  const send = data => { if (globalThis.GoWayki && typeof GoWayki.postMessage === 'function') GoWayki.postMessage(JSON.stringify(data)); };
  function store() { try { localStorage.setItem('wayki.combi.v1', JSON.stringify({best,sound})); } catch (_) {} }
  const images = stems.map(stem => { const image = new Image(); image.src = 'sprites/' + stem + '.webp'; return image; });
  function selection() {
    const l = text(), locked = best < selected * 25;
    $('preview').src = images[selected].src; $('busName').textContent = names[selected];
    $('unlock').textContent = locked ? `${l.unlock} ${selected * 25} pts` : `${selected+1} / 15 · ${l.available}`;
    $('play').disabled = !ready || (engine.phase !== 'paused' && locked);
    $('best').textContent = `${l.best}: ${best}`;
    $('sound').textContent = `${l.sound}: ${sound ? l.yes : l.no}`;
    $('sound').setAttribute('aria-pressed', String(sound)); $('hint').textContent = l.hint;
    $('pause').textContent = l.pause;
  }
  function panel(kind) {
    const l = text(); $('overlay').hidden = false;
    $('selection').hidden = kind === 'paused';
    $('heading').textContent = kind === 'paused' ? l.paused : kind === 'ended' ? (engine.lives ? l.done : l.crash) : l.ready;
    $('info').innerText = kind === 'ended' ? `${l.finish} ${engine.score} ${l.passengers} · S/ ${engine.coins}` : l.info;
    $('play').textContent = kind === 'paused' ? l.resume : kind === 'ended' ? l.restart : l.play;
    selection();
  }
  function tone(kind) {
    if (!sound) return;
    try {
      if (!audio) audio = new (window.AudioContext || window.webkitAudioContext)();
      if (audio.state === 'suspended') audio.resume();
      const oscillator = audio.createOscillator(), gain = audio.createGain(), time = audio.currentTime;
      oscillator.type = 'triangle'; oscillator.frequency.value = kind === 'collision' ? 95 : kind === 'passenger' ? 680 : 900;
      gain.gain.setValueAtTime(.07,time); gain.gain.exponentialRampToValueAtTime(.001,time+.13);
      oscillator.connect(gain); gain.connect(audio.destination); oscillator.start(); oscillator.stop(time+.14);
    } catch (_) { /* Audio is optional and never prevents play. */ }
  }
  function hud() { $('score').textContent = `${engine.score} pts`; $('coins').textContent = `S/ ${engine.coins}`; $('lives').textContent = '♥ '.repeat(engine.lives).trim() || '—'; $('time').textContent = `${Math.ceil((90000-engine.elapsed)/1000)} s`; }
  function rounded(x,y,w,h,r,color) { ctx.fillStyle=color; ctx.beginPath(); ctx.moveTo(x+r,y);ctx.arcTo(x+w,y,x+w,y+h,r);ctx.arcTo(x+w,y+h,x,y+h,r);ctx.arcTo(x,y+h,x,y,r);ctx.arcTo(x,y,x+w,y,r);ctx.closePath(); ctx.fill(); }
  function draw() {
    ctx.clearRect(0,0,360,560); ctx.fillStyle='#ddd8be'; ctx.fillRect(0,0,360,560);
    const sky=ctx.createLinearGradient(0,0,0,120); sky.addColorStop(0,'#e0ede7'); sky.addColorStop(1,'#f6e6bc'); ctx.fillStyle=sky;ctx.fillRect(0,0,360,115);
    ctx.fillStyle='#adb9ae'; ctx.beginPath();ctx.moveTo(105,105);ctx.lineTo(202,18);ctx.lineTo(299,105);ctx.fill();
    ctx.fillStyle='#faf8ec';ctx.beginPath();ctx.moveTo(174,43);ctx.lineTo(202,18);ctx.lineTo(229,44);ctx.lineTo(204,39);ctx.lineTo(191,45);ctx.fill();
    ctx.fillStyle='#f5edcf';for(let i=0;i<9;i++){ctx.fillRect(i*44,84-(i%3)*7,39,40);ctx.fillStyle='#b2ac93';ctx.fillRect(i*44+14,98,7,14);ctx.fillStyle='#f5edcf';}
    ctx.fillStyle='#444a45';ctx.fillRect(54,112,252,448);ctx.fillStyle='#c5bda4';ctx.fillRect(45,112,9,448);ctx.fillRect(306,112,9,448);
    ctx.strokeStyle='#f0dfba';ctx.lineWidth=3;ctx.setLineDash([20,25]);ctx.lineDashOffset=-engine.distance%45;
    for(const x of [138,222]){ctx.beginPath();ctx.moveTo(x,114);ctx.lineTo(x,560);ctx.stroke();}ctx.setLineDash([]);
    for(let i=0;i<7;i++){const y=122+((i*77+engine.distance*.5)%455);rounded(5,y,28,39,3,'#eee7ce');rounded(326,y,29,39,3,'#eee7ce');}
    for(const object of engine.objects){if(object.y<105)continue;const x=lanes[object.lane],y=object.y;
      if(object.kind==='coin'){ctx.fillStyle='#ffd55c';ctx.beginPath();ctx.arc(x,y,13,0,Math.PI*2);ctx.fill();ctx.fillStyle='#78551b';ctx.font='bold 13px system-ui';ctx.textAlign='center';ctx.fillText('S/1',x,y+4);}
      else if(object.kind==='passenger'){rounded(x-25,y-20,50,42,8,'#ede8c9');ctx.fillStyle='#327a70';ctx.beginPath();ctx.arc(x-7,y-6,6,0,Math.PI*2);ctx.fill();rounded(x-14,y+2,14,16,4,'#327a70');ctx.fillStyle='#72532d';ctx.font='bold 16px system-ui';ctx.textAlign='left';ctx.fillText('+',x+3,y+9);}
      else if(object.kind==='pothole'){ctx.fillStyle='#252d2a';ctx.beginPath();ctx.ellipse(x,y,23,14,.2,0,Math.PI*2);ctx.fill();ctx.strokeStyle='#6a7166';ctx.lineWidth=3;ctx.stroke();}
      else if(object.kind==='cone'){ctx.fillStyle='#ef8954';ctx.beginPath();ctx.moveTo(x,y-23);ctx.lineTo(x-18,y+21);ctx.lineTo(x+18,y+21);ctx.fill();rounded(x-11,y+3,22,6,1,'#fff3db');}
      else{rounded(x-20,y-31,40,62,9,'#91aaa2');rounded(x-15,y-17,30,15,4,'#324f51');rounded(x-15,y+11,30,12,4,'#324f51');rounded(x-18,y-30,7,5,1,'#fff0bf');rounded(x+11,y-30,7,5,1,'#fff0bf');}}
    if(!engine.invincible || Math.floor(engine.invincible/130)%2===0){ctx.globalAlpha=.2;ctx.fillStyle='#111';ctx.beginPath();ctx.ellipse(engine.x,playerY+28,31,9,0,0,Math.PI*2);ctx.fill();ctx.globalAlpha=1;const image=images[selected];if(image.complete&&image.naturalWidth)ctx.drawImage(image,engine.x-39,playerY-39,78,78);}
  }
  function finish() { cancelAnimationFrame(frame); $('pause').disabled=true; if(!reported){reported=true;best=Math.max(best,engine.score);store();send({type:'score',value:engine.score,durationMs:Math.round(engine.elapsed)});}panel('ended'); }
  function tick(time) { const delta=last?time-last:16;last=time;const events=engine.frame(delta);for(const event of events){if(event==='end'){finish();}else{tone(event);if(event==='collision'&&vibration){if(globalThis.GoWayki)send({type:'haptic'});else if(navigator.vibrate)navigator.vibrate([80,50,80]);}}}draw();hud();if(engine.phase==='playing')frame=requestAnimationFrame(tick); }
  function pause() { if(engine.phase!=='playing')return;engine.pause();cancelAnimationFrame(frame);last=0;panel('paused'); }
  function start() { if(!ready)return;if(engine.phase==='paused')engine.resume();else{if(best<selected*25)return;engine.start();reported=false;}last=0;$('overlay').hidden=true;$('pause').disabled=false;canvas.focus();if(sound)tone('coin');frame=requestAnimationFrame(tick); }
  $('play').onclick=start;$('pause').onclick=pause;$('left').onclick=()=>engine.move(-1);$('right').onclick=()=>engine.move(1);
  $('previous').onclick=()=>{selected=(selected+14)%15;selection();draw();};$('next').onclick=()=>{selected=(selected+1)%15;selection();draw();};
  $('sound').onclick=()=>{sound=!sound;store();selection();send({type:'sound',value:sound});if(sound)tone('coin');};
  let touch;
  canvas.addEventListener('pointerdown',event=>{touch=event.clientX;canvas.setPointerCapture(event.pointerId);});
  canvas.addEventListener('pointerup',event=>{if(touch!==undefined&&Math.abs(event.clientX-touch)>20)engine.move(event.clientX>touch?1:-1);touch=undefined;});
  canvas.addEventListener('pointercancel',()=>{touch=undefined;});
  if (!window.PointerEvent) {
    canvas.addEventListener('touchstart',event=>{touch=event.touches[0].clientX;},{passive:true});
    canvas.addEventListener('touchmove',event=>event.preventDefault(),{passive:false});
    canvas.addEventListener('touchend',event=>{const x=event.changedTouches[0].clientX;if(touch!==undefined&&Math.abs(x-touch)>20)engine.move(x>touch?1:-1);touch=undefined;},{passive:true});
  }
  document.addEventListener('keydown',event=>{if(['ArrowLeft','ArrowRight','a','A','d','D','p','P','Escape'].includes(event.key)){event.preventDefault();if(event.repeat)return;if(['p','P','Escape'].includes(event.key))pause();else engine.move(['ArrowLeft','a','A'].includes(event.key)?-1:1);}});
  document.addEventListener('visibilitychange',()=>{if(document.hidden)pause();});
  globalThis.WaykiGame={pause,configure(config={}){best=Math.max(best,Number.isInteger(config.best)&&config.best>=0&&config.best<=5000?config.best:0);if(typeof config.sound==='boolean')sound=config.sound;if(typeof config.vibration==='boolean')vibration=config.vibration;english=config.language==='en';if(typeof config.name==='string')$('player').textContent=config.name.slice(0,80);document.documentElement.lang=english?'en':'es';$('badge').textContent=english?'ON THE ROAD TO MISTI':'RUMBO AL MISTI';$('left').setAttribute('aria-label',english?'Left lane':'Carril izquierdo');$('right').setAttribute('aria-label',english?'Right lane':'Carril derecho');$('previous').setAttribute('aria-label',english?'Previous combi':'Combi anterior');$('next').setAttribute('aria-label',english?'Next combi':'Combi siguiente');$('preview').alt=english?'Selected combi':'Combi seleccionada';canvas.setAttribute('aria-label',english?'Collect passengers and coins. Avoid obstacles. Use arrows, A D or swipe.':'Recoge pasajeros y monedas. Evita obstáculos. Usa flechas, A D o desliza.');store();if(engine.phase!=='playing')panel(engine.phase);else selection();draw();},getState(){return{phase:engine.phase,lane:engine.lane,score:engine.score,coins:engine.coins,lives:engine.lives,elapsed:Math.round(engine.elapsed),best,selected,sound,ready};}};
  Promise.all(images.map(image=>image.decode())).then(()=>{ready=true;panel('idle');draw();}).catch(()=>{$('status').textContent='No se pudieron cargar las ilustraciones locales. Vuelve a abrir el juego.';});
  panel('idle');draw();hud();
})();

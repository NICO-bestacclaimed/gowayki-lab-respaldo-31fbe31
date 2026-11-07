import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const sandbox = vm.createContext({});
vm.runInContext(readFileSync(new URL('../assets/game/game.js',import.meta.url),'utf8'),sandbox);
const Engine = sandbox.WaykiEngine;
let passed = 0;
function test(name, run) { run(); passed++; console.log('PASS',name); }
test('three lanes, bounds and paused input',()=>{const game=new Engine();game.start();game.move(-1);game.move(-1);assert.equal(game.lane,0);game.move(1);game.move(1);game.move(1);assert.equal(game.lane,2);game.pause();game.move(-1);game.step(500);assert.equal(game.elapsed,0);assert.equal(game.lane,2);game.resume();game.step(16);assert.equal(game.elapsed,16);});
test('passengers add ten and coins add one with S/ counter',()=>{const game=new Engine();game.start();for(const kind of ['passenger','coin']){game.objects.push({lane:1,y:460,kind,hit:false});game.step(16);}assert.equal(game.score,11);assert.equal(game.coins,1);});
test('a nearby object in another lane does not collide',()=>{const game=new Engine();game.start();game.objects.push({lane:0,y:460,kind:'car',hit:false});game.step(16);assert.equal(game.lives,3);});
test('collision invulnerability prevents repeated loss and three separate hits end once',()=>{const game=new Engine();game.start();game.objects.push({lane:1,y:460,kind:'car',hit:false});game.step(16);assert.equal(game.lives,2);game.objects.push({lane:1,y:460,kind:'cone',hit:false});game.step(16);assert.equal(game.lives,2);let ended=0;for(let i=0;i<2;i++){game.invincible=0;game.objects.push({lane:1,y:460,kind:'pothole',hit:false});ended+=game.step(16).filter(e=>e==='end').length;}assert.equal(game.phase,'ended');assert.equal(ended,1);assert.equal(game.step(16).length,0);});
test('time limit is ninety active seconds and pausing does not spend time',()=>{const game=new Engine(()=>.1);game.start();game.pause();for(let i=0;i<10;i++)game.step(40);game.resume();let ends=0;for(let i=0;i<2250;i++)ends+=game.step(40).filter(e=>e==='end').length;assert.equal(game.elapsed,90000);assert.equal(game.phase,'ended');assert.equal(ends,1);});
test('long background frame cannot teleport obstacles or inflate duration',()=>{const game=new Engine();game.start();game.step(300000);assert.equal(game.elapsed,40);assert.ok(game.distance<10);});
test('speed increases over a run and restart clears score, time and obstacles',()=>{const game=new Engine(()=>.1);game.start();game.step(40);const initial=game.distance;game.elapsed=80000;game.step(40);assert.ok(game.distance-initial>initial);game.score=250;game.start();assert.equal(game.score,0);assert.equal(game.elapsed,0);assert.equal(game.objects.length,0);assert.equal(game.lives,3);});
test('slow frames use collision substeps without stretching the ninety second timer',()=>{const game=new Engine(()=>.1);game.start();game.frame(80);assert.equal(game.elapsed,80);game.frame(300000);assert.equal(game.elapsed,330);});
console.log(`${passed} game logic tests passed`);

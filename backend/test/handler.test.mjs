import test from 'node:test';
import assert from 'node:assert/strict';
import {createHandler} from '../netlify/functions/coach.mjs';

const token='test-only-'.repeat(4);
const input={mode:'brick',goal:'Learn storage',context:'Finish: explain a bucket',messages:[{role:'user',content:'Sure'}]};
function setup({variables={},rows=[{reserved_requests:1}],response,dbError=false}={}) {
  const calls=[];
  const env={BBB_AI_ENABLED:'true',BBB_TRIAL_TOKEN:token,BBB_OPENAI_API_KEY:'fake-test-key',...variables};
  const handler=createHandler({env:name=>env[name],database:()=>({sql:async()=>{calls.push('reserve');if(dbError)throw Error();return rows;}}),providerFetch:async(url,options)=>{calls.push(JSON.parse(options.body));return response??Response.json({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify({reply:'A bucket stores objects. What would you put in one?',memory:'Learning storage',status:'continue',outcome:''})}]}]});}});
  const run=(body=input,auth=`Bearer ${token}`,context='production')=>handler(new Request('https://test.netlify.app/.netlify/functions/coach',{method:'POST',headers:{authorization:auth},body:JSON.stringify(body)}),{deploy:{context}});
  return {calls,run};
}
test('unauthorized requests never reserve or call provider',async()=>{const x=setup();assert.equal((await x.run(input,'bad')).status,401);assert.deepEqual(x.calls,[])});
test('disabled, preview and missing-key requests never spend',async()=>{
  for(const [variables,context] of [[{BBB_AI_ENABLED:'false'},'production'],[{},'deploy-preview'],[{BBB_OPENAI_API_KEY:''},'production']]){
    const x=setup({variables});assert.equal((await x.run(input,`Bearer ${token}`,context)).status,503);assert.deepEqual(x.calls,[]);
  }
});
test('invalid and oversized bodies never reserve',async()=>{const x=setup();assert.equal((await x.run({...input,messages:[]})).status,400);assert.equal((await x.run({...input,context:'x'.repeat(41000)})).status,413);assert.deepEqual(x.calls,[])});
test('exhausted allowance never calls provider',async()=>{const x=setup({rows:[]});assert.equal((await x.run()).status,429);assert.deepEqual(x.calls,['reserve'])});
test('database failures fail closed',async()=>{const x=setup({dbError:true});assert.equal((await x.run()).status,503);assert.deepEqual(x.calls,['reserve'])});
test('successful reply uses bounded pinned model with no storage or tools',async()=>{
  const x=setup();const result=await x.run();assert.equal(result.status,200);assert.equal(result.headers.get('cache-control'),'no-store');
  assert.equal(x.calls[0],'reserve');const payload=x.calls[1];assert.equal(payload.store,false);assert.equal(payload.max_output_tokens,2400);assert.equal(payload.model,'gpt-5.4-mini-2026-03-17');assert.equal(payload.tools,undefined);assert.ok(Buffer.byteLength(JSON.stringify(payload))<=40000);
});
test('provider failure consumes one reservation and is not retried',async()=>{const x=setup({response:new Response('',{status:500})});assert.equal((await x.run()).status,502);assert.equal(x.calls.length,2)});
test('refusal and incomplete generation cannot complete a brick',async()=>{
  for(const response of [Response.json({status:'incomplete'}),Response.json({status:'completed',output:[{content:[{type:'refusal',refusal:'No'}]}]})]){
    const x=setup({response});assert.notEqual((await x.run()).status,200);assert.equal(x.calls.length,2);
  }
});
test('plan mode validates and returns sequential brick structure',async()=>{
  const bricks=Array.from({length:3},(_,i)=>({title:`Step ${i+1}`,purpose:'Understand one concept',finish:'Explain it in your own words'}));
  const x=setup({response:Response.json({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify({bricks})}]}]})});
  assert.deepEqual(await (await x.run({...input,mode:'plan'})).json(),{bricks});
  assert.ok(x.calls[1].text.format.schema.properties.bricks);
});

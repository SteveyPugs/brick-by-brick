import { createHash, timingSafeEqual } from 'node:crypto';
import { getDatabase } from '@netlify/database';
import { instructions, schema, planSchema, validatePlan, validateInput, validateReply } from '../../src/coach.mjs';

const json = (body,status=200)=>Response.json(body,{status,headers:{'Cache-Control':'no-store'}});
const hash = value=>createHash('sha256').update(value).digest();

export function createHandler({env, database, providerFetch}) {
return async function handler(req, context) {
  if (req.method !== 'POST') return json({error:'method_not_allowed'},405);
  // No live provider calls in previews or until explicitly enabled.
  if (context?.deploy?.context !== 'production' || env('BBB_AI_ENABLED') !== 'true') return json({error:'ai_disabled'},503);
  const token = env('BBB_TRIAL_TOKEN');
  const key = env('BBB_OPENAI_API_KEY');
  if (!token || token.length < 32 || !key) return json({error:'not_configured'},503);
  if (!timingSafeEqual(hash(req.headers.get('authorization') ?? ''),hash(`Bearer ${token}`))) return json({error:'unauthorized'},401);
  let input;
  try {
    // Bound streamed bodies even when Content-Length is absent or forged.
    const reader=req.body?.getReader(); if (!reader) throw new Error();
    let size=0; const chunks=[];
    while(true){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>40000){await reader.cancel();return json({error:'request_too_large'},413);}chunks.push(value);}
    input=validateInput(JSON.parse(Buffer.concat(chunks).toString('utf8')));
  } catch { return json({error:'invalid_request'},400); }
  try {
    // Atomic, lifetime trial allowance: never resets on redeploy or month rollover.
    // Reserve before calling provider; failures consume a slot conservatively.
    const payload=JSON.stringify({model:'gpt-5.4-mini-2026-03-17',store:false,max_output_tokens:2400,reasoning:{effort:'none'},instructions:instructions+(input.mode==='plan'?' Draft 3 to 5 distinct sequential bricks using the decisions already made. Each has title (80 characters max), purpose and observable finish criterion (350 characters each max). Do not repeat decisions already settled. No arbitrary deadlines.': ''),
      input:[{role:'user',content:JSON.stringify({goal:input.goal,mode:input.mode,context:input.context})},...input.messages],
      text:{format:{type:'json_schema',name:'coach_reply',strict:true,schema:input.mode==='plan'?planSchema:schema}}});
    if(Buffer.byteLength(payload)>40000) return json({error:'request_too_large'},413);
    const db=database();
    const rows=await db.sql`UPDATE bbb_trial_usage SET reserved_requests=reserved_requests+1 WHERE singleton=true AND reserved_requests<100 RETURNING reserved_requests`;
    if (rows.length !== 1) return json({error:'trial_allowance_reached'},429);
    const response=await providerFetch('https://api.openai.com/v1/responses',{
      method:'POST',headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},signal:AbortSignal.timeout(45000),
      body:payload
    });
    if (!response.ok) return json({error:'provider_unavailable'},502);
    const data=await response.json();
    if(data.status!=='completed') return json({error:'incomplete_response'},502);
    const text=(data.output??[]).flatMap(x=>x.content??[]).filter(x=>x.type==='output_text').map(x=>x.text).join('');
    return json(input.mode==='plan'?validatePlan(JSON.parse(text)):validateReply(JSON.parse(text),input.mode));
  } catch { return json({error:'response_unavailable'},503); }
};
}
export default createHandler({env:name=>Netlify.env.get(name),database:()=>getDatabase(),providerFetch:(...args)=>fetch(...args)});

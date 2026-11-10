import test from 'node:test';
import assert from 'node:assert/strict';
import { NetlifyDB } from '@netlify/database-dev';
import pg from 'pg';

test('110 concurrent local reservations stop at 100',async()=>{
  const local=new NetlifyDB();
  let db;
  try {
    const connectionString=await local.start();
    await local.applyMigrations('./netlify/database/migrations');
    db=new pg.Pool({connectionString});
    const reserve=async()=> (await db.query('UPDATE bbb_trial_usage SET reserved_requests=reserved_requests+1 WHERE singleton=true AND reserved_requests<100 RETURNING reserved_requests')).rows;
    const results=await Promise.all(Array.from({length:110},()=>reserve()));
    assert.equal(results.filter(x=>x.length===1).length,100);
    const {rows}=await db.query('SELECT reserved_requests FROM bbb_trial_usage');
    assert.equal(rows[0].reserved_requests,100);
    const next=await reserve();
    assert.equal(next.length,0);
  } finally {if(db)await db.end();await local.stop();}
});

// Actual browser UI validation, using the bundled Playwright package.
const fs=require('fs'),path=require('path');
const {chromium}=require(process.env.NEURONS_NODE_MODULES+'/playwright');
const root=path.resolve(__dirname,'..'),out=path.join(root,'docs/validation/assets_20261015');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 const results=[];
 for(const name of ['01_全游戏提示词表单.html','01_音频需求表.html']){
  const p=await browser.newPage({viewport:{width:1366,height:900}}),errors=[];
  p.on('pageerror',e=>errors.push(e.message));
  await p.goto('file:///'+path.join(root,'deliverables/NEURONS_2D_资产需求_20261015',name).replaceAll('\\','/'));
  await p.locator('details').first().waitFor();
  const kind=await p.evaluate(()=>payload.kind);
  await p.locator('#search').fill(kind==='art'?'CHR_MAIN_ACT_WALK':'SFX_DRAWER');
  await p.locator('details').first().click();
  const card=p.locator('details').first();
  await card.locator('[data-field="notes"]').fill('浏览器往返验证，不提交此测试备注');
  const result=await p.evaluate(()=>{const saved=progress();return {kind:payload.kind,count:rows.length,visible:visibleRows().length,roundtrip:normalize(saved).some(x=>x.notes==='浏览器往返验证，不提交此测试备注'),otherKind:Array.isArray(saved[kind==='art'?'audio':'art']),duplicateRejected:(()=>{try{merge([{id:rows[0].id},{id:rows[0].id}]);return false;}catch{return true;}})()};});
  const downloadPromise=p.waitForEvent('download');await p.locator('#export').click();
  const download=await downloadPromise;const downloaded=JSON.parse(fs.readFileSync(await download.path(),'utf8'));
  result.download=downloaded.kind==='progress'&&downloaded.schema_version===2;
  result.errors=errors;await p.screenshot({path:path.join(out,kind+'_form.png'),fullPage:false});
  if(!result.roundtrip||!result.download||!result.duplicateRejected||errors.length)throw Error(JSON.stringify(result));
  results.push(result);await p.close();
 }
 await browser.close();fs.writeFileSync(path.join(out,'browser_results.json'),JSON.stringify(results,null,2));console.log(JSON.stringify(results));
})().catch(e=>{console.error(e);process.exit(1);});

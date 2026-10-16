"""Build one offline scale-review HTML from the verified room audit.

Only writes docs/research/space_scale_review_20261016.html. No runtime,
artwork, input audit, or production form is modified. Python stdlib only.
"""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/research/space_scale_audit_20261016.json"
OUTPUT = ROOT / "docs/research/space_scale_review_20261016.html"

HTML = r'''<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>NEURONS · 空间比例对照</title>
<style>
:root{--paper:#f5f4ee;--ink:#233a3d;--muted:#5e7376;--line:#cad5d3;--accent:#236c6b;--warm:#b37144}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font:16px/1.65 "Microsoft YaHei","PingFang SC",sans-serif}main{max-width:1360px;margin:auto;padding:30px 34px 48px}h1{font-size:30px;line-height:1.25;margin:9px 0 12px;font-weight:650}h2{font-size:21px;margin:0 0 14px}p{margin:7px 0}small,.muted{color:var(--muted)}.eyebrow{font-size:12px;letter-spacing:2px;color:var(--accent)}.status{display:inline-block;border:1px solid #ccbfa2;background:#f3ead5;padding:5px 11px;border-radius:4px;font-size:13px}.lead{max-width:950px;font-size:17px}.panel{margin-top:24px;background:#fffefa;border:1px solid var(--line);border-radius:8px;padding:23px 25px}.toolbar{display:flex;align-items:flex-end;gap:18px;flex-wrap:wrap;margin:16px 0}.control{display:flex;flex-direction:column;gap:5px;font-size:14px}select,button{font:inherit;color:var(--ink);background:#fffefa;border:1px solid #92a9a6;border-radius:4px;padding:9px 12px}select{width:min(570px,76vw)}button{cursor:pointer}button:hover{background:#e8f0eb}input[type=range]{accent-color:var(--accent);width:205px}.range-line{display:flex;align-items:center;gap:12px}.compare-head{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap}.legend{font-size:13px;display:flex;gap:15px}.dot{display:inline-block;width:10px;height:10px;margin-right:5px;border-radius:50%}.scroller{overflow:auto;border:1px solid var(--line);background:#f3f7f5;border-radius:5px;margin-top:13px;max-height:820px;scrollbar-color:#839e96 #e7eeea;scrollbar-width:auto}.scroller:focus{outline:2px solid var(--accent)}.scroller svg{display:block;max-width:none}.summary{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin:14px 0}.summary>div{border-left:3px solid #839397;padding:4px 12px}.summary>div:nth-child(2){border-color:var(--accent)}.summary strong{display:block;font-size:22px;font-variant-numeric:tabular-nums}.notes{font-size:14px;padding:13px 15px;background:#edf2ed;border-radius:4px}.camera{font-size:19px;font-weight:600;border-left:4px solid var(--accent);padding:10px 16px;background:#e8efea;margin:21px 0 5px}.reference{display:grid;grid-template-columns:minmax(360px,1.05fr) minmax(300px,1fr);gap:24px;align-items:start}.reference svg{display:block;width:100%;max-width:680px}.specs{display:grid;grid-template-columns:130px 1fr;gap:7px 12px;font-size:14px}.specs dt{color:var(--muted)}.specs dd{margin:0}.warning{color:#79542c}.door-example{overflow-x:auto;background:#f3f7f5;border:1px solid var(--line);border-radius:5px}.door-example svg{min-width:800px;width:100%;display:block}.sources{font-size:12px;overflow-wrap:anywhere;margin-top:24px}details{margin-top:14px;font-size:14px}summary{cursor:pointer;color:var(--accent)}code{font:13px Consolas,monospace}a{color:var(--accent)}footer{font-size:13px;color:var(--muted);margin-top:22px}svg text{font-family:"Microsoft YaHei","PingFang SC",sans-serif}svg .dimension{fill:#476469;font-size:16px}svg .tiny{fill:#527176;font-size:13px}svg .ruler{stroke:#69898a;stroke-width:1.2;fill:none}svg .human{fill:#b67950;stroke:#855433;stroke-width:1.5}
@media(max-width:850px){main{padding:20px 15px}.panel{padding:18px 14px}.reference,.summary{grid-template-columns:1fr}h1{font-size:25px}.specs{grid-template-columns:115px 1fr}}
@media print{.toolbar,.scroller>svg{print-color-adjust:exact}.scroller{max-height:none;overflow:visible}main{padding:0}.panel{break-inside:avoid}.status{background:white}.scroller svg{width:100%!important;height:auto!important}}
</style>
<main>
<header><div class="eyebrow">NEURONS / SPACE STUDY · 2026.10.16</div><h1>先把房间、门和人放到同一把尺子上</h1><span class="status">尺寸方案 · 尚未实施 · 尚未实机验收</span><p class="lead">下面是几何对照，不是场景美术，也不代表画风定稿。只比较房间外边界与比例；房间连接、必要物件和剧情因果继续保留。</p></header>
<section class="panel" aria-labelledby="comparison-title">
<div class="compare-head"><h2 id="comparison-title">选一个空间，比较真实大小</h2><span class="legend"><span><i class="dot" style="background:#8b999d"></i>当前占位 / 同尺参照</span><span><i class="dot" style="background:#4d8a80"></i>建议尺寸</span></span></div>
<div class="toolbar"><label class="control">房间<select id="room" aria-label="选择房间"></select></label><label class="control">两图统一缩放<span class="range-line"><input id="zoom" type="range" min="25" max="120" value="50" step="5"><output id="zoom-label">50%</output></span></label><button id="reset">统一 50%</button></div>
<div class="summary"><div><small id="current-label"></small><strong id="current-size"></strong></div><div><small>建议外边界 · 待逐房白盒测试</small><strong id="proposed-size"></strong></div></div>
<p class="muted" style="font-size:13px">两图使用相同米制与投影，不会分别缩放成一样大。可横向滚动查看；地板细线每格 1 米。棕色人形只作 1.75 米高度尺。</p>
<div id="comparison" class="scroller" tabindex="0" aria-label="同尺空间对比，可横向滚动"></div>
<div class="notes"><p id="connections"></p><p id="elements"></p><p id="reuse"></p><p id="basis" class="muted"></p></div>
<div class="camera">大房间靠相机移动，不缩小人物塞入一屏。</div>
</section>
<section class="panel" aria-labelledby="scale-title"><h2 id="scale-title">门与成人的比例</h2><div class="reference"><div id="proportions"></div><div><dl class="specs"><dt>成人高度尺</dt><dd>1.75 m。只用于比较比例，不是主角身高或身份设定。</dd><dt>门高</dt><dd>2.15 m（2.10–2.20 m 起测范围的示意值）</dd><dt>普通门宽</dt><dd>0.95 m（0.90–1.00 m 起测范围的示意值）</dd><dt>病床通过门宽</dt><dd>1.30 m（1.20–1.50 m 起测范围内）</dd><dt>墙厚</dt><dd>0.16 m（0.12–0.20 m 起测范围内）</dd><dt>通道参考带</dt><dd>1.50–1.80 m；最终按演员、家具与推床实走核验。</dd></dl><p class="warning" style="font-size:13px">门的视觉比例不能代替可通行净宽验收。这些值仍是比较与起测方案，需连同身体占地、门扇扫掠及配对动作一起核验。</p></div></div>
<details><summary>投影与画布参数</summary><p>1280 世界显示提案：<code>screen_x = 96x + 30z</code>，<code>screen_y = 56z − 78h</code>，x／z／h 均以米为单位。参考成人投影高 136.5 px；门高 167.7 px。不是当前运行投影。</p><p>制作源图按该像素映射的 2 倍：成人高 273 px、门高 335.4 px。大房间可以超出一屏；此处不把所有房间锁成一张 1280 宽底图。缩放只控制本页查看，不更改任何游戏参数。</p></details>
</section>
<section class="panel" aria-labelledby="doors-title"><h2 id="doors-title">候诊厅：仍是五个门，第五门放到右侧转角</h2><p>下图只说明既有连接怎样分到两面墙：病房、诊室、药房、办公室，加右侧楼梯门。不是新增房间或第六个门；相邻房间仍需配置对应返回落点。</p><div id="door-example" class="door-example"></div><p class="muted" style="font-size:13px">这是门位布置建议。没有绘制家具或额外窗户；门前站位、门扇扫掠和通行带还要在引擎内实测。</p></section>
<details class="sources"><summary>来源与范围</summary><p id="source-info"></p><p>39 个基础房型对应 55 个常规场景实例；隐藏 Street 单独列出，不计入 39。尚未实施的房间左侧仅展示 5.6 × 3.8 m 比较尺，不能理解为这些关卡已存在。</p><p><a href="space_scale_audit_20261016.json">逐房审计数据</a> · <a href="space_scale_audit_20261016.md">审计说明</a></p></details>
<footer>本页可离线打开；没有联网脚本、图片或生成素材。不会写入游戏场景，也不改变已交付图片。</footer>
</main>
<script id="source-data" type="application/json">__DATA__</script>
<script>
'use strict';
const audit=JSON.parse(document.getElementById('source-data').textContent);
const $=id=>document.getElementById(id);const NS='http://www.w3.org/2000/svg';
const rooms=audit.rooms.map(r=>({...r}));const hidden=audit.hidden_fragment;
rooms.push({id:hidden.id,name:'第一关 · 隐藏 Street（独立片段）',source:hidden.source,instance_ids:[hidden.id],current:{implemented_geometry:true,floor_m:hidden.current_floor_m},suggestion:{floor_bounding_m:hidden.suggested_floor_m,connections:'父亲血门入口 → 广场片段 → 独立 E1 出口',clearance_and_elements:'喷泉两侧可绕行；保留猎手发现、接近、扑击与干预空间。不新增击杀、对白或最低停留时间条件。'}});
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const p=(x,z,h=0)=>[96*x+30*z,56*z-78*h];const pts=a=>a.map(v=>v.map(n=>Number(n.toFixed(2))).join(',')).join(' ');
const poly=(points,fill,stroke='#65817c',extra='')=>`<polygon points="${pts(points)}" fill="${fill}" stroke="${stroke}" stroke-width="1.4" ${extra}/>`;
const line=(a,b,color='#779291',w=1,extra='')=>`<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${color}" stroke-width="${w}" ${extra}/>`;
const text=(x,y,s,cls='dimension',extra='')=>`<text x="${x}" y="${y}" class="${cls}" ${extra}>${esc(s)}</text>`;
function human(x,z){const [a,b]=p(x,z),H=78*1.75;return `<g class="human"><ellipse cx="${a}" cy="${b+1}" rx="17" ry="5" fill="#927252" opacity=".18" stroke="none"/><circle cx="${a}" cy="${b-H+10}" r="10"/><path d="M ${a-11} ${b-H+24} L ${a+11} ${b-H+24} L ${a+15} ${b-53} L ${a+8} ${b-50} L ${a+6} ${b} L ${a-1} ${b} L ${a-4} ${b-46} L ${a-7} ${b} L ${a-14} ${b} L ${a-11} ${b-52} Z"/><path d="M ${a-11} ${b-H+29} L ${a-21} ${b-62} M ${a+11} ${b-H+29} L ${a+21} ${b-62}" fill="none" stroke-width="6" stroke-linecap="round"/></g>`;}
function door(x,z,width=.95,right=false){const q=(u,h,d=0)=>right?p(x+d,z+u,h):p(x+u,z+d,h);return poly([q(0,0),q(width,0),q(width,2.15),q(0,2.15)],'#e6eee8','#4c706c')+poly([q(width,0),q(width,2.15),q(width,2.15,.16),q(width,0,.16)],'#bfcfc7','#4c706c')+poly([q(0,2.15),q(width,2.15),q(width,2.15,.16),q(0,2.15,.16)],'#d3ded6','#4c706c')+line(q(.07,.08),q(.07,2.08),'#8ca59a',1)+line(q(width-.09,.93),q(width-.17,.93),'#4c706c',3);}
function floor(w,d,color){let s=poly([p(0,0),p(w,0),p(w,d),p(0,d)],color);for(let x=1;x<w;x++)s+=line(p(x,0),p(x,d),'#b8ccc2',.7);for(let z=1;z<d;z++)s+=line(p(0,z),p(w,z),'#b8ccc2',.7);return s;}
function dimension(a,b,label,offset){const A=[a[0]+offset[0],a[1]+offset[1]],B=[b[0]+offset[0],b[1]+offset[1]];return line(a,A,'#9fb3ab',1)+line(b,B,'#9fb3ab',1)+line(A,B)+line([A[0],A[1]-5],[A[0],A[1]+5])+line([B[0],B[1]-5],[B[0],B[1]+5])+text((A[0]+B[0])/2,(A[1]+B[1])/2+22,label,'dimension','text-anchor="middle"');}
function roomDrawing(w,d,title,subtitle,color){let s=text(0,-205,title,'dimension','font-weight="700" font-size="22"')+text(0,-176,subtitle,'tiny');s+=floor(w,d,color);s+=poly([p(0,0),p(w,0),p(w,-.16),p(0,-.16)],'#bccbc3');s+=human(.7,Math.min(d-.55,2.6));s+=door(1.4,Math.min(d-.6,2.5));s+=text(...p(.2,Math.min(d,3.4)), '人和门仅为比例尺，非实际摆位','tiny');s+=dimension(p(0,d),p(w,d),`${w} m`,[0,32]);s+=dimension(p(w,0),p(w,d),`${d} m`,[45,0]);return s;}
function update(){const r=rooms.find(x=>x.id===$('room').value),dims=r.suggestion.floor_bounding_m;const old=r.current.floor_m||[5.6,3.8];const [w,d]=dims;const implemented=r.current.implemented_geometry;const leftWidth=96*old[0]+30*old[1]+110,gap=100,rightWidth=96*w+30*d+115,W=leftWidth+gap+rightWidth+110,H=56*Math.max(old[1],d)+330;const scale=Number($('zoom').value)/100;
$('current-label').textContent=implemented?'当前已实现的占位边界':'尚未实施：左侧仅为旧占位大小参照';$('current-size').textContent=`${old[0]} × ${old[1]} m · ${(old[0]*old[1]).toFixed(2)} m²`;$('proposed-size').textContent=`${w} × ${d} m · ${(w*d).toFixed(2)} m²`;$('zoom-label').value=`${Math.round(scale*100)}%`;
$('comparison').innerHTML=`<svg xmlns="${NS}" role="img" aria-label="${esc(r.name)}，相同米制比例的当前与建议尺寸" width="${W*scale}" height="${H*scale}" viewBox="0 0 ${W} ${H}"><g transform="translate(45,235)">${roomDrawing(old[0],old[1],implemented?'当前占位':'同尺参照（该房未实施）','5.6 × 3.8 m；不是正式尺寸','#e5e9e4')}</g><g transform="translate(${45+leftWidth+gap},235)">${roomDrawing(w,d,'建议尺寸 · 未实施',r.name,'#dcece1')}</g></svg>`;
$('connections').textContent='既有连接：'+r.suggestion.connections;$('elements').textContent='尺寸需要容纳：'+r.suggestion.clearance_and_elements;$('reuse').textContent='使用范围：'+r.instance_ids.join(' / ');$('basis').textContent='依据：'+r.source+'。此处只画外边界，不代表所有家具或演员站位已经完成。';}
for(const r of rooms){const o=document.createElement('option');o.value=r.id;o.textContent=`${r.id} · ${r.name}`;$('room').append(o);} $('room').value='L2_LOBBY';$('room').addEventListener('change',()=>{$('comparison').scrollLeft=0;update();});$('zoom').addEventListener('input',update);$('reset').addEventListener('click',()=>{$('zoom').value=50;update();});
function proportions(){let s='';s+=door(.3,0,.95);s+=human(1.85,0);s+=door(2.55,0,1.3);s+=text(29,30,'普通门 0.95 m','tiny');s+=text(145,53,'成人尺 1.75 m','tiny');s+=text(245,30,'病床门 1.30 m','tiny');s+=dimension(p(.3,0),p(.3,0,2.15),'2.15 m',[-27,0]);const a=p(4.3,0),b=p(4.3,0,1.75);s+=line(a,b)+text(a[0]+10,-65,'1.75 m','tiny');s+=poly([p(.3,1.75),p(1.8,1.75),p(1.8,2.3),p(.3,2.3)],'#e5dac7','#ad946d');s+=text(28,159,'1.50 m 通道参考带','tiny');s+=poly([p(2.55,1.75),p(4.35,1.75),p(4.35,2.3),p(2.55,2.3)],'#d7e8dd','#7da292');s+=text(268,159,'1.80 m 双人参考带','tiny');$('proportions').innerHTML=`<svg xmlns="${NS}" viewBox="-20 -200 580 385" role="img" aria-label="成人与两种门、通道的比例尺">${s}</svg>`;}
function lobby(){const w=12,d=8;let s=floor(w,d,'#e2eee5');s+=line(p(0,0),p(w,0),'#4d706b',4)+line(p(w,0),p(w,d),'#4d706b',4);const doors=[['病房',.8],['诊室',3.2],['药房',5.6],['办公室',8]];for(const [name,x]of doors){s+=door(x,0,1.3)+text(...p(x+.65,0,2.48),name,'dimension','text-anchor="middle"');}s+=door(w,2.7,1.3,true);const at=p(w,3.35,2.45);s+=text(at[0]+8,at[1],'⑤ 楼梯','dimension');s+=text(at[0]+8,at[1]+24,'既有第5门 · 右侧转角','tiny');s+=human(6,4);s+=poly([p(1,1.2),p(11.1,1.2),p(11.1,3),p(1,3)],'#c3d9cd','none','opacity=".46"');s+=text(...p(3,2.5),'门前退让区示意，不是家具排布','tiny');s+=dimension(p(0,d),p(w,d),'12 m',[0,30]);s+=text(30,56*d+92,'建议 12 × 8 m；仅示意门的分布。门幅仍待逐门核验。','dimension');$('door-example').innerHTML=`<svg xmlns="${NS}" viewBox="-40 -230 1690 820" role="img" aria-label="候诊厅既有四个房门和右转角第五楼梯门示意">${s}</svg>`;}
proportions();lobby();update();$('source-info').textContent='数据：docs/research/space_scale_audit_20261016.json；SHA-256：__HASH__。39 房型＋隐藏片段；本页投影与比例尺为技术讨论建议，不是已采纳美术规格。';
</script></html>'''

def main():
    raw = SOURCE.read_bytes()
    audit = json.loads(raw)
    rooms = audit["rooms"]
    assert len(rooms) == 39, "Expected all 39 canonical base room types"
    assert len({room["id"] for room in rooms}) == len(rooms), "Duplicate room ID"
    for room in rooms:
        size = room["suggestion"]["floor_bounding_m"]
        assert len(size) == 2 and all(float(n) > 0 for n in size), room["id"]
    embedded = json.dumps(audit, ensure_ascii=False, separators=(",", ":")).replace("<", "\\u003c")
    result = HTML.replace("__DATA__", embedded).replace("__HASH__", hashlib.sha256(raw).hexdigest())
    OUTPUT.write_text(result, encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}: {len(rooms)} base rooms + 1 hidden fragment; same-scale SVG; runtime untouched.")


if __name__ == "__main__":
    main()

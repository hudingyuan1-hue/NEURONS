function referenceText(a){
  const refs=(a.refs||[]).filter(r=>r.id!==a.mother);
  let s=a.upload||'';
  if(a.mother)s='必附：'+(D.names?.[a.mother]||a.mother)+'的已确认母图。 '+s;
  if(refs.length)s+=' '+refs.map(r=>(r.required?'必附':'已有才附')+'：'+(r.name||r.id)+'，'+r.role).join('；');
  if(a.category==='家具与物品')s+=' 仅附已确认房间的摆放处局部核可见侧、尺寸和操作面；场景的雾、窗光光束、大范围投影不画进独立物件。';
  if(!s)s='新母图可附本类已认可画法参考。只借绘画语言，不借其他角色身份或未确认的剧情。';
  return s;
}
function basePrompt(a,task){
  let refs='';
  const alien=a.id.includes('_ALTERED')&&!a.clips?.length;
  if(a.mother){
    const n=D.names?.[a.mother]||a.mother;
    refs=alien?'图1是原角色“'+n+'”的身份来源。保留原文规定的身份标记与衣装来源；本次按下述设计完成全身怪物化，允许其明确要求的体态、轮廓与身体连接改变，不只贴局部异化。\n':'图1是已确认的“'+n+'”，保持同一身份、脸型、发型和辨识标记；仅改变本项指定的衣装、状态、视图或表情，不重新设计。\n';
  }
  if(a.id==='CHR_OTHER_NPCS_N19_ALTERED')refs+='另附主角当前已成立的外貌与旧伤资料：前脸采用主角当前面貌，后脸仅继承已确认旧伤；未知伤处留空，不凭空增加缝线。\n';
  if(a.refs?.some(r=>r.required&&r.id!==a.mother))refs+='必要参考：'+a.refs.filter(r=>r.required&&r.id!==a.mother).map(r=>(r.name||r.id)+'负责'+r.role).join('；')+'。\n';
  const content=task?'本次只制作“'+task.name+'”这一张：'+task.text+' 不拼成多状态或多视图网格。':a.content;
  const story=a.category==='开场与结局';
  const bodyLayer=['ENDING_HOST_BODY_REFERENCE','ENV_EVENT_BODY_UNKNOWN'].includes(a.id);
  let tail='';
  if(story&&!bodyLayer){
    let canvas='沿本项构图比例保留高分辨率原图。';
    if(a.id.startsWith('SLIDE_')||a.id==='ENDING_BED_BASE')canvas='横幅16:9，可从2560×1440起试。';
    if(a.id==='ENDING_HOST_EYES')canvas='本次眼部局部一张，1:1，可从1024×1024起试；闭眼与刚睁眼保持同一裁切、机位和光源，不合成左右拼图。';
    if(a.id.startsWith('UI_EVIDENCE_')||a.id==='UI_RECORD_34')canvas='照片内容4:3，可从1280×960起试；人物名单与事件以已确认参考为准。';
    if(a.id==='UI_REHAB_WORK_ART')canvas='沿已确认作品的实际长宽比，不强行裁成横幅。';
    tail='\n'+D.story_style+'\n'+canvas+' 字幕、纸边、UI与动态信息由Codex另画。';
  }else if(a.category==='家具与物品'){
    tail='\n沿已确认房间局部的机位、可见侧与尺度制作独立主体，保留材质自身冷暖与柔和面光；房间环境雾、外扩光晕、窗光光束、大片地面投影不烘焙进物件。可操作的柜门/抽屉及可取物保留可拆结构。主体外为均匀浅暖灰底或工具支持的透明底，不画场景。\n'+D.prop_style;
  }else{
    const canvas=a.canvas||'沿同形态母图的画布，成人站姿可从1024×1280起试；坐卧、四足、多头按身体展开，不缩小或压扁主体。';
    const framing=a.spec==='UI_CHAR'?'按当前表情保留头部/上半身及真正参与动作的手臂；捧腹、拱身需保留相应躯干，不截断相关肢体。':'完整保留本项实际身体和支点，不截断头、手、脚或尾部。';
    const view=a.spec==='UI_CHAR'?'':'场内主体沿已确认使用场景的斜侧观看高度，脸与身体立面清楚，肩部顶面少量可见；母图已是合格机位则沿用，不改正俯视。';
    tail='\n'+D.char_style+'\n'+view+' '+canvas+' '+framing+' 均匀浅暖灰纯底，不画场景、画内棋盘格或外扩光晕。';
  }
  return refs+content+tail;
}
function actionPrompt(a,c,p,mother,target){
  const name=D.names?.[mother]||mother;
  const view=a.direction?'本次身体朝向：'+a.direction+'，左右手脚指角色自身的左右。':'沿当前形态母图的实际朝向；需要转身时只执行本相位规定的转向，不把整条动作随机换机位。';
  let text='编辑所附同一角色，制作“'+a.name+' / '+c.label+'”中的单张相位：'+p.label+'。\n图1：'+name+'的已确认母图，锁定身份、脸型、发型、当次衣装、身体结构和辨识标记。固定本游戏斜侧俯视；'+view+'已有本方向基姿或本动作第一张合格图时作为图2，固定观看高度、尺度与支点；尚无基姿时先核本方向起始姿态。\n本次具体姿态：'+p.text+'\n';
  if(target)text+='另附当前唯一接触对象“'+(D.names?.[target]||target)+'”的操作面/支撑处局部，只用于比例和接触定位；不把它与人物永久合成，也不补其他人物。\n';
  text+='动作上下文：'+c.action+' 本次只画刚选中的那个瞬间，不把整段动作叠在一张图，也不让人物在画布中横移表示路程。\n'+(c.support||a.support)+' '+(a.note||'')+'\n';
  if(a.id==='CHR_OTHER_NPCS_FATHER_ACTION_ALTERED')text+='母图中已经与手部粘连的碎瓶保留，按原连接随动作变化；它不是应删除的独立道具。\n';
  if(a.id==='CHR_OTHER_NPCS_N19_ACTION_ALTERED')text+='沿已确认的后期双面母图；前脸采用已确认主角面貌，后脸的伤痕只继承已成立事实，不自行补缝线。\n';
  text+=D.char_style+'\n'+(c.canvas_spec||a.canvas||'沿当前已核起始图的画布与主体尺度。')+' 沿本方向起始姿势的光照；全身及真实支撑完整，浅暖灰均匀纯底，无动作网格、箭头、文字、速度线或场景；后续对齐、补真实过渡与接入由Codex处理。';
  return text;
}
function renderAsset(a,host){
  host.innerHTML='<p class="meta">'+esc(a.id)+' · '+esc(a.scope||'')+'</p>'+(a.pending?'<p class="warn">'+esc(a.pending)+(a.blocked?' 本项依据尚缺，先保留占位，不下正式生成单。':'')+'</p>':'')+(a.note?'<p class="meta">'+esc(a.note)+'</p>':'');
  if(a.role==='codex'){
    host.insertAdjacentHTML('beforeend','<p class="notice">由Codex用已有素材、分层、简单图形或程序效果完成；这不是你的正式生成订单。</p><p>'+esc(a.content)+'</p>');
    progressUI(host,a);return;
  }
  if(a.clips?.length){
    const u=document.createElement('div');
    u.innerHTML='<p><b>附图：</b>本次形态母图必附；同方向基姿/已核第一张已有才附。接触相位只另附当前对象一项，不把列表全部上传。</p><div class="selectors"><label>母图 <select class="mother"></select></label><label>动作 <select class="clip"></select></label><label>当前相位 <select class="pose"></select></label></div><div class="selectors"><label>当前接触对象 <select class="target"></select></label></div><p class="phase-order"></p><p class="guide"></p><textarea class="prompt" rows="12" readonly></textarea><div class="actions"><button class="primary copy">复制当前相位完整提示词</button><button class="filename">复制本张文件名</button></div><p class="meta">对齐后连播，检查左右承重、轮廓跳动、支点与接触。普通图片溶解不能代替肢体过渡；相位数不是最终播放帧数。</p>';
    host.append(u);
    const ms=u.querySelector('.mother'),cs=u.querySelector('.clip'),ps=u.querySelector('.pose'),ts=u.querySelector('.target');
    const mothers=a.mother_choices?.length?a.mother_choices:[a.mother||a.id];
    ms.innerHTML=mothers.map(v=>'<option value="'+esc(v)+'">'+esc(D.names?.[v]||v)+'</option>').join('');
    cs.innerHTML=a.clips.map((v,i)=>'<option value="'+i+'">'+esc(v.label)+'</option>').join('');
    ts.innerHTML='<option value="">无 / 当前相位不需要</option>'+(a.target_choices||[]).map(v=>'<option value="'+esc(v)+'">'+esc(D.names?.[v]||v)+'</option>').join('');
    let current;
    function update(){
      const c=a.clips[+cs.value],p=c.poses[+ps.value];current=p;
      u.querySelector('.prompt').value=actionPrompt(a,c,p,ms.value,ts.value);
      u.querySelector('.phase-order').textContent='播放顺序：'+(c.play_order||c.poses.map((_,i)=>i)).map(i=>c.poses[i]?.label).filter(Boolean).join(' → ');
      u.querySelector('.guide').textContent=(c.guide||c.production_order||'按真实动作阶段逐张补缺。')+' '+(c.method==='Codex分层变形'?'已有合格基姿优先由Codex处理呼吸/轻动，不重复生成。':'');
    }
    function clips(){const c=a.clips[+cs.value];ps.innerHTML=c.poses.map((v,i)=>'<option value="'+i+'">'+esc(v.label)+(v.optional?'（按需补）':'')+'</option>').join('');update()}
    cs.onchange=clips;ps.onchange=update;ms.onchange=update;ts.onchange=update;
    u.querySelector('.copy').onclick=()=>copy(u.querySelector('.prompt').value);
    u.querySelector('.filename').onclick=()=>copy(current.filename);clips();
  }else{
    host.insertAdjacentHTML('beforeend','<p><b>附图：</b>'+esc(referenceText(a))+'</p>'+(a.tasks?.length?'<div class="selectors"><label>本次只做 <select class="task"></select></label></div>':'')+'<textarea class="prompt" rows="10" readonly></textarea><div class="actions"><button class="primary copy">复制本项完整提示词</button><button class="filename">复制文件名</button></div>');
    let task;
    function update(){host.querySelector('.prompt').value=basePrompt(a,task)}
    if(a.tasks?.length){const t=host.querySelector('.task');t.innerHTML=a.tasks.map((v,i)=>'<option value="'+i+'">'+esc(v.name)+'</option>').join('');t.onchange=()=>{task=a.tasks[+t.value];update()};task=a.tasks[0]}
    host.querySelector('.copy').onclick=()=>copy(host.querySelector('.prompt').value);
    host.querySelector('.copy').disabled=!!a.blocked;
    host.querySelector('.filename').onclick=()=>copy(task?.filename||a.filename);update();
  }
  if(a.effects){
    const e=D.effects.find(e=>e.id===a.effects[0]);
    if(e){const z=document.createElement('div');z.className='notice';z.innerHTML='<b>'+esc(e.name)+'</b><p>'+esc(e.manual)+'</p><p>已有条件项；只在沿母图分片仍不合格时补一张终态，不新画怪物母图或整套碎裂序列。</p><textarea rows="4" readonly></textarea><button>复制条件终态提示词</button>';z.querySelector('textarea').value=e.prompt+' 保留该异化母图的身体材料与原项圈；只画散落终态，不画人物或发生过程。';z.querySelector('button').onclick=()=>copy(z.querySelector('textarea').value);host.append(z)}
  }
  progressUI(host,a);
}

"""Record the spatial checkpoint without claiming formal art or human play approval."""
from pathlib import Path
from datetime import datetime
import hashlib, json, shutil, zipfile
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'docs/validation/spatial_rebuild_20261020'
TMP = ROOT / 'tmp/spatial_rebuild_20261019'
PACK = ROOT / 'exports/spatial_rebuild_20261020'
def load(p): return json.loads(Path(p).read_text(encoding='utf-8'))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def dump(p, data):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')

def main():
    runtime = load(ROOT / 'deliverables/space_templates_corrected_20261019/runtime_spaces.json')
    templates = load(ROOT / 'deliverables/space_templates_corrected_20261019/manifest.json')
    live = load(EVIDENCE / 'live_r2/result.json')
    natural = load(EVIDENCE / 'natural/result.json')
    package = load(EVIDENCE / 'pck/result.json')
    for result in [live, natural, package]: assert not result['failures']
    for name in ['all_spaces_r2_stderr.log', 'natural_stderr.log', 'pck_stderr.log', 'exe_stderr.log']:
        assert not (TMP / name).read_text(encoding='utf-8').strip(), name
    source = Path('C:/Users/23623/Downloads/关卡 周目 环境(1).docx')
    archived = ROOT / 'DOCX/本轮空间依据/关卡 周目 环境_20261020.docx'
    archived.parent.mkdir(parents=True, exist_ok=True)
    if archived.exists(): assert sha(source) == sha(archived)
    else: shutil.copy2(source, archived)
    source_info = {'source': str(source), 'archived_source': str(archived.relative_to(ROOT)),
                   'sha256': sha(source), 'records': 441, 'embedded_maps': 51,
                   'priority': 'Current user-supplied spatial document overrides conflicting historical layout geometry; it does not replace narrative, attack or reward sources.'}
    dump(EVIDENCE / 'source_document_manifest.json', source_info)
    for name in ['neural_navigation_result.json', 'neural_actor_portals_result.json',
                 'spatial_revision_save_result.json', 'street_early_checks.json',
                 'neural_design.json', 'street_early_design.json']:
        shutil.copy2(TMP / name, EVIDENCE / name)
    # Actual runtime screenshot overview, never a replacement painting.
    selected = ['L1_bedroom', 'L3_ward', 'L3_corridor', 'L3_quiet',
                'L4_atrium', 'L4_visual', 'L4_bridge', 'L4_rhythm',
                'L4_switch', 'L5_hippocampus', 'L5_basal', 'L5_amygdala',
                'L5_brainstem', 'L6_street_side', 'L6_street_narrow', 'L6_street_node']
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 18)
    sheet = Image.new('RGB', (1600, 1000), '#efede6'); draw = ImageDraw.Draw(sheet)
    for i, name in enumerate(selected):
        im = Image.open(EVIDENCE / f'live_r2/{name}.png').convert('RGB'); im.thumbnail((392, 221))
        x, y = (i % 4) * 400, (i // 4) * 250
        draw.text((x+6, y+3), name, fill='#263b39', font=font); sheet.paste(im, (x+4, y+27))
    sheet.save(EVIDENCE / 'runtime_overview.jpg', quality=93)
    checks = {'rooms': len(live['rooms']), 'gpu_passes': len(live['passes']),
              'natural_passes': len(natural['passes']), 'natural_ending': natural['ending'].get('id'),
              'natural_simulation_seconds': natural['elapsed_simulation_seconds'],
              'natural_hp': load(EVIDENCE / 'natural/final_snapshot.json')['rules']['hp'],
              'package_passes': len(package['passes']), 'formal_art_accepted': False,
              'human_normal_speed_accepted': False, 'second_pc_accepted': False}
    dump(EVIDENCE / 'checkpoint_summary.json', checks)
    note = f'''# 空间重构检查点 · 2026-10-20

本轮按新上传文档重构实际游戏，不再用旧矩形实现反向限制源图。原身份、技能、伤害、结算、逻辑连接与搜寻ID保留；实际门向、功能分区和路径随文档修正。用户卧室样板仅用于统一斜侧观看、连续墙面及近侧降切，不用于复制所有房型或家具摆位。

- L4/L5：18种结构、29条房间记录，包括四向中庭、扇厅、弯室、哑铃桥、S路、Y岔、回廊、脉冲井、双翼和双室。L5前十一房复用L4几何。
- L6：露天广场、竖长7×13米单北入口侧室、窄巷、错移街段、维护支巷、真中心洞口及出口；露天通口不凭门高元数据自动加城门过梁。
- L1–L3：病房门窗和床向、二层走廊房间两侧、北窗南门安静室及东北退让、六独立团疗椅、U形护理台、双床和淋浴围合均核源修正。
- 绘制、可走地面、洞口、导航及整张搬运床共享真实轮廓；内洞护沿薄于外墙，连续转角不描工程小块接缝。初轮GPU发现的8个薄弧自交顶片与安静室漏导出已修；初轮记录保留，不计为最终渲染通过。
- 旧存档采用独立空间revision及四份原始JSON，原在途位置、路线和动作不瞬移。L2/L3同关休息保留原revision，新章或完整重置采用当前结构。
- 当前模板{templates['scenes']}房、{templates['furniture_templates']}件构造定位、{templates['files']}PNG；这些不是等量人工订单。矩形只表示占地范围，风扇、椅腿、U台、弧桌、圆芯、薄屏、纤维和折叶按具体构造提示绘制。

最终实机56房巡检{len(live['passes'])}/0，stderr为空；新建隔离档普通process贯通L1–L6至E2完整结果，{natural['elapsed_simulation_seconds']:.2f}模拟秒、末尾HP{checks['natural_hp']}。运行用固定30模拟帧加速，不是人工正常速度或全分支体验；单次HP结果也不能批准难度递增。隔离PCK{len(package['passes'])}/0，独立Windows EXE初始化OpenGL并自动退出码0；均未做第二台电脑验证。

正式人物、动画、场景绘画、材质风格与最终声音听感仍是后续制作/验收内容，不把几何占位当成正式画风。用户随后已授权Codex承担全部剩余资产生产，先人物；主角只制作一套服装动作，其余服装不再逐套生成。用户已改名修订的异化图不再做审美重评，只做技术导入检查。

可试玩：`exports/spatial_rebuild_20261020/NEURONS.exe`，须与同目录PCK保留。新版表单：桌面最终表单中的03总表与空间与家具模板/00；01/02保留历史并提示新版入口。无Git写操作。
'''
    (EVIDENCE / 'README.md').write_text(note, encoding='utf-8')
    package_readme = note + '\n此包是空间重构检查点，后续人物与正式资产生产继续进行。\n'
    (PACK / 'README.txt').write_text(package_readme, encoding='utf-8')
    hashes = '\n'.join(f'{sha(PACK/name)}  {name}' for name in ['NEURONS.exe', 'NEURONS.pck', 'README.txt']) + '\n'
    (PACK / 'SHA256.txt').write_text(hashes, encoding='utf-8')
    with zipfile.ZipFile(PACK / 'NEURONS_Windows_空间重构_20261020.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for name in ['NEURONS.exe', 'NEURONS.pck', 'README.txt', 'SHA256.txt']: z.write(PACK / name, name)
    dump(EVIDENCE / 'build_manifest.json', {'recorded_at': datetime.now().isoformat(), 'source': source_info,
         'runtime_sha256': sha(ROOT / 'deliverables/space_templates_corrected_20261019/runtime_spaces.json'),
         'runtime_sources': runtime['source_sha256'], 'checks': checks,
         'package': {p.name: sha(p) for p in PACK.iterdir() if p.is_file()},
         'original_art_policy': 'User source PNGs are retained unchanged. New user files are inventoried by snapshot, never auto-rejected.'})
    print(json.dumps(checks, ensure_ascii=False))

if __name__ == '__main__': main()

"""Register painted layers against original bedroom slots, never write geometry."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'docs/validation/asset_production_20261020/furniture'
source=json.loads((QA/'sprite_preparation.json').read_text(encoding='utf-8'))
room=json.loads((ROOT/'neurons/data/room_spaces.json').read_text(encoding='utf-8'))['rooms']['bedroom']
items={x['id']:x for x in room['furniture']}
contracts=json.loads((ROOT/'deliverables/comprehensive_forms_20261019/data/active_spatial_contracts.json').read_text(encoding='utf-8'))
asset_ids={str(p['furniture_id']):asset for asset,placements in contracts['placements'].items() for p in placements if p.get('room_id')=='L1_bedroom'}
sprites=source['sprites']
calibration={
 'bed':{'mode':'top_plane','source_plane_px':[[74,112],[539,87],[111,225]],'plane_height_m':.55,'ground_anchor_px':[318,267]},
 'bed_blanket':{'mode':'top_plane','source_plane_px':[[57,104],[416,79],[82,231]],'rect_fraction':[.33,0,.67,1],'height_offset_m':.035,'attachment':'bed_top'},
 'bedside':{'mode':'prism_faces','source_top_px':[[42,72],[232,55],[277,158],[83,175]],'source_west_px':[[42,72],[83,175],[83,338],[42,254]],'source_south_px':[[83,175],[277,158],[277,320],[83,338]],'ground_anchor_px':[159,285]},
 'bedside_drawer':{'mode':'drawer_component','source_top_px':[[62,82],[360,62],[444,171],[104,195]],'source_west_px':[[62,82],[104,195],[104,290],[62,170]],'source_south_px':[[104,195],[444,171],[444,263],[104,290]],'drawer_count':3,'open_drawer_index':1,'travel_m':.28,'attachment':'bedside'},
 'desk':{'mode':'desk_parts','source_plane_px':[[25,84],[466,54],[62,173]],'tabletop_polygon_px':[[25,84],[466,54],[508,140],[507,157],[61,184],[25,102]],'leg_parts':[{'source_rect_px':[42,133,15,125],'world_fraction':[.07,.12]},{'source_rect_px':[428,136,18,99],'world_fraction':[.93,.12]},{'source_rect_px':[78,172,17,158],'world_fraction':[.07,.88]},{'source_rect_px':[475,151,19,157],'world_fraction':[.93,.88]}],'ground_anchor_px':[275,286]},
 'chair':{'mode':'height_anchor','ground_anchor_px':[192,328],'top_y_px':28},
 'fan':{'mode':'height_anchor','ground_anchor_px':[175,420],'top_y_px':43,'rotor_center_px':[175,149],'rotor_diameter_source_px':178},
 'fan_rotor':{'mode':'rotor_component','pivot_px':[218,204],'diameter_px':322,'attachment':'fan_cage'},
 'rack':{'mode':'height_anchor','ground_anchor_px':[160,426],'top_y_px':27},
 'books':{'mode':'prism_faces','source_top_px':[[100,34],[177,21],[271,108],[194,124]],'source_west_px':[[100,34],[194,124],[194,489],[100,393]],'source_south_px':[[194,124],[271,108],[272,473],[194,489]],'ground_anchor_px':[183,442]},
 'wardrobe':{'mode':'prism_faces','source_top_px':[[72,33],[180,10],[281,95],[176,128]],'source_west_px':[[72,33],[176,128],[176,480],[72,385]],'source_south_px':[[176,128],[281,95],[283,446],[176,480]],'ground_anchor_px':[176,433]},
 'wardrobe_open':{'mode':'reserved_open_variant','ground_anchor_px':[192,431],'top_y_px':22,'attachment':'wardrobe','binding_note':'Preserved separate variant; hinge-plane calibration pending. Do not automatically replace actual closed doors with an uncalibrated full-image warp.'},
 'stool':{'mode':'height_anchor','ground_anchor_px':[168,246],'top_y_px':36},
 'stool_parcel':{'mode':'prism_faces','source_top_px':[[41,51],[206,33],[266,99],[100,118]],'source_west_px':[[41,51],[100,118],[100,252],[40,179]],'source_south_px':[[100,118],[266,99],[266,233],[100,252]],'attachment':'stool_seat'},
 'box_lower':{'mode':'prism_faces','source_top_px':[[40,71],[232,45],[337,171],[143,198]],'source_west_px':[[40,71],[143,198],[142,338],[39,241]],'source_south_px':[[143,198],[337,171],[331,310],[142,338]]},
 'box_upper':{'mode':'prism_faces','source_top_px':[[52,90],[305,58],[404,183],[125,215]],'source_west_px':[[52,90],[125,215],[119,365],[54,255]],'source_south_px':[[125,215],[404,183],[404,329],[119,365]],'attachment':'box_lower'},
 'storage':{'mode':'prism_faces','source_top_px':[[41,50],[172,32],[253,116],[100,140]],'source_west_px':[[100,140],[253,116],[253,413],[101,434]],'source_south_px':[[41,50],[100,140],[101,434],[41,361]],'front_plane_policy':'Drawer fronts follow the existing west operation face; neutral side wood is reprojected separately.'},
 'rack_coat':{'mode':'attachment_height','attachment_anchor_px':[185,43],'bottom_y_px':482,'physical_height_m':1.35,'right_cuff_px':[297,319],'attachment':'rack_hooks'},
 'bedside_book':{'mode':'top_plane','source_plane_px':[[51,76],[243,63],[99,186]],'attachment':'bedside_top'},
 'bedside_clock':{'mode':'height_anchor','ground_anchor_px':[120,196],'top_y_px':54,'physical_height_m':.22,'attachment':'bedside_top'},
 'desk_paper':{'mode':'top_plane','source_plane_px':[[58,86],[226,61],[116,220]],'attachment':'desk_top'}
}
for id,record in sprites.items():record['calibration']=calibration[id]
slots={}
for id in ['bed','bedside','desk','chair','fan','rack','books','wardrobe','stool','box','storage']:
 item=items[id]
 slots['bedroom:'+id]={'asset_id':asset_ids.get(id),'original_id':id,'original_kind':item['kind'],'source_geometry':'neurons/data/room_spaces.json:rooms.bedroom.furniture','world_rect_m':item['rect_m'],'world_dimensions_m':item['rect_m'][2:]+[item['height_m']],'sprite':'box_lower' if id=='box' else id,'layers':{'bed':['bed','bed_blanket'],'bedside':['bedside','bedside_drawer','bedside_book','bedside_clock'],'fan':['fan_rotor','fan'],'rack':['rack','rack_coat'],'stool':['stool','stool_parcel'],'box':['box_lower','box_upper'],'desk':['desk','desk_paper']}.get(id,[id]),'state_owner':'app/search_actions/drawer_open/world_visual_time','mechanics_changed':False,'status':'painted_sprite_calibrated_pending_combination_gpu'}
 slots['bedroom:'+id]['runtime_binding_prepared']=id not in ['stool','box','storage']
 if not slots['bedroom:'+id]['runtime_binding_prepared']:slots['bedroom:'+id]['status']='painted_source_backed_up_integration_deferred_for_current_user_priority'
result={'schema_version':1,'enabled':False,'status':'first_bedroom_group_gpu_pending','slots':slots,'sprites':sprites,'state_policy':'Application keeps all existing action phases, contact settlement and item ownership. This registry supplies drawing layers and contact-pixel locations only.','original_atlases':source['atlases'],'runtime_3d':False,'geometry_or_ids_modified':False}
(ROOT/'neurons/data/production_props.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(QA/'registration.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'slots':len(slots),'separate_layers':len(sprites),'enabled':False,'geometry_changed':False}))

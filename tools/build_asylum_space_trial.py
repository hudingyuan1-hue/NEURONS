"""Versioned upper-floor metric trials; original topology/indices unchanged.

Only named rooms are replaced. Existing lower-floor configuration is preserved.
Dimensions/placements are technical trials, never approved artwork contracts.
"""
from pathlib import Path
import json
PATH=Path(__file__).resolve().parents[1]/'neurons/data/institution_spaces.json'
data=json.loads(PATH.read_text(encoding='utf-8'))
def item(room,index,name,rect,at,kind,height,**extra):
 return dict(id=f'{room}:{index}',name=name,rect_m=rect,approach_m=at,kind=kind,height_m=height,color='8c9b90',**extra)
def portal(toward,wall,center,width=1.35,size=(16,5)):
 w,h=size
 if wall=='north':wall_at=[center,0];inward=[0,1]
 elif wall=='south':wall_at=[center,h];inward=[0,-1]
 elif wall=='west':wall_at=[0,center];inward=[1,0]
 else:wall_at=[w,center];inward=[-1,0]
 def point(distance):return [round(wall_at[i]+inward[i]*distance,3) for i in range(2)]
 return dict(toward=toward,wall=wall,wall_point=wall_at,at=point(.65),threshold=point(.25),landing=point(1.25),inward=inward,width_m=width,height_m=2.15)
def room(name,size,furniture,portals,anchors,**extra):
 return dict(geometry_version=2,size_m=size,authority='S1:P147–164; original topology and stable points retained; placements are technical trial',wall=dict(thickness_m=.15,height_m=2.55),furniture=furniture,portals=portals,anchors=anchors,decor=[],static_walls=[],pairs=[],wide_routes=[],search_counts={'3':len(furniture)},search_metadata='asylum_upper',**extra)
c='corridor';a='activity'
data['upper_trial_rooms']=[c,a,'group_therapy','quiet','bathroom','double_ward','workshop']
data['rooms'][c]=room(c,[16,5],[
 item(c,0,'护士站办公桌',[.55,.35,1.8,.75],[1.5,1.5],'desk',.75),
 item(c,1,'花坛',[14.75,.4,.65,.65],[14.35,.9],'plant',.7),
 item(c,2,'候诊椅组',[1.8,4.1,1.8,.55],[2.7,3.75],'chairs',.9),
 item(c,3,'桌旁柜子',[.5,3.4,.6,.8],[1.45,3.8],'drawer',1.1),
],[portal('stairs','west',2.5),portal(a,'north',3.5),portal('group_therapy','north',7.5),portal('quiet','north',12),portal('bathroom','south',13.5),portal('double_ward','south',9.5),portal('workshop','south',5.5)],dict(
 spawn=[1.25,2.5],actor_idle=[1.25,2.5],entry=[1.25,2.5],
 head_nurse_wait=[1.5,1.5],med_nurse_wait=[2.1,1.5],ordinary_orderly_wait=[2.7,2.2],isolation_orderly_wait=[11,1.1],
 station_side=[2.7,2.2],chief_station_side=[.85,1.5],station_write_pos=[2.1,1.5],transfer_station_bed=[2.3,2.1],transfer_station_nurse=[1.85,2.0],station_work_surface=[1.5,1.5],
 corridor_parking=[13.3,2.6],corner_waiting=[9.5,3.2],isolation_staff_side=[11,1.1],ordinary_patient_stop=[2.8,2.2],
 ),camera_track=True)
data['rooms'][c]['pairs']=[dict(id='station_document_contact',a='transfer_station_bed',b='transfer_station_nurse',max_distance_m=.55),dict(id='nurse_at_real_station',a='transfer_station_nurse',b='station_work_surface',max_distance_m=.65)]
data['rooms'][c]['wide_routes']=[dict(id='bed_main_lane',radius_m=.45,**{'from':[1.25,2.5],'to':[14.2,2.5]})]
data['rooms'][a]=room(a,[10,8],[
 item(a,0,'电视柜',[.2,1.1,1.6,.5],[1,1.95],'drawer',.7),
 item(a,1,'窗①',[0,2.3,.08,1.2],[.7,2.9],'window',1.15,collision=False,wall_mount='west'),
 item(a,2,'沙发组',[.7,3.5,2.4,1],[1.9,3.15],'sofa',.85),
 item(a,3,'茶几',[3.8,3.55,1.1,.7],[4.35,3.2],'table',.43),
 item(a,4,'活动桌',[6.6,3.5,2,.9],[7.6,3.15],'desk',.75),
 item(a,5,'绿植',[8.8,6.7,.6,.6],[8.35,6.9],'plant',1),
 item(a,6,'窗②',[9.92,1.8,.08,1.2],[9.3,2.4],'window',1.15,collision=False,wall_mount='east'),
 item(a,7,'书架',[6.7,.35,2,.45],[7.7,1.2],'books',1.6),
],[portal('corridor','north',5,size=(10,8))],dict(spawn=[5,1.25],actor_idle=[5,1.25],entry=[5,1.25],postop_patient_wait=[3.4,2.5],informer_wait=[4.6,2.3]),camera_track=True)
data['rooms'][a]['wide_routes']=[dict(id='door_to_sofa_side',radius_m=.45,**{'from':[5,1.25],'to':[3.45,2.85]})]
# Remaining S1:P165–216 rooms use the same instance/layout pipeline. Each
# movable person, original relic and paired action has its own clear stand.
g='group_therapy'
seats=[[2.3,3.4,.6,2.6],[5.9,3.4,.6,2.6],[2.9,6.0,3,.5],[2.3,3,1.1,.5],[5.4,3,1.1,.5]]
data['rooms'][g]=room(g,[9,8],[
 item(g,0,'储物柜',[.4,1.6,.9,1.5],[1.65,2.35],'drawer',1.5),
 item(g,1,'窗①',[0,4.9,.08,1.3],[.7,5.55],'window',1.2,collision=False,wall_mount='west'),
 item(g,2,'团体座椅组',[2.3,3,4.2,3.5],[4.4,3.9],'chairs',.9,collision_rects_m=seats),
 item(g,3,'绿植',[7.7,6.8,.6,.6],[7.2,7.1],'plant',1),
 item(g,4,'窗②',[8.92,4.8,.08,1.3],[8.3,5.45],'window',1.2,collision=False,wall_mount='east'),
 item(g,5,'白板',[5.2,.25,1.8,.12],[6.1,1.2],'board',1.65),
],[portal(c,'north',4.5,size=(9,8))],dict(spawn=[4.5,1.25],entry=[4.5,1.25],actor_idle=[4.5,1.25],therapist_wait=[6.1,1.2],speaker_wait=[4.4,3.9],speaker_release=[4.4,1.8],observer_wait=[4.4,2.7]),camera_track=True)
data['rooms'][g]['wide_routes']=[dict(id='open_seat_group_entry',radius_m=.45,**{'from':[4.5,1.25],'to':[4.4,4.8]})]
q='quiet'
data['rooms'][q]=room(q,[6,5],[
 item(q,0,'固定储物柜',[.4,1.4,.8,1.3],[1.55,2],'drawer',1.6),
 item(q,1,'普通储物柜',[4.8,1.4,.8,1.3],[4.45,2],'drawer',1.6),
 item(q,2,'软垫休息椅',[.55,3.7,1.7,.65],[1.4,3.35],'chair',.85),
 item(q,3,'高窗',[5.92,3.45,.08,1.2],[5.3,4.05],'window',1.55,collision=False,wall_mount='east'),
],[portal(c,'north',3,size=(6,5))],dict(spawn=[3,1.25],entry=[3,1.25],actor_idle=[3,1.25],ordinary_patient_stop=[3,2.8],transport_bed_park=[3,2.2],isolation_observation=[3,2.8]),camera_track=True)
data['rooms'][q]['wide_routes']=[dict(id='bed_to_actual_parking',radius_m=.45,**{'from':[3,1.25],'to':[3,2.2]})]
b='bathroom'
shower1=[[5.6,1.5,1.9,.12],[7.38,1.5,.12,1.5],[5.6,2.88,1.9,.12]]
shower2=[[5.6,4.2,1.9,.12],[7.38,4.2,.12,1.5],[5.6,5.58,1.9,.12]]
data['rooms'][b]=room(b,[8,7],[
 item(b,0,'洗手池①',[.35,1,.7,1.2],[1.4,1.6],'sink',.8),
 item(b,1,'洗手池②',[.35,3,.7,1.2],[1.4,3.6],'sink',.8),
 item(b,2,'公共地漏',[2.8,3.2,.25,.25],[3.05,3.45],'drain',.02,collision=False),
 item(b,3,'淋浴间①',[5.6,1.5,1.9,1.5],[6.3,2.3],'shower',1.9,collision_rects_m=shower1,screen_target=True),
 item(b,4,'淋浴间②',[5.6,4.2,1.9,1.5],[6.3,4.95],'shower',1.9,collision_rects_m=shower2),
 item(b,5,'高窗',[0,5.25,.08,1.2],[.7,5.85],'window',1.55,collision=False,wall_mount='west'),
 item(b,6,'马桶',[3.3,5.8,.65,.65],[3.6,5.35],'toilet',.75),
],[portal(c,'north',4,size=(8,7))],dict(spawn=[4,1.25],entry=[4,1.25],actor_idle=[4,1.25],cleaner_wait=[4.5,1.25],observer_wait=[4.75,2.3],corpse_origin=[6.3,2.3],relic_asylum_corpse_wristband=[3.05,3.45],relic_asylum_meal_list=[6.3,4.95],wash_shower1=[6.3,2.3],wash_drain=[3.05,3.45],wash_shower2=[6.3,4.95]),camera_track=True)
data['rooms'][b]['decor']=[item(b,-1,'清洁车停靠位',[1.8,5.8,.8,.6],[2.2,5.3],'cart',.8,collision=True)]
data['rooms'][b]['wide_routes']=[dict(id='corpse_board_stall_to_door',radius_m=.45,**{'from':[6.3,2.3],'to':[4,1.25]})]
d='double_ward'
data['rooms'][d]=room(d,[8,6],[
 item(d,0,'衣柜',[.4,1,.75,1.25],[1.55,1.6],'wardrobe',2),
 item(d,1,'储物柜',[5.6,.45,.9,1],[6.85,1],'drawer',1.4),
 item(d,2,'单人床①',[1.3,3,2.05,1],[3.75,3.5],'bed',.5),
 item(d,3,'单人床②',[4.65,3,2.05,1],[4.25,3.5],'bed',.5),
 item(d,4,'床头柜①',[1.3,4.5,.55,.55],[2.25,4.8],'drawer',.65),
 item(d,5,'床头柜②',[6.15,4.5,.55,.55],[5.75,4.8],'drawer',.65),
 item(d,6,'窗',[3.3,5.92,1.4,.08],[4,5.3],'window',1.2,collision=False,wall_mount='south'),
],[portal(c,'north',4,size=(8,6))],dict(spawn=[4,1.25],entry=[4,1.25],actor_idle=[4,1.25],corner_patient_wait=[5,1.4],patient_wait=[3.75,3.5],observer_wait=[4.9,2.2]),camera_track=True)
data['rooms'][d]['wide_routes']=[dict(id='between_two_numbered_beds',radius_m=.45,**{'from':[4,1.25],'to':[4,4.25]})]
w='workshop'
data['rooms'][w]=room(w,[10,7],[
 item(w,0,'操作桌①',[.5,2.3,2.2,1],[1.6,1.85],'desk',.75),
 item(w,1,'操作桌②',[6.8,2.3,2.2,1],[7.9,1.85],'desk',.75),
 item(w,2,'矮柜',[.4,5.8,1.2,.7],[1,5.4],'drawer',.65),
 item(w,3,'洗手池',[.4,.4,1,.55],[.9,1.3],'sink',.8),
 item(w,4,'窗',[0,3.7,.08,1.4],[.7,4.4],'window',1.2,collision=False,wall_mount='west'),
 item(w,5,'作品展示板',[4,6.8,1.8,.12],[4.9,6.15],'board',1.5),
 item(w,6,'材料柜',[8.6,4.3,1,1.6],[9.1,6.35],'drawer',1.6,locked_upper=True,contact_height_m=1.0),
 item(w,7,'材料架',[8.5,.4,1,.55],[9,1.25],'material_rack',1.6),
],[portal(c,'north',5,size=(10,7))],dict(spawn=[5,1.25],entry=[5,1.25],actor_idle=[5,1.25],labor_patient_wait=[9,1.25],worker_table=[8.45,1.85],worker_rack=[9.45,1.2],table_search=[7.9,1.85],supervisor_wait=[8.65,6.35],observer_wait=[7.9,1.2]),camera_track=True)
data['rooms'][w]['object_anchors']={'product_surface':dict(pos_m=[8.15,2.35],height_m=.75,support='workshop:1',contact_anchors=['worker_table','table_search'],reach_m=.65)}
data['rooms'][w]['pairs']=[dict(id='separate_worker_and_searcher',a='worker_table',b='table_search',max_distance_m=.65)]
data['rooms'][w]['wide_routes']=[dict(id='between_work_tables',radius_m=.45,**{'from':[5,1.25],'to':[5,5.5]})]
for name in [g,q,b,d,w]:data['rooms'][name]['authority']='S1:P165–216; original topology/search parts; technical proportions only'
PATH.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Updated seven versioned upper metric trials; lower configurations preserved; no art generated.')

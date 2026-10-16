extends RefCounted
## Persistent facts for the implemented exploration slice. No textures here.
const AsylumMap=preload("res://scripts/core/asylum_map.gd")
const CortexMap=preload("res://scripts/core/cortex_map.gd")
const KeyDiscovery=preload("res://scripts/core/key_discovery.gd")
const ROOM_POINTS={
 "bedroom":["床","床头柜","靠背椅","书桌","蓝色圆凳与纸箱","杂物箱","衣帽架","衣柜","五层书架","储物柜","立式风扇"],
 "ward":[],
 "lobby":["挂号导诊台","叫号屏控制盒","自助机出票槽","绿植底托","宣传架","饮水机下柜"],
 "clinic":["医生桌抽屉","储物柜","洗手池下柜","检查床床沿与床底","器械柜","壁架","垃圾桶","窗台"],
 "pharmacy":["取药柜台","冷藏药柜开放层","洗手池下柜","储物柜","药架","处方配药台","宣传架"],
 "office":["资料架","窗台","饮水机下柜","垃圾桶","小边柜","文件柜","办公桌①","打印机出纸托盘","洗手池下柜","储物柜","办公桌②"]}
const GRAPH={"ward":["lobby"],"lobby":["ward","clinic","pharmacy","office"],"clinic":["lobby"],"pharmacy":["lobby"],"office":["lobby"]}
var data:Dictionary={}
var key_rules=KeyDiscovery.new()

func _init() -> void:
 data={"level":1,"cycle":1,"attempts":{"1":1,"2":1,"3":1},"targets":[],"key_target":"","key_seen":false,"key_owner":"",
  "unlocked":[1],"rooms":{},"receipts":{},"exploration_boundary":false,"profile":{}}

func new_attempt(level:int,rng:RandomNumberGenerator) -> void:
 # Persist one discovery root for the profile. Replaying a saved rest or
 # transition must not rerandomize the same next attempt from wall time.
 if str(data.get("key_seed_root","")).is_empty():
  var existing:String=str(data.get("key_discovery",{}).get("seed",""))
  data.key_seed_root=("key-root|"+(existing if not existing.is_empty() else str(rng.state))).sha256_text()
 _remember_previous_discovery()
 var attempt:int=int(data.attempts.get(str(level),1))
 var sample_rng:=RandomNumberGenerator.new()
 sample_rng.seed=("key-targets-v2|%s|%d|%d"%[str(data.key_seed_root),level,attempt]).sha256_text().substr(0,15).hex_to_int()
 var recent_target:String=_recent_target(level,attempt)
 var candidates:Array=all_candidates(level)
 for i in range(candidates.size()-1,0,-1):
  var j:int=sample_rng.randi_range(0,i)
  var temp=candidates[i]
  candidates[i]=candidates[j]
  candidates[j]=temp
 if level==4:
  # S4:T6R5: each floor contributes eight, not sixteen from a mixed pool.
  var first:Array=[];var second:Array=[]
  for candidate in candidates:
   (first if str(candidate).get_slice(":",0) in CortexMap.FIRST_ROOMS else second).append(candidate)
  candidates=_take_sample(first,8,recent_target)+_take_sample(second,8,recent_target)
 else:candidates=_take_sample(candidates,10 if level==1 else 12 if level==2 else 14,recent_target)
 data.level=level
 if level==1:data.room_geometry_version=2
 if level in [2,3]:data.institution_geometry_version=2
 data.targets=candidates
 data.key_target=""
 data.key_seen=false
 data.key_owner=""
 data.key_discovery=key_rules.begin(level,attempt,str(data.key_seed_root),candidates)
 data.rooms={}
 data.erase("search_route_watch")
 data.exploration_boundary=false
 data.cortex_exit_crossed=false
 if not data.attempts.has(str(level)):data.attempts[str(level)]=1

func _take_sample(pool:Array,count:int,recent_target:String) -> Array:
 var without_recent:Array=[]
 for target in pool:
  if str(target)!=recent_target:without_recent.append(target)
 # Never shrink a required sample, delete a world point, or turn a
 # presentation cooldown into an unavailable final key candidate.
 return (without_recent if without_recent.size()>=count else pool).slice(0,count)

func _recent_target(level:int,attempt:int) -> String:
 var latest:Dictionary={}
 for record in data.get("key_discovery_history",[]):
  if int(record.level)==level and (latest.is_empty() or int(record.attempt)>int(latest.attempt)):latest=record
 if latest.is_empty():return ""
 var elapsed:int=attempt-int(latest.attempt)
 return str(latest.target) if elapsed>0 and elapsed<=int(key_rules.config.recent_result_cooldown_attempts) else ""

func _remember_discovery(level:int,attempt:int,target:String) -> void:
 if not target in all_candidates(level):return
 if not data.has("key_discovery_history"):data.key_discovery_history=[]
 for record in data.key_discovery_history:
  if int(record.level)==level and int(record.attempt)==attempt and str(record.target)==target:return
 data.key_discovery_history.append({"level":level,"attempt":attempt,"target":target})

func _remember_previous_discovery() -> void:
 var previous:Dictionary=data.get("key_discovery",{})
 var target:String=str(previous.get("discovered",""))
 if target.is_empty():return
 _remember_discovery(int(previous.get("level",data.level)),int(previous.get("attempt",1)),target)

static func all_candidates(level:int) -> Array:
 var result:Array=[]
 var rooms:Array=["bedroom"] if level==1 else ["lobby","clinic","pharmacy","office"] if level==2 else AsylumMap.POINTS.keys() if level==3 else CortexMap.POINTS.keys()
 for room in rooms:
  for index in range(point_names(level,room).size()):result.append("%s:%d"%[room,index])
 return result

func resolve_key(target:String,receipt:String,finder:String) -> Dictionary:
 if not data.has("key_discovery"):return {"accepted":false,"newly_found":false,"reason":"migration_required"}
 var result:Dictionary=key_rules.resolve(data.key_discovery,target,receipt,finder,all_candidates(int(data.level)))
 if result.get("newly_found",false):
  data.key_target=target
  data.key_owner="dog" if finder=="dog" else target
  data.key_seen=finder=="hero"
  _remember_discovery(int(data.key_discovery.level),int(data.key_discovery.attempt),target)
 return result

func note_search_interference(target:String,event:Dictionary) -> bool:
 if not data.has("key_discovery") or not target in all_candidates(int(data.level)):return false
 return key_rules.note_interference(data.key_discovery,target,event)

func migrate_key_discovery(completed:Array,saved_rng:String) -> bool:
 var previous:Dictionary=data.get("key_discovery",{})
 if int(previous.get("version",0))>=2:return false
 # Loading the same old save produces the same new seed. No random reroll
 # during migration, and no reuse of the old chosen location as an outcome.
 var seed_value:String=str(previous.get("seed",""))
 if seed_value.is_empty():seed_value=("key-migration|"+saved_rng+"|"+JSON.stringify(data.get("profile",{}))).sha256_text()
 if str(data.get("key_seed_root","")).is_empty():data.key_seed_root=("key-root|"+seed_value).sha256_text()
 var legal:Array=all_candidates(int(data.level))
 var eligible:Array=[]
 for target in data.get("targets",[]):
  if str(target) in legal and not str(target) in eligible:eligible.append(str(target))
 var migrated:Dictionary=key_rules.begin(int(data.level),int(data.attempts.get(str(int(data.level)),1)),seed_value,eligible)
 migrated.completed=previous.get("completed",{}).duplicate(true)
 migrated.evidence=previous.get("evidence",{}).duplicate(true)
 migrated.interference=previous.get("interference",{}).duplicate(true)
 for target in completed:
  if target in legal and not migrated.completed.has(target):
   migrated.completed[target]={"receipt":"legacy_completed:"+str(target),"finder":"unknown","found":false,"reason":"preserved_completed_empty"}
 for target in migrated.completed:
  var receipt:String=str(migrated.completed[target].get("receipt",""))
  if not receipt.is_empty() and receipt!="legacy_completed":migrated.completion_receipts[receipt]=target
 var owner:String=str(data.get("key_owner",""))
 var already_discovered:bool=bool(data.get("key_seen",false)) or owner in ["hero","dog","floor"] or not str(previous.get("discovered","")).is_empty()
 if already_discovered:
  migrated.discovered=str(previous.get("discovered",data.get("key_target","")))
  if str(migrated.discovered).is_empty():migrated.discovered=str(data.get("key_target",""))
  if str(migrated.discovered).is_empty():migrated.discovered="legacy_existing_key"
 else:
  data.key_target="";data.key_owner="";data.key_seen=false
  # v1's discarded group-rate policy could leave all sixteen L4 initial
  # targets empty. L4 has no rest, so preserve those verdicts and use only
  # genuinely unfinished legal supplemental points for a migration recovery.
  # No key is awarded here; the real completion path still settles it once.
  var initial_empty:bool=eligible.size()==16 and key_rules.remaining_eligible(migrated)==0
  for target in eligible:
   if bool(migrated.completed.get(target,{}).get("found",false)):initial_empty=false
  if int(previous.get("version",0))==1 and int(data.level)==4 and initial_empty:
   var recovery:Array=[]
   for target in legal:
    if not migrated.completed.has(target):recovery.append(target)
   migrated.migration_recovery_targets=recovery
   migrated.migration_recovery_reason="v1_l4_initial_group_empty_without_key_no_rest"
   if recovery.is_empty():migrated.diagnostic="legacy_l4_no_uncompleted_recovery_target"
 migrated.migrated_from_version=int(previous.get("version",0))
 migrated.migrated_from_fixed_placement=previous.is_empty()
 # No old group-rate or interference factor survives as live policy.
 # An old all-empty trial receives no retroactive key: L1-L3 keep the normal
 # real rest path; L4 uses the explicitly marked supplemental recovery above.
 data.key_discovery=migrated
 _remember_previous_discovery()
 return true

func normalize_restored_numbers() -> void:
 # JSON numbers are floats. Never create a second attempt counter named 3.0;
 # legacy aliases denote the same counter, so keep the maximum, never sum.
 data.level=int(data.level);data.cycle=int(data.cycle)
 var normalized:Dictionary={}
 for raw in data.attempts:
  var key:String=str(raw)
  if key.is_valid_float() and is_equal_approx(float(key),float(int(float(key)))):key=str(int(float(key)))
  normalized[key]=maxi(int(normalized.get(key,1)),int(data.attempts[raw]))
 data.attempts=normalized

static func point_names(level:int,room:String) -> Array:
 if level==4:return CortexMap.POINTS.get(room,[])
 return AsylumMap.POINTS.get(room,[]) if level==3 else ROOM_POINTS.get(room,[])

func doors(room:String) -> Array:
 if int(data.level)==4:return CortexMap.doors(room)
 if int(data.level)==3:return AsylumMap.doors(room)
 var result:Array=GRAPH.get(room,[]).duplicate()
 if room=="lobby":result.append("stairs")
 return result

func has_key() -> bool:
 return data.key_owner=="hero"

func next_room(from:String,to:String) -> String:
 if int(data.level)==4:return CortexMap.next_room(from,to)
 if int(data.level)==3:return AsylumMap.next_room(from,to)
 if from==to:return from
 var pending:Array=[from]
 var visited:Dictionary={from:""}
 while not pending.is_empty():
  var current:String=pending.pop_front()
  for neighbor in GRAPH.get(current,[]):
   if visited.has(neighbor):continue
   visited[neighbor]=current
   if neighbor==to:
    var step:String=to
    while visited[step]!=from:step=visited[step]
    return step
   pending.append(neighbor)
 return ""


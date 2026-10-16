extends RefCounted
## S4 P56/P90, with the user's completion-time discovery revision.
## The next genuinely completed eligible target has chance 1 / remaining.
## No key location is selected in advance. Interference is a fact, not a debuff.
var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/key_discovery.json"))

func begin(level:int,attempt:int,seed_value:String="",eligible_targets:Array=[]) -> Dictionary:
 if seed_value.is_empty():
  var entropy:=RandomNumberGenerator.new()
  entropy.randomize()
  seed_value="%s:%s:%s"%[str(entropy.randi()),str(entropy.randi()),str(entropy.randi())]
 var eligible:Array=[]
 for target in eligible_targets:
  if not str(target).is_empty() and not str(target) in eligible:eligible.append(str(target))
 # Old three-argument callers remain callable but cannot silently use every
 # legal world point as a key target. Tests/fixtures must declare their set.
 return {"version":2,"level":level,"attempt":attempt,"seed":seed_value,"eligible_targets":eligible,
  "completed":{},"completion_receipts":{},"interference":{},"evidence":{},"discovered":"","configuration_version":int(config.version),
  "diagnostic":"eligible_targets_required" if eligible.is_empty() else ""}

func _eligible_targets(state:Dictionary) -> Array:
 var result:Array=state.get("eligible_targets",[]).duplicate()
 # Only the explicit v1 L4 migration can add a recovery set. New attempts
 # never populate it, and the original public sample remains unchanged.
 for target in state.get("migration_recovery_targets",[]):
  if not target in result:result.append(target)
 return result

func remaining_eligible(state:Dictionary) -> int:
 var remaining:int=0
 for target in _eligible_targets(state):
  if not state.get("completed",{}).has(target):remaining+=1
 return remaining

func probability(state:Dictionary,target:String) -> float:
 if int(state.get("version",0))!=2 or not str(state.get("discovered","")).is_empty():return 0.0
 if not target in _eligible_targets(state) or state.get("completed",{}).has(target):return 0.0
 var remaining:int=remaining_eligible(state)
 return 1.0/float(remaining) if remaining>0 else 0.0

func draw(state:Dictionary,target:String) -> float:
 # Thirteen hexadecimal digits fit exactly within a double's integer range.
 var token:String="%s|%d|%d|%s"%[str(state.seed),int(state.level),int(state.attempt),target]
 return float(token.sha256_text().substr(0,13).hex_to_int())/4503599627370496.0

func note_interference(state:Dictionary,target:String,event:Dictionary) -> bool:
 if target.is_empty() or not str(state.discovered).is_empty() or state.completed.has(target):return false
 if not event.get("success",false):return false
 var receipt:String=str(event.get("event_id",""))
 if receipt.is_empty() or state.evidence.has(receipt):return false
 var skill:String=str(event.get("id",""))
 if not event.get("search_cancelled",false) and skill not in ["TEMP","TINNITUS"]:return false
 state.evidence[receipt]={"target":target,"skill":skill,"cancelled":bool(event.get("search_cancelled",false)),"kind":"cancel" if event.get("search_cancelled",false) else "search_delay"}
 if not state.interference.has(target):state.interference[target]=[]
 state.interference[target].append(receipt)
 return true

func resolve(state:Dictionary,target:String,receipt:String,finder:String,candidates:Array) -> Dictionary:
 if receipt.is_empty() or finder not in ["hero","dog"] or not target in candidates:return {"accepted":false,"newly_found":false,"reason":"invalid_completion"}
 if int(state.get("version",0))!=2:return {"accepted":false,"newly_found":false,"reason":"migration_required"}
 if state.get("eligible_targets",[]).is_empty():return {"accepted":false,"newly_found":false,"reason":"eligible_targets_required"}
 if state.completed.has(target):return {"accepted":false,"newly_found":false,"reason":"already_completed"}
 if state.completion_receipts.has(receipt):return {"accepted":false,"newly_found":false,"reason":"receipt_already_used"}
 var p:float=probability(state,target)
 # CONTROL may complete non-sampled points and earn their normal reward.
 # They are recorded, but cannot widen P56's key set or consume a key draw.
 var eligible:bool=target in _eligible_targets(state)
 var value:float=draw(state,target) if p>0.0 else -1.0
 var guarantee:bool=eligible and remaining_eligible(state)==1 and str(state.discovered).is_empty()
 var found:bool=str(state.discovered).is_empty() and (value<p or guarantee)
 if p<=0.0:found=false
 var verdict:Dictionary={"receipt":receipt,"finder":finder,"eligible":eligible,"probability":p,"draw":value,"found":found,"guaranteed":guarantee,"evidence":state.interference.get(target,[]).duplicate()}
 state.completed[target]=verdict
 state.completion_receipts[receipt]=target
 if found:state.discovered=target
 return {"accepted":true,"newly_found":found,"reason":"discovered" if found else "empty","verdict":verdict.duplicate(true)}

extends RefCounted
## Presentation query only. Healing/death/awakening cannot invent or erase facts.
const DAMAGE_KINDS=["cat_hit","hit","hospital_damage","asylum_damage","cortex_damage","combat_hit"]
static func incidents(facts:Array) -> Array:
 var result:Array=[];var seen:Dictionary={}
 for fact in facts:
  var kind:String=str(fact.get("kind",""));var receipt:String=str(fact.get("event_id",""))
  if kind not in DAMAGE_KINDS or receipt.is_empty() or seen.has(receipt):continue
  if str(fact.get("target","protagonist")) not in ["hero","protagonist"]:continue
  if float(fact.get("hp_damage",0))<=0:continue
  seen[receipt]=true;result.append(fact.duplicate(true))
 return result
static func marks(facts:Array) -> Dictionary:
 var positive:Dictionary={};var result:Dictionary={}
 for incident in incidents(facts):positive[str(incident.event_id)]=incident
 for fact in facts:
  # S3's actual clamp closes on the hand. Its paired zero-damage anatomical
  # marker is not another injury, nor proof of a future facial scar.
  if str(fact.get("kind",""))!="cortex_injury" or fact.get("part","")!="hand" or fact.get("source","")!="clamp":continue
  var id:String=str(fact.get("event_id",""))
  if not id.ends_with(":clamp_wound"):continue
  var contact:String=id.trim_suffix("clamp_wound")+"clamp_damage"
  if not positive.has(contact) or positive[contact].kind!="cortex_damage":continue
  result[id]={"id":id,"part":"hand","source_event":contact,"source":"S3 actual cortex clamp contact; P1716/P1886/P1953"}
 return result

extends RefCounted
## R1 global achievements are separate from profile knowledge and resources.
## Separate entry points accept only the original keys for their real events.
const DEFINITIONS={
 "first_death":"寿司","parent_collapse_death":"矛盾的牺牲品","first_awakening":"睁眼",
 "exposed_player":"谁在操作？","first_control_action":"身体借我一下","control_resisted":"夺舍未遂",
 "autonomous_main_clear":"自由意志","hidden_clear":"又短又快真厉害","host_wins":"梦醒时分",
 "character_wins":"反客为主","player_wins":"借壳上市","self_erased":"静音模式"}
const E1_KEYS=["hidden_clear","host_wins"]
const EVENT_KEYS=["first_death","parent_collapse_death","first_awakening","exposed_player","first_control_action","control_resisted","self_erased"]
var root:String="user://profiles"

func path() -> String:
 var normalized:String=root.trim_suffix("/").trim_suffix("\\")
 return "user://global_progress.json" if normalized=="user://profiles" else normalized.path_join("global_progress.json")

func empty_data() -> Dictionary:
 return {"schema":1,"unlocked":{},"receipts":{}}

func load_progress() -> Dictionary:
 var target:String=ProjectSettings.globalize_path(path())
 var current:Dictionary=_read(target)
 if current.ok:return current
 var backup:Dictionary=_read(target+".bak")
 if backup.ok:
  backup.recovered_backup=true
  return backup
 if FileAccess.file_exists(target) or FileAccess.file_exists(target+".bak"):
  return {"ok":false,"error":"全局成就文件及备份均无效；保留原文件，不覆盖。","data":empty_data()}
 return {"ok":true,"data":empty_data(),"new":true}

func grant_e1(event_id:String) -> Dictionary:
 return grant(E1_KEYS,event_id,"R1:P24/P28/T6R9–10；实际隐藏Street出口")

func grant(keys:Array,event_id:String,source:String) -> Dictionary:
 if event_id.is_empty():return {"ok":false,"error":"缺少实际事件编号"}
 for key in keys:
  if not key in E1_KEYS:return {"ok":false,"error":"该成就触发尚未接入；不能由预览或未知事件解锁"}
 return _grant_valid(keys,event_id,source)

func grant_main(keys:Array,event_id:String) -> Dictionary:
 if event_id.is_empty():return {"ok":false,"error":"缺少实际事件编号"}
 for key in keys:
  if key not in ["player_wins","character_wins","autonomous_main_clear"]:return {"ok":false,"error":"非Street出口成就"}
 return _grant_valid(keys,event_id,"R1:P22–30/P50–51；实际Street终点")

func grant_event(keys:Array,event_id:String) -> Dictionary:
 if event_id.is_empty():return {"ok":false,"error":"缺少实际事件编号"}
 for key in keys:
  if key not in EVENT_KEYS:return {"ok":false,"error":"非实际规则事件成就"}
 return _grant_valid(keys,event_id,"R1:T6R2–7/R13；实际死亡/觉醒/识破/掌控事件")

func _grant_valid(keys:Array,event_id:String,source:String) -> Dictionary:
 var current:Dictionary=load_progress()
 if not current.ok:return current
 var next:Dictionary=current.data.duplicate(true)
 var changed:Array=[]
 for key in keys:
  if next.unlocked.has(key):continue
  next.unlocked[key]={"name":DEFINITIONS[key],"event_id":event_id,"source":source}
  changed.append(key)
 if changed.is_empty():return {"ok":true,"changed":[],"data":next,"path":path()}
 next.receipts[event_id]=changed.duplicate()
 var result:Dictionary=_write(next)
 if result.ok:
  result.changed=changed
  result.data=next
 return result

func _write(data:Dictionary) -> Dictionary:
 var target:String=ProjectSettings.globalize_path(path())
 var error:int=DirAccess.make_dir_recursive_absolute(target.get_base_dir())
 if error!=OK:return {"ok":false,"error":"全局成就目录不可写：%s"%error}
 var payload:String=JSON.stringify(data,"",true)
 var temporary:String=target+".tmp"
 var file:=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:return {"ok":false,"error":"全局成就临时文件不可写"}
 file.store_string(JSON.stringify({"format":1,"payload":payload,"sha256":payload.sha256_text()}))
 file.close()
 if not _read(temporary).ok:return {"ok":false,"error":"全局成就写入校验失败"}
 if FileAccess.file_exists(target) and _read(target).ok:
  error=DirAccess.copy_absolute(target,target+".bak")
  if error!=OK:return {"ok":false,"error":"全局成就备份失败"}
 error=DirAccess.rename_absolute(temporary,target)
 if error==OK:
  # Global achievements have no rollback semantics. Keep a second verified
  # copy of the newest union, rather than a profile-style older snapshot.
  error=DirAccess.copy_absolute(target,target+".bak")
 return {"ok":error==OK,"error":str(error),"path":target}

func _read(target:String) -> Dictionary:
 if not FileAccess.file_exists(target):return {"ok":false}
 var parser:=JSON.new()
 if parser.parse(FileAccess.get_file_as_string(target))!=OK:return {"ok":false}
 var parsed=parser.data
 if not parsed is Dictionary or int(parsed.get("format",0))!=1:return {"ok":false}
 var payload:String=str(parsed.get("payload",""))
 if payload.sha256_text()!=str(parsed.get("sha256","")):return {"ok":false}
 if parser.parse(payload)!=OK:return {"ok":false}
 var data=parser.data
 if not data is Dictionary or int(data.get("schema",0))!=1 or not data.get("unlocked") is Dictionary or not data.get("receipts") is Dictionary:return {"ok":false}
 for key in data.unlocked:
  if not DEFINITIONS.has(key) or not data.unlocked[key] is Dictionary:return {"ok":false}
 return {"ok":true,"data":data}

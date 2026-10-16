extends RefCounted
## One versioned profile slot, checksum and previous-good backup.
var root:String="user://profiles"

func save_snapshot(data:Dictionary) -> Dictionary:
 var folder:String=ProjectSettings.globalize_path(root)
 var error:int=DirAccess.make_dir_recursive_absolute(folder)
 if error!=OK:return {"ok":false,"error":"目录不可写: %s"%error}
 var payload:String=JSON.stringify(data,"",true)
 var envelope:String=JSON.stringify({"format":1,"payload":payload,"sha256":payload.sha256_text()})
 var target:String=folder.path_join("profile.json")
 var temporary:String=target+".tmp"
 var file:=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:return {"ok":false,"error":"存档不可写"}
 file.store_string(envelope)
 file.close()
 if not _read(temporary).ok:return {"ok":false,"error":"写入校验失败"}
 if FileAccess.file_exists(target) and _read(target).ok:
  var prior:Dictionary=_read(target).data
  if int(prior.get("schema",0)) in [1,2] and int(data.get("schema",0))>int(prior.schema):
   var legacy:String=folder.path_join("profile.schema%d.json"%int(prior.schema))
   if not FileAccess.file_exists(legacy):
    error=DirAccess.copy_absolute(target,legacy)
    if error!=OK:return {"ok":false,"error":"旧版存档保留失败"}
  error=DirAccess.copy_absolute(target,target+".bak")
  if error!=OK:return {"ok":false,"error":"备份失败"}
 error=DirAccess.rename_absolute(temporary,target)
 return {"ok":error==OK,"error":str(error),"path":target}

func load_snapshot() -> Dictionary:
 var target:String=ProjectSettings.globalize_path(root).path_join("profile.json")
 var result:Dictionary=_read(target)
 if result.ok:return result
 var backup:Dictionary=_read(target+".bak")
 if backup.ok:
  backup["recovered_backup"]=true
  return backup
 return {"ok":false,"error":"没有可读取的有效存档"}

func _read(path:String) -> Dictionary:
 if not FileAccess.file_exists(path):return {"ok":false}
 var parser:=JSON.new()
 if parser.parse(FileAccess.get_file_as_string(path))!=OK:return {"ok":false}
 var envelope=parser.data
 if not envelope is Dictionary or envelope.get("format",0)!=1:return {"ok":false}
 var payload:String=str(envelope.get("payload",""))
 if payload.sha256_text()!=envelope.get("sha256",""):return {"ok":false}
 if parser.parse(payload)!=OK:return {"ok":false}
 var data=parser.data
 if not data is Dictionary or int(data.get("schema",0)) not in [1,2,3]:return {"ok":false}
 return {"ok":true,"data":data}

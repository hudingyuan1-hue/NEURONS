extends RefCounted
## Saved layout identity is independent from metre-format geometry_version.
## Missing revision on an existing save means the original metric layout.
const CURRENT:int=2
const LEGACY:int=1
const HISTORY:String="res://data/space_history_20261019/"
static var documents:Dictionary={}

static func document(name:String,revision:int=CURRENT) -> Dictionary:
 var path:String=(HISTORY if revision<CURRENT else "res://data/")+name
 if not documents.has(path):
  var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
  assert(parsed is Dictionary,"Missing spatial revision data: "+path)
  documents[path]=parsed
 return documents[path].duplicate(true)

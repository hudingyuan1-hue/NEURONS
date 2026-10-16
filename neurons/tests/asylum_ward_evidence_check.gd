extends "res://tests/asylum_ward_check.gd"
## Actual event contacts plus explicit legacy JSON fixtures. No new signing
## dialogue, no direct control of NPCs, no fabricated label/name glyphs.

func evidence(id:String) -> Dictionary:return app.asylum.ward_events.evidence_target(id)
func evidence_fields(id:String) -> Dictionary:return app.asylum.ward_events.evidence_fields(id)

func finish3() -> void:
 var result:Dictionary={"passes":passes,"failures":failures,"rendered":true,"scope":"B3 statement/product physical ownership, actual handoff/paste/place contacts, dynamic visible anchors, exact save/legacy migration, finite workshop inventory across actual attempts. Signature source only constrains truth; no invented signature action or extra permission gate. Fixed initial actors are explicit fixtures, not natural-RNG/human full playthrough or formal art/audio acceptance.","methods":{"world_step_seconds":0.025,"normal_campaign_update":true,"actual_checksummed_json":true,"formal_art_accepted":false,"audio_listened":false}}
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"  "));file.close()
 print("ASYLUM_WARD_EVIDENCE_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/ward_evidence"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="精神病院纸件物权验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 therapy_fixture()
 check(evidence("asylum_statement_paper").is_empty(),"unexposed director-held statement is not remotely readable")
 check(app.rules.owners.get("asylum_statement_paper","")=="therapist","one real statement sheet initially remains with director")
 check(until3(func():return ward_state().therapy.phase=="give_paper",8),"director really performs recorder events and approaches before presenting paper")
 step3(0.2)
 var before:String=canonical3(ward_state().therapy)
 var count:int=app.rules.institutional_records.size()
 check(evidence("asylum_statement_paper").is_empty() and not rec3("statement_given"),"unfinished paper contact gives no exposed document or delivery fact")
 check(roundtrip() and canonical3(ward_state().therapy)==before,"mid-handoff JSON preserves exact document metadata and pending contact")
 var clock:float=float(app.asylum.data.clock)
 await frames(5)
 check(canonical3(ward_state().therapy)==before and is_equal_approx(float(app.asylum.data.clock),clock),"real manual pause freezes pending handoff and evidence version")
 check(until3(func():return ward_state().therapy.paper=="speaker",2),"only actual handoff completion changes statement owner")
 var sheet:Dictionary=evidence("asylum_statement_paper")
 check(sheet.get("holder","")=="speaker" and sheet.get("room","")=="group_therapy" and sheet.get("visible",false),"exposed paper anchor follows its one actual speaker holder")
 check(app.rules.owners.asylum_statement_paper=="speaker" and int(sheet.version)==2 and ward_state().therapy.statement_asset.history.size()==1,"one contact produces one version and one physical handover history")
 var paper_fields:Dictionary=evidence_fields("asylum_statement_paper")
 check(paper_fields.get("text","")=="此前所述均不属实" and paper_fields.get("actually_signed",true)==null and paper_fields.get("acknowledged",true)==null,"readable exact source sentence is separate from assent and unknown genuine signature")
 check(paper_fields.get("prefilled_name",true)==null and paper_fields.get("proxy_signature",true)==null,"missing name and proxy-signature glyphs stay unknown")
 check(not "asylum_statement_paper" in app.rules.known and app.rules.institutional_records.size()==count,"requesting an evidence descriptor never grants reading knowledge or new institutional records")
 var revision:String=app.asylum.ward_events.evidence_revision("asylum_statement_paper")
 app.asylum.actor("speaker").pos=[2.8,0.95]
 check(same_point3(evidence("asylum_statement_paper").pos,[2.8,0.95]) and app.asylum.ward_events.evidence_revision("asylum_statement_paper")==revision,"paper moves with holder without inventing a new text revision")
 app.asylum.actor("speaker").phase="gone";step3()
 check(evidence("asylum_statement_paper").is_empty() and ward_state().therapy.statement_asset.holder=="speaker","departed holder ends readability without teleporting sheet back to director")
 check(roundtrip() and app.rules.owners.asylum_statement_paper=="speaker" and evidence("asylum_statement_paper").is_empty(),"JSON preserves unobservable paper ownership without respawning another sheet")
 check(evidence("asylum_signature_record").get("holder","")=="therapist" and evidence_fields("asylum_signature_record").actual_signature==null,"source-existing signature appendix stays with director without inventing genuine signing")
 check(evidence_fields("asylum_signature_record").prefilled_name==null and evidence_fields("asylum_signature_record").proxy_signature==null and ward_state().therapy.signature_asset.history.is_empty(),"unknown prefilled/proxy fields stay null and create no invented signing history")
 app.asylum.actor("therapist").phase="gone"
 check(evidence("asylum_signature_record").is_empty() and app.rules.owners.asylum_signature_record=="therapist","absent clipboard holder removes remote reading but preserves actual record ownership")

 ward_fixture("workshop");app.hero_pos=Vector2(2.8,2.2)
 actor3("labor_patient","workshop",app.layout.furniture[7].at)
 check(evidence("asylum_product_label").is_empty(),"material rack and absent box expose no finished product label")
 check(until3(func():return ward_state().work.box=="folded",5),"real folding contact creates only a folded intermediate")
 check(evidence("asylum_product_label").is_empty() and app.rules.owners.asylum_work_box=="labor_patient","folded held paper is not a labelled table product")
 check(until3(func():return ward_state().work.phase=="paste",7),"worker actually fetches existing label and returns to table two")
 step3(0.2)
 check(evidence("asylum_product_label").is_empty() and ward_state().work.label=="labor_patient","loose label and unfinished paste cannot expose completed label content")
 var work_before:String=canonical3(ward_state().work)
 check(roundtrip() and canonical3(ward_state().work)==work_before,"mid-paste JSON preserves separate box and loose-label ownership")
 check(until3(func():return ward_state().work.box=="labelled",2),"real paste contact attaches one existing label to folded box")
 var product:Dictionary=evidence("asylum_product_label")
 check(product.get("holder","")=="workshop_table2" and app.rules.owners.asylum_work_label=="asylum_work_box","label is physically attached to same table-held box at paste contact")
 check(evidence_fields("asylum_product_label").batch==null and not evidence_fields("asylum_product_label").placed and evidence_fields("asylum_product_label").contents==null,"unprovided batch and actual contents stay unknown while separate placement remains pending")
 check(not "asylum_product_label" in app.rules.known,"making a labelled product does not remotely teach protagonist its contents")
 check(until3(func():return ward_state().work.phase=="done",2),"separate real placement finishes one product")
 check(evidence_fields("asylum_product_label").placed and int(ward_state().work.products)==1 and ward_state().work.box_asset.history.size()==6,"six physical work contacts produce one finite product with persistent history")
 var product_pos:Array=evidence("asylum_product_label").pos.duplicate()
 revision=app.asylum.ward_events.evidence_revision("asylum_product_label")
 app.asylum.actor("labor_patient").pos=[4.3,1.0]
 check(same_point3(evidence("asylum_product_label").pos,product_pos),"placed box stays on actual table when worker walks away")
 check(roundtrip() and app.asylum.ward_events.evidence_revision("asylum_product_label")==revision,"JSON preserves completed product version and actual owner")
 step3(4)
 check(int(ward_state().work.products)==1 and ward_state().work.box_asset.history.size()==6,"continued frames cannot duplicate product or paper-contact history")
 app.asylum.start_attempt();app.asylum.ward_events.state()
 check(int(ward_state().work.products)==1 and evidence_fields("asylum_product_label").placed and app.rules.owners.asylum_work_box=="workshop_table2","new real attempt keeps finite workshop product and attached label instead of refilling")

 # Explicit legacy snapshots test migration, not a newly executed handover.
 therapy_fixture();ward_state().therapy.paper="speaker";ward_state().therapy.erase("statement_asset")
 check(roundtrip() and evidence("asylum_statement_paper").holder=="speaker" and ward_state().therapy.statement_asset.history.is_empty(),"legacy speaker-owned paper restores existing visibility without forging contact history")
 check(not rec3("statement_given") and not ward_state().therapy.retraction_spoken,"legacy paper ownership alone cannot invent new delivery receipt or spoken retraction")
 ward_fixture("workshop");ward_state().work.box="table2";ward_state().work.label="rack";ward_state().work.products=0;ward_state().work.erase("box_asset")
 check(roundtrip() and evidence("asylum_product_label").is_empty(),"inconsistent old table marker without pasted label or completed product is not readable")
 ward_state().work.label="box";ward_state().work.products=1
 check(roundtrip() and evidence_fields("asylum_product_label").placed and ward_state().work.box_asset.history.is_empty(),"legacy genuinely completed labelled box migrates without fabricating production history")
 finish3()

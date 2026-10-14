extends AudioStreamPlayer
## Short local synthesis for provisional interface feedback, not final sound art.
var enabled := true

func cue(kind:String) -> void:
 if not enabled:
  return
 var hz:float={"open":170.0,"close":120.0,"success":440.0,"invalid":82.0,"transfer":660.0,"hit":65.0}.get(kind,220.0)
 var rate:=22050
 var count:=int(rate*0.12)
 var data:=PackedByteArray()
 data.resize(count*2)
 for i in range(count):
  var t:=float(i)/rate
  var envelope:=pow(1.0-float(i)/count,2)*minf(1.0,float(i)/120)
  var value:=int(sin(TAU*hz*t)*envelope*2600)
  data.encode_s16(i*2,value)
 var wav:=AudioStreamWAV.new()
 wav.format=AudioStreamWAV.FORMAT_16_BITS
 wav.mix_rate=rate
 wav.data=data
 stream=wav
 play()


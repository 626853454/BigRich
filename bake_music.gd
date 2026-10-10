extends SceneTree
func _initialize()->void:
	for name:String in ["music_calm","music_groove"]:
		var bytes:PackedByteArray=FileAccess.get_file_as_bytes("res://assets/mahjong_night/show/audio/"+name+".wav")
		assert(bytes.slice(0,4).get_string_from_ascii()=="RIFF" and bytes.slice(36,40).get_string_from_ascii()=="data")
		assert(bytes.decode_u16(22)==2 and bytes.decode_u16(34)==16)
		var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.stereo=true;stream.mix_rate=44100;stream.data=bytes.slice(44)
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=stream.data.size()/4
		assert(ResourceSaver.save(stream,"res://assets/mahjong_night/show/audio/"+name+".res")==OK)
	print("MUSIC_PCM_LOOPS_BAKED");quit()

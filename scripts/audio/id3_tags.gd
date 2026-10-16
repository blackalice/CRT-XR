extends RefCounted
## Bounded, read-only text metadata. Artwork and unknown frames are skipped.
const KEYS := {"TIT2":"title","TPE1":"artist","TALB":"album","TRCK":"track","TPOS":"disc","TT2":"title","TP1":"artist","TAL":"album","TRK":"track","TPA":"disc"}
static func integer(bytes: PackedByteArray, sync := false) -> int:
	var value := 0
	for byte in bytes: value=(value<<(7 if sync else 8)) | (byte & (127 if sync else 255))
	return value
static func latin(bytes: PackedByteArray) -> String:
	var text := ""
	for byte in bytes:
		if byte==0: break
		text+=String.chr(byte)
	return text.strip_edges()
static func text(bytes: PackedByteArray) -> String:
	if bytes.is_empty(): return ""
	var encoding := bytes[0]
	var data := bytes.slice(1)
	var result := ""
	if encoding==0: result=latin(data)
	elif encoding==3: result=data.get_string_from_utf8()
	elif encoding in [1,2]:
		var big := encoding==2
		if data.size()>=2 and data[0]==254 and data[1]==255: big=true; data=data.slice(2)
		elif data.size()>=2 and data[0]==255 and data[1]==254: big=false; data=data.slice(2)
		data.resize(data.size()-(data.size()%2))
		if big:
			for i in range(0,data.size(),2):
				var byte := data[i]; data[i]=data[i+1]; data[i+1]=byte
		result=data.get_string_from_utf16()
	return result.replace("\n"," ").replace("\r"," ").replace("\t"," ").strip_edges().left(256)
static func unsync(bytes: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	for i in range(bytes.size()):
		if i>0 and bytes[i]==0 and bytes[i-1]==255: continue
		result.append(bytes[i])
	return result
static var cache: Dictionary = {}
static func read(path: String) -> Dictionary:
	var stamp := FileAccess.get_modified_time(path)
	if cache.has(path) and cache[path].stamp==stamp: return cache[path].tags.duplicate()
	var tags := read_file(path)
	if cache.size()>=2048: cache.clear()
	cache[path]={"stamp":stamp,"tags":tags.duplicate()}
	return tags
static func read_file(path: String) -> Dictionary:
	var result := {"title":path.get_file().get_basename(),"artist":"","album":path.get_base_dir().get_file(),"track":0,"disc":0}
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null: return result
	var found := {}
	var header := file.get_buffer(10)
	if header.size()==10 and header.slice(0,3).get_string_from_ascii()=="ID3" and header[3] in [2,3,4]:
		var version := header[3]
		var size := integer(header.slice(6,10),true)
		# Cap tag parsing at 4 MiB; cover images never become loaded textures.
		if size<=4*1024*1024 and size<=file.get_length()-10 and not (version==2 and header[5]&64):
			var bytes := file.get_buffer(size)
			if version<4 and header[5]&128: bytes=unsync(bytes)
			var offset := 0
			if version>=3 and header[5]&64:
				offset=integer(bytes.slice(0,4),version==4)+(4 if version==3 else 0)
			var width := 6 if version==2 else 10
			for frame in range(256):
				if offset<0 or offset+width>bytes.size(): break
				var name := bytes.slice(offset,offset+(3 if version==2 else 4)).get_string_from_ascii()
				var length := integer(bytes.slice(offset+3,offset+6)) if version==2 else integer(bytes.slice(offset+4,offset+8),version==4)
				if length<=0 or length>bytes.size()-offset-width: break
				var flags := bytes[offset+9] if version>=3 else 0
				var unsupported := (flags&224)!=0 if version==3 else (flags&77)!=0
				if KEYS.has(name) and length<=4096 and not unsupported:
					var data := bytes.slice(offset+width,offset+width+length)
					if version==4 and (flags&2 or header[5]&128): data=unsync(data)
					var value := text(data)
					if not value.is_empty(): found[KEYS[name]]=value
				offset+=width+length
	if file.get_length()>=128:
		file.seek(file.get_length()-128)
		var tail := file.get_buffer(128)
		if tail.slice(0,3).get_string_from_ascii()=="TAG":
			for entry in [["title",3],["artist",33],["album",63]]:
				var value := latin(tail.slice(entry[1],entry[1]+30))
				if not found.has(entry[0]) and not value.is_empty(): found[entry[0]]=value
			if not found.has("track") and tail[125]==0 and tail[126]>0: found.track=str(tail[126])
	for key in found:
		result[key]=maxi(0,int(str(found[key]).get_slice("/",0))) if key in ["track","disc"] else found[key]
	return result

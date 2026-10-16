extends SceneTree
## Offline albedo/contact combination for Compatibility's direct-light path.
func _initialize():call_deferred("run")
func run():
    var packed:=load("res://build/wood-table/table.scn") as PackedScene
    var table:=packed.instantiate() as MeshInstance3D
    var mat:=table.get_active_material(0) as StandardMaterial3D
    var colour:=mat.albedo_texture.get_image()
    if colour.is_compressed():colour.decompress()
    colour.clear_mipmaps();colour.convert(Image.FORMAT_RGBA8)
    var ao:=Image.load_from_file("res://build/room-bake/table_ao.png")
    if ao.get_size()!=colour.get_size():ao.resize(colour.get_width(),colour.get_height(),Image.INTERPOLATE_LANCZOS)
    var pixels:=colour.get_data();var shades:=ao.get_data();ao.convert(Image.FORMAT_RGBA8);shades=ao.get_data()
    # 8-bit lookup tables avoid millions of pow calls during preparation.
    var linear:PackedFloat32Array=[];linear.resize(256)
    for i in range(256):linear[i]=Color(float(i)/255.0,0,0).srgb_to_linear().r
    var lut:=PackedByteArray();lut.resize(256*256)
    for c in range(256):
        for a in range(256):
            var factor:=lerpf(1.0,float(a)/255.0,.9)
            lut[c*256+a]=roundi(Color(linear[c]*factor,0,0).linear_to_srgb().r*255.0)
    for p in range(0,pixels.size(),4):
        for c in range(3):pixels[p+c]=lut[int(pixels[p+c])*256+int(shades[p])]
    var result:=Image.create_from_data(colour.get_width(),colour.get_height(),false,Image.FORMAT_RGBA8,pixels)
    result.generate_mipmaps()
    if result.compress(Image.COMPRESS_BPTC)!=OK:table.free();quit(1);return
    var texture:=ImageTexture.create_from_image(result)
    var error:=ResourceSaver.save(texture,"res://build/room-bake/table_contact_albedo.res",ResourceSaver.FLAG_COMPRESS)
    var bake_path:="res://build/room-bake/bake.json"
    var manifest=JSON.parse_string(FileAccess.get_file_as_string(bake_path))
    manifest["contact_material"]={"strength":.9,"method":"linear-light colour modulation, sRGB encode, mipmapped BC7","prepared_table_sha256":FileAccess.get_sha256("res://build/wood-table/table.scn"),"output_sha256":FileAccess.get_sha256("res://build/room-bake/table_contact_albedo.res")}
    var file:=FileAccess.open(bake_path,FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  "));file.close()
    table.free();print("CONTACT ALBEDO PREPARED: ",error_string(error));quit(0 if error==OK else 1)

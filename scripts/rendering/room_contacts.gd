extends RefCounted
## Static contact AO in model-local coordinates. Lighting stays dynamic.
static func texture(name: String) -> Texture2D:
    var folder:=ProjectSettings.globalize_path("res://build/room-bake") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("assets/room-bake")
    var path:=folder.path_join(name)
    if not FileAccess.file_exists(path):return null
    var image:=Image.load_from_file(path)
    if image==null:return null
    image.convert(Image.FORMAT_L8);image.generate_mipmaps()
    return ImageTexture.create_from_image(image)
static func apply(world: Node3D, support: Node3D) -> void:
    var folder:=ProjectSettings.globalize_path("res://build/room-bake") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("assets/room-bake")
    var manifest_path:=folder.path_join("bake.json")
    if not FileAccess.file_exists(manifest_path):return
    var data=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    if not data is Dictionary or bool(data.get("console_present",false))!=world.television.has_node("ConsoleProp") or absf(float(data.get("floor_y",1000))-(world.support_floor_y-.01))>.001:
        push_warning("Room contact bake does not match this layout; run scripts/rebake-room.ps1.");return
    if not support.has_node("TopShelf"):return
    var table:=support.get_node("TopShelf") as MeshInstance3D
    var material:=table.get_active_material(0) as StandardMaterial3D
    var floor_ao:=texture("floor_ao.png")
    if material==null or floor_ao==null:return
    var shaded:=material.duplicate() as StandardMaterial3D
    # Compatibility does not apply native AO to direct lighting. Use the
    # offline linear-light colour/contact combination, without another pass.
    var colour_path:=folder.path_join("table_contact_albedo.res")
    if not FileAccess.file_exists(colour_path):return
    shaded.albedo_texture=load(colour_path) as Texture2D
    shaded.ao_enabled=false
    shaded.set_meta("contact_baked_into_colour",true)
    table.material_override=shaded
    # The override replaces the mesh's own material; drop it so its original
    # 2048 albedo (superseded by the contact colour) can leave video memory.
    if table.mesh is ArrayMesh:(table.mesh as ArrayMesh).surface_set_material(0,null)
    var rect:Array=data.floor_rect
    world.floor_material.set_shader_parameter("contact_rect",Vector4(rect[0],rect[1],rect[2],rect[3]))
    world.floor_material.set_shader_parameter("contact_ao",floor_ao)
    world.floor_material.set_shader_parameter("contact_enabled",true)
    # Static shapes use baked contact shading instead of aliasing shadow maps.
    for part in world.television.find_children("*","MeshInstance3D",true,false):
        part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    support.set_meta("contact_bake",true)

extends SceneTree
## Setting up the VITURE Windows SDK from its ZIP, its folder or glasses.dll.
const VitureSdk = preload("res://scripts/tracking/viture_sdk.gd")
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")

func write(path: String, bytes := "x") -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE); file.store_string(bytes); file.close()

func run():
	var root := ProjectSettings.globalize_path("user://sdk-test")
	# An extracted SDK nests its architectures; x86_64 is the one to use.
	var sdk := root.path_join("VITURE_SDK/lib")
	for arch in ["arm64", "x86_64"]:
		write(sdk.path_join(arch).path_join("glasses.dll"), arch)
		write(sdk.path_join(arch).path_join("libusb-1.0.dll"), arch)
	write(sdk.path_join("x86_64/readme.txt"))
	var found := VitureSdk.find_in_folder(root.path_join("VITURE_SDK"))
	check(found.ends_with("x86_64/glasses.dll"), "The x86_64 build is found inside an extracted SDK")
	var out := root.path_join("from-folder")
	var result := VitureSdk.install_from(root.path_join("VITURE_SDK"), out)
	check(result.ok and result.files == 2, "A folder installs its two DLLs")
	check(FileAccess.get_file_as_string(out.path_join("glasses.dll")) == "x86_64", "The x86_64 DLL, not arm64, was copied")
	check(not FileAccess.file_exists(out.path_join("readme.txt")), "Only DLLs are copied")
	var out2 := root.path_join("from-dll")
	result = VitureSdk.install_from(sdk.path_join("x86_64/glasses.dll"), out2)
	check(result.ok and FileAccess.file_exists(out2.path_join("libusb-1.0.dll")), "Choosing glasses.dll copies the DLLs beside it")
	# The ZIP as VITURE supplies it.
	var zip_path := root.path_join("sdk.zip")
	var packer := ZIPPacker.new(); packer.open(zip_path)
	for entry in [["SDK/arm64/glasses.dll", "arm"], ["SDK/x86_64/glasses.dll", "x64"], ["SDK/x86_64/libusb-1.0.dll", "usb"], ["SDK/include/glasses.h", "h"]]:
		packer.start_file(entry[0]); packer.write_file(entry[1].to_utf8_buffer()); packer.close_file()
	packer.close()
	var out3 := root.path_join("from-zip")
	result = VitureSdk.install_from(zip_path, out3)
	check(result.ok and result.files == 2 and FileAccess.get_file_as_string(out3.path_join("glasses.dll")) == "x64", "The ZIP installs its x86_64 DLLs")
	check(not VitureSdk.install_from(root.path_join("nothing-here"), out3).ok, "A missing path fails with a message")
	write(root.path_join("other.dll"))
	check(not VitureSdk.install_from(root.path_join("other.dll"), out3).ok, "Some other DLL is refused")
	var empty := root.path_join("empty.zip"); packer = ZIPPacker.new(); packer.open(empty); packer.start_file("a.txt"); packer.write_file(PackedByteArray([1])); packer.close_file(); packer.close()
	check(not VitureSdk.install_from(empty, out3).ok, "A ZIP without glasses.dll is refused")
	# Where tracking looks: the user-data copy, then the older sdk folder beside the app.
	var app := root.path_join("app"); write(app.path_join("sdk/glasses.dll"))
	# (Run from the editor binary, a developer's ignored res://sdk copy may be found first.)
	check(not VitureSdk.find_dll(app).is_empty(), "The older sdk folder beside the app still works")
	print("VITURE SDK: %d failures" % failures)
	quit(1 if failures else 0)

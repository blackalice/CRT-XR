#include "retro_core.h"
#include "radio_mp3.h"
#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;
void initialize_retrocrt(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) { ClassDB::register_class<RetroCore>(); ClassDB::register_class<RadioMP3Decoder>(); }
}
void uninitialize_retrocrt(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT retrocrt_library_init(
    GDExtensionInterfaceGetProcAddress get_proc, GDExtensionClassLibraryPtr library, GDExtensionInitialization* initialization) {
    GDExtensionBinding::InitObject object(get_proc, library, initialization);
    object.register_initializer(initialize_retrocrt);
    object.register_terminator(uninitialize_retrocrt);
    object.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return object.init();
}

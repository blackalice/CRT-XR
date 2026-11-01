# projectM integration
Pinned projectM v4.1.8: 4967dc003e5206d7df3ff447287f7609c47d2343, LGPL-2.1-or-later.
https://github.com/projectM-visualizer/projectm

`offscreen.patch` changes the final render destination to the caller-bound framebuffer and exports GLEW initialization. Modified by CRT XR on 2026-11-01; upstream files retain LGPL terms.
Build using `bash scripts/build-projectm.sh windows` or `linux`, then rebuild the native extension. Linux requires desktop OpenGL development headers. Windows uses MinGW and GLEW 2.2.0 (notices in GLEW-LICENSE.txt).

Exports include the replaceable shared library and corresponding patched source and build materials. Preserve these source materials in release packages. Library replacement and reverse engineering to debug modifications remain permitted under LGPL section 6. Vendored dependencies retain the notices included with their corresponding sources.

The three presets in assets/visualizer are original CRT XR work under the root MIT licence, without external textures or community preset dependencies. User preset import is deferred.

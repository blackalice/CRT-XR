# CRT XR licensing

Original CRT XR source code and documentation are licensed under the [MIT License](LICENSE), adopted on 17 October 2026. The copyright name follows the project's existing Git author identity.

This grant covers original contributions, including the application scripts, UI, native host/tracking code, build tools and tests, except where a file or portion carries a different upstream notice. It does not relicense third-party material or grant trademark rights.

## Separate components and assets

Keep the notices in [THIRD_PARTY.md](THIRD_PARTY.md) and `third_party/`. Imported/adapted shader portions keep their original terms. The generated diagnostic cartridges explicitly marked CC0 remain CC0. Third-party C++ headers and audio decoders retain their embedded notices.

Downloaded emulator cores, Godot/godot-cpp, models, textures and sounds retain their respective licences. The source-code MIT grant does not make the complete application bundle permissively licensed or commercially distributable. Owner-supplied original CRT XR branding/artwork is included under MIT; third-party assets are excluded. Copyright permission does not grant trademark rights.

## Source publication versus binary releases

The source repository excludes downloaded cores and local model archives. Review the notices for the assets committed to the repository as well as those in any binary package. Include LICENSE, LICENSING.md, THIRD_PARTY.md and the applicable full upstream notices in exports.

The implementation-specific distribution review and corresponding-source requirements are recorded in [docs/CORE-DISTRIBUTION.md](docs/CORE-DISTRIBUTION.md). beta.5 replaces the old downloaded core binaries with locally built pinned-source binaries, retaining per-binary hashes, source archives and build materials. The Nestopia integration is treated conservatively as an in-process GPL combination, with original MIT grants retained. Other cores remain separate libraries under their own terms; no global commercial permission is asserted for the collection.

Keep the corresponding-source package available alongside the exact executable packages. Runtime acceptance and packaging checks do not change the applicable licences.

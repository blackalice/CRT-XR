# CRT XR licensing

Original CRT XR source code and documentation are licensed under the [MIT License](LICENSE), adopted on 17 October 2026. The copyright name follows the project's existing Git author identity.

This grant covers original contributions, including the application scripts, UI, native host/tracking code, build tools and tests, except where a file or portion carries a different upstream notice. It does not relicense third-party material or grant trademark rights.

## Separate components and assets

Keep the notices in [THIRD_PARTY.md](THIRD_PARTY.md) and `third_party/`. Imported/adapted shader portions keep their original terms. The generated diagnostic cartridges explicitly marked CC0 remain CC0. Third-party C++ headers and audio decoders retain their embedded notices.

Downloaded emulator cores, Godot/godot-cpp, models, textures and sounds retain their respective licences. The source-code MIT grant does not make the complete application bundle permissively licensed or commercially distributable. Owner-supplied original CRT XR branding/artwork is included under MIT; third-party assets are excluded. Copyright permission does not grant trademark rights.

## Source publication versus binary releases

The source repository excludes downloaded cores and local model archives. Review the notices for the assets committed to the repository as well as those in any binary package. Include LICENSE, LICENSING.md, THIRD_PARTY.md and the applicable full upstream notices in exports.

The following binary-release questions remain open; the MIT decision does not answer them:

* Nestopia: preserve the upstream GPL notices and corresponding source. Assess the obligations for the in-process host/core combination; dynamic loading is not treated as an automatic exemption.
* Snes9x and Genesis Plus GX: retain their custom licences and component notices, including commercial-use restrictions. Do not market the complete package as MIT-only.
* Official core binaries: existing source snapshots and revision records are retained, but independently reproduced builds/toolchain provenance are still pending. Follow the source-build instructions in docs/DEVELOPMENT.md.
* TV model: the archived creator listing was independently verified as CC BY 4.0; docs/license-evidence/crt-tv.json records the URL and HTML hash. Retain attribution, modifications and source provenance. The listing does not certify the bytes of a later downloaded revision or override separately accepted download terms.

These are distribution review items, not restrictions added to the original MIT source licence. No public binary release has been approved by this document.

# Licence proposal — for review, not yet adopted

Recommendation: **MIT for original CRT XR source code**, with third-party components and assets explicitly excluded from that grant. MIT allows reuse/modification/distribution while retaining the copyright and licence notice. It fits a small open-source hobby application with reusable rendering/UI/launcher code. See the [OSI MIT text](https://opensource.org/license/mit).

No project LICENSE file is being added until the project owner approves the licence and copyright-holder wording. Suggested scope: original source under scripts/, native/ and tests/, and original branding, except files/sections carrying upstream notices. Do not blanket-relicense imported shader code, emulator code, Godot/godot-cpp, audio decoders, model files or CC-BY assets.

This recommendation does not clear the combined binary bundle for public distribution. Nestopia's GPL obligations and the non-commercial terms in Snes9x / Genesis Plus GX require a separate distribution assessment, including corresponding source and the host/core integration. Dynamic loading alone is not a blanket exemption. Source provenance/reproducibility also remains open. Keep THIRD_PARTY.md and all actual upstream notices with the distribution.

Decision for the owner: accept MIT for original contributions (and choose the copyright name), choose a different licence, or keep the candidate private while distribution terms are resolved. A core-free host package with users supplying compatible cores is a possible distribution design to assess; it is not assumed to resolve every integration obligation.

# Meizu M5c: Android 11 / LineageOS 18.1

Source port: the internal complete-input snapshot passed static product-copy closure and all 11 init files passed the SDK30 init parser. C/C++ compilation, a full ROM build and device runtime remain unverified. The public subset intentionally omits non-redistributable inputs, so the private static result is not a build result for this public checkout.

## What this branch contains

Real device configuration, init/fstab/SELinux integration and available userspace source from the project's existing bring-up tree. It is an audited source publication, not a placeholder or a flashable ROM.

Source checkpoint: `6d74feccf6ebb5f29747bbbee9493e2f4c114874`. `PUBLICATION.json` records excluded inputs and comment/diagnostic redactions. Existing public history is preserved; the private source repository and its history were not rewritten.

## Build boundary

A complete ROM still requires separately supplied proprietary vendor components and the exact matching kernel input. Those binaries are intentionally absent. The kernel freshness checks and missing-dependency failures remain enabled; no fake replacement or allow-missing flag was added.
The inherited GPS component has restrictive third-party notices and is withheld. Its dependency is still unresolved; this branch is not a complete ROM build manifest.
The existing common MTK source delta and native contract-test source are provided as `patches/vendor_mediatek_a11_contract.patch`; its base and limits are recorded alongside it.

## Validation status

No ROM/kernel compilation or hardware operation was performed by this publication. Older inline comments describe their original checkpoint; this README records the publication status. Bring-up settings include permissive SELinux and may relax ADB authentication; this is development source, not a secure production release.

Suitable follow-up work includes source review, init/XML/static checks and separately pinned open-source component compilation. A complete proprietary-free ROM build has not been demonstrated. Retained source notices apply per file; publication does not relicense third-party code. Older public ancestry already includes artifacts, so the full repository history is not claimed to contain source only.

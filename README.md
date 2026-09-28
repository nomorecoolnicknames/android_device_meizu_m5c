# Meizu M5c: Android 13 / LineageOS 20 Treble

Active Android 13 bring-up source snapshot including Treble integration, legacy graphics/RIL shims and a 32-bit Bluetooth HAL. A related Android 13 build has been observed on the device in another bring-up lane; this exact source commit has no new complete build-to-device identity proof. No stable-ROM claim is made.

## What this branch contains

Real device configuration, init/fstab/SELinux integration and available userspace source from the project's existing bring-up tree. It is an audited source publication, not a placeholder or a flashable ROM.

Source checkpoint: `1900fff274c7544c8705db3a0dfe262a63511ef1`. `PUBLICATION.json` records excluded inputs and comment/diagnostic redactions. Existing public history is preserved; the private source repository and its history were not rewritten.

## Build boundary

A complete ROM still requires separately supplied proprietary vendor components and the exact matching kernel input. Those binaries are intentionally absent. The kernel freshness checks and missing-dependency failures remain enabled; no fake replacement or allow-missing flag was added.
The RIL daemon also requires two proprietary static archives, and two command-table headers have restrictive third-party notices. These four inputs are withheld; RIL source is therefore published for review and porting, with those dependencies explicitly unresolved.

## Validation status

No ROM/kernel compilation or hardware operation was performed by this publication. Older inline comments describe their original checkpoint; this README records the publication status. Bring-up settings include permissive SELinux and may relax ADB authentication; this is development source, not a secure production release.

Suitable follow-up work includes source review, init/XML/static checks and separately pinned open-source component compilation. A complete proprietary-free ROM build has not been demonstrated. Retained source notices apply per file; publication does not relicense third-party code. Older public ancestry already includes artifacts, so the full repository history is not claimed to contain source only.

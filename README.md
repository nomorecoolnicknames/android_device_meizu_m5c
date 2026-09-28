# Meizu M5c: Android 9 / LineageOS 16.0

Historical Android 9 device implementation, imported from the preserved device snapshot. No new ROM build or device runtime was performed for this publication.

## What this branch contains

Real device configuration, init/fstab/SELinux integration and available userspace source from the project's existing bring-up tree. It is an audited source publication, not a placeholder or a flashable ROM.

Source checkpoint: `2e2b0640d9519b7295aa02dc73e7a271b248902f`. `PUBLICATION.json` records excluded inputs and comment/diagnostic redactions. Existing public history is preserved; the private source repository and its history were not rewritten.

## Build boundary

A complete ROM still requires separately supplied proprietary vendor components and the exact matching kernel input. Those binaries are intentionally absent. The kernel freshness checks and missing-dependency failures remain enabled; no fake replacement or allow-missing flag was added.
The inherited GPS component has restrictive third-party notices and is withheld. Its dependency is still unresolved; this branch is not a complete ROM build manifest.

## Validation status

No ROM/kernel compilation or hardware operation was performed by this publication. Older inline comments describe their original checkpoint; this README records the publication status. Bring-up settings include permissive SELinux and may relax ADB authentication; this is development source, not a secure production release.

Suitable follow-up work includes source review, init/XML/static checks and separately pinned open-source component compilation. A complete proprietary-free ROM build has not been demonstrated. Retained source notices apply per file; publication does not relicense third-party code. Older public ancestry already includes artifacts, so the full repository history is not claimed to contain source only.

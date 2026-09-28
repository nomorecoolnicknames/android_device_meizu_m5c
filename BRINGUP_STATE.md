# M5c public source checkpoint — 2026-09-29

FACT: imported Android 13 / LineageOS 20 Treble source checkpoint `1900fff274c7544c8705db3a0dfe262a63511ef1` through an audited source-only publication.

Active Android 13 bring-up source snapshot including Treble integration, legacy graphics/RIL shims and a 32-bit Bluetooth HAL. A related Android 13 build has been observed on the device in another bring-up lane; this exact source commit has no new complete build-to-device identity proof. No stable-ROM claim is made.

FACT: no canonical working tree, phone or cloud job was modified. Private binaries, restrictive-notice dependencies, old backups and unit identifiers were not added to the published branch. See `PUBLICATION.json` for exact exclusions; the kernel identity gate remains enabled.

Next gate: select reproducible legally usable dependencies, run branch-appropriate source/module checks, then an explicitly identified complete build and device readback/runtime validation. Publication itself is not that gate.

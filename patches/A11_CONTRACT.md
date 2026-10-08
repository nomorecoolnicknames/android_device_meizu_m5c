# Android 11 RIL contract patch

vendor_mediatek_a11_contract.patch keeps three legacy RIL behaviours on
Android 11: the NULL MF path, the empty PDP list and the InitialAttachApn
layout. It adds a source-only native test (tests/legacy_contract_test.c).

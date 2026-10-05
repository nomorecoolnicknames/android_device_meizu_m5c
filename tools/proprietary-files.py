#!/usr/bin/env python3
# proprietary-files.py — writes proprietary-files.txt from the vendor tree.
#
#   tools/proprietary-files.py VENDOR_TREE > proprietary-files.txt
#
# VENDOR_TREE is vendor/meizu/m5c (branch lineage-20-treble).  The list is
# what the build installs from its proprietary/ directory, one "SRC:DST" line
# per file (SRC under proprietary/, DST in the image), grouped by how it gets
# there:
#   copied    m5c-vendor-blobs.mk PRODUCT_COPY_FILES, evaluated by GNU make
#             (so the filter-out of wired ELFs at its end applies);
#   patched   Android.mk m5c-treble-blob with same-length path rewrites;
#   wired     Android.mk m5c-treble-blob, DT_NEEDED edits of
#             treble-elf-wiring.txt only;
#   module    Android.mk BUILD_PREBUILT modules (linked by name).
# The header is kept in proprietary-files.header next to the output.
import os
import re
import subprocess
import sys
import tempfile


def copied(vt):
    with tempfile.TemporaryDirectory() as d:
        os.makedirs(os.path.join(d, "vendor/meizu"))
        os.symlink(os.path.abspath(vt), os.path.join(d, "vendor/meizu/m5c"))
        mk = os.path.join(d, "eval.mk")
        with open(mk, "w") as f:
            # No odm partition: the build puts odm inside vendor.
            f.write("TARGET_COPY_OUT_VENDOR := vendor\n"
                    "TARGET_COPY_OUT_ODM := vendor/odm\n"
                    "include vendor/meizu/m5c/m5c-vendor-blobs.mk\n"
                    "$(info $(PRODUCT_COPY_FILES))\nall:;@:\n")
        out = subprocess.run(["make", "-s", "-C", d, "-f", mk], check=True,
                             capture_output=True, text=True).stdout
    pre = "vendor/meizu/m5c/proprietary/"
    pairs = [w.split(":", 1) for w in out.split()]
    return [(s[len(pre):], t) for s, t in pairs if s.startswith(pre)]


def android_mk(vt):
    text = open(os.path.join(vt, "Android.mk")).read()
    wired = {l.split()[0] for l in open(os.path.join(vt, "treble-elf-wiring.txt"))
             if l.strip() and not l.startswith("#")}
    patched = re.findall(r"^\$\(eval \$\(call m5c-treble-blob,([^,]+),([^,]*),", text, re.M)
    patched = [rel for rel, rewrites in patched if rewrites]
    modules = []
    for block in text.split("include $(CLEAR_VARS)")[1:]:
        block = block.split("include $(BUILD_PREBUILT)")[0]
        for m in re.finditer(r"proprietary/(\S+)|\$\(M5C_SHINFO_DIR\)/(\S+)", block):
            modules.append(m.group(1) or m.group(2))
    return patched, sorted(wired - set(patched)), modules


def main(argv):
    if len(argv) != 2:
        sys.exit("usage: tools/proprietary-files.py VENDOR_TREE > proprietary-files.txt")
    vt = argv[1]
    here = os.path.dirname(os.path.abspath(__file__))
    sys.stdout.write(open(os.path.join(here, "proprietary-files.header")).read())
    patched, wired, modules = android_mk(vt)
    groups = [
        ("copied as they are (m5c-vendor-blobs.mk)", copied(vt)),
        ("path-patched copies (Android.mk m5c-treble-blob; also wired if listed "
         "in treble-elf-wiring.txt)", [(r, "vendor/" + r) for r in patched]),
        ("DT_NEEDED-wired copies (Android.mk m5c-treble-blob, "
         "treble-elf-wiring.txt)", [(r, "vendor/" + r) for r in wired]),
        ("prebuilt modules (Android.mk; the 64-bit RIL pair with its .dynsym "
         "sh_info fixed)", [(r, "vendor/" + r) for r in modules]),
    ]
    seen = set()
    for title, pairs in groups:
        print(f"\n## {title}")
        for src, dst in sorted(pairs, key=lambda p: p[1]):
            if dst in seen:
                sys.exit(f"{dst}: installed twice")
            seen.add(dst)
            print(f"{src}:{dst}")


if __name__ == "__main__":
    main(sys.argv)

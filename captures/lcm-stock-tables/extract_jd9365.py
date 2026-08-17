import struct, sys
ELF="/home/valakas/m5c/kernel-reverse/vmlinux.elf"
f=open(ELF,'rb'); d=f.read()
assert d[:4]==b'\x7fELF'
phoff=struct.unpack_from('<Q',d,0x20)[0]
phentsz=struct.unpack_from('<H',d,0x36)[0]
phnum=struct.unpack_from('<H',d,0x38)[0]
loads=[]
for i in range(phnum):
    o=phoff+i*phentsz
    ptype=struct.unpack_from('<I',d,o)[0]
    if ptype==1:
        off,vaddr,_,fsz=struct.unpack_from('<QQQQ',d,o+8)[:4]
        loads.append((vaddr,off,fsz))
def va2off(va):
    for vaddr,off,fsz in loads:
        if vaddr<=va<vaddr+fsz: return off+(va-vaddr)
    raise Exception(hex(va))
def dump_table(va,n,name):
    out=["static struct LCM_setting_table %s[] = {"%name]
    o=va2off(va)
    for i in range(n):
        e=d[o+i*72:o+(i+1)*72]
        cmd=struct.unpack_from('<I',e,0)[0]
        cnt=e[4]
        para=e[5:5+64]
        ps=",".join("0x%02X"%b for b in para[:max(cnt,1)]) if cnt else "0x00"
        out.append("\t{0x%02X, %d, {%s} },"%(cmd,cnt,ps))
    out.append("};")
    return "\n".join(out)
print("/* jd9365 init table: stock VA 0xffffffc00101fe40, 227 entries */")
print(dump_table(0xffffffc00101fe40,0xe3,"lcm_initialization_setting"))
print()
print("/* jd9365 suspend table: stock VA 0xffffffc001023e18, 6 entries */")
print(dump_table(0xffffffc001023e18,6,"lcm_suspend_setting"))

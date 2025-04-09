import requests

response = requests.get("https://raw.githubusercontent.com/Webassembly/wabt/main/include/wabt/opcode.def")
data = response.text

def leb(x):
    out = []
    while x > 0:
        byte = x & 0b1111111
        x >>= 7

        if x > 0:
            byte |= 0b10000000

        out.append(byte)
    return out

opcodes = []
for line in filter(lambda l: l.startswith("WABT_OPCODE("), map(lambda l: l.strip(), data.split('\n'))):
    _, _, _, _, _, opcode, prefix, _, name, _ = map(lambda x: x.strip(), line.strip("WABT_OPCODE(")[0:-1].split(","))
    opcode, prefix = map(lambda x: int(x, 16), [opcode, prefix])
    byte = [prefix] if opcode == 0 else [opcode] + leb(prefix)
    opcodes.append(("@" + name, byte))

opcodes.remove(("@\"select\"", [0x1b]))

with open("inst.zig", "w") as f:
    f.write("pub fn bytes(inst: Inst) []const u8 {\n\treturn switch (inst) {\n")
    for (name, byte) in opcodes:
        f.write(f"\t\t.{name} => &.{{{str(byte)[1:-1]}}},\n")
    f.write("\t};\n}\n\n")

    f.write("pub const Inst = enum {\n")
    for (name, _) in opcodes:
        f.write(f"\t{name},\n")
    f.write("};\n")


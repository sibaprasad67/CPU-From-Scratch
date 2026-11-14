"""
asm.py - Lightweight RISC-V Mini-Assembler for your CPU.
Assembles .s assembly text files into .hex machine code.
Supports: add, sub, and, or, slt, addi, lw, sw, beq, bne, jal, nop
Supports labels, comments, and immediate offsets.
"""

import sys
import re
from pathlib import Path

def reg_num(r):
    r = r.strip().lower()
    if r.startswith("x"):
        return int(r[1:])
    abi = {"zero":0,"ra":1,"sp":2,"gp":3,"tp":4,"t0":5,"t1":6,"t2":7,
           "s0":8,"fp":8,"s1":9,"a0":10,"a1":11,"a2":12,"a3":13,"a4":14,"a5":15,
           "a6":16,"a7":17,"s2":18,"s3":19,"s4":20,"s5":21,"s6":22,"s7":23,
           "s8":24,"s9":25,"s10":26,"s11":27,"t3":28,"t4":29,"t5":30,"t6":31}
    return abi.get(r, 0)

def assemble_file(src_path, dst_path):
    lines = Path(src_path).read_text(encoding="utf-8").splitlines()
    
    # Pass 1: Parse labels and instructions
    instructions = []
    labels = {}
    current_pc = 0

    for line in lines:
        raw = line.split("//")[0].split("#")[0].strip()
        if not raw:
            continue
        # Check label
        if ":" in raw:
            parts = raw.split(":", 1)
            label = parts[0].strip()
            labels[label] = current_pc
            raw = parts[1].strip()
            if not raw:
                continue

        instructions.append((current_pc, raw))
        current_pc += 4

    # Pass 2: Encode machine code
    hex_lines = []
    for pc, text in instructions:
        parts = re.split(r"[\s,]+", text.strip())
        op = parts[0].lower()

        if op == "nop":
            word = 0x00000013
        elif op in ("add", "sub", "and", "or", "slt"):
            rd = reg_num(parts[1])
            rs1 = reg_num(parts[2])
            rs2 = reg_num(parts[3])
            f3 = {"add": 0, "sub": 0, "slt": 2, "or": 6, "and": 7}[op]
            f7 = 0x20 if op == "sub" else 0
            word = (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x33
        elif op == "addi":
            rd = reg_num(parts[1])
            rs1 = reg_num(parts[2])
            imm = int(parts[3], 0) & 0xFFF
            word = (imm << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x13
        elif op == "lw":
            rd = reg_num(parts[1])
            # parse offset(rs1)
            m = re.match(r"(-?\d+|0x[0-9a-fA-F]+)\((x\d+|[a-z0-9]+)\)", parts[2])
            imm = int(m.group(1), 0) & 0xFFF
            rs1 = reg_num(m.group(2))
            word = (imm << 20) | (rs1 << 15) | (2 << 12) | (rd << 7) | 0x03
        elif op == "sw":
            rs2 = reg_num(parts[1])
            m = re.match(r"(-?\d+|0x[0-9a-fA-F]+)\((x\d+|[a-z0-9]+)\)", parts[2])
            imm = int(m.group(1), 0) & 0xFFF
            rs1 = reg_num(m.group(2))
            imm_hi = (imm >> 5) & 0x7F
            imm_lo = imm & 0x1F
            word = (imm_hi << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | (imm_lo << 7) | 0x23
        elif op in ("beq", "bne"):
            rs1 = reg_num(parts[1])
            rs2 = reg_num(parts[2])
            target_str = parts[3]
            if target_str in labels:
                offset = labels[target_str] - pc
            else:
                offset = int(target_str, 0)
            offset &= 0x1FFF
            b12 = (offset >> 12) & 1
            b11 = (offset >> 11) & 1
            b10_5 = (offset >> 5) & 0x3F
            b4_1 = (offset >> 1) & 0xF
            f3 = 0 if op == "beq" else 1
            word = (b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (b4_1 << 8) | (b11 << 7) | 0x63
        elif op == "jal":
            rd = reg_num(parts[1])
            target_str = parts[2]
            if target_str in labels:
                offset = labels[target_str] - pc
            else:
                offset = int(target_str, 0)
            offset &= 0x1FFFFF
            j20 = (offset >> 20) & 1
            j10_1 = (offset >> 1) & 0x3FF
            j11 = (offset >> 11) & 1
            j19_12 = (offset >> 12) & 0xFF
            word = (j20 << 31) | (j10_1 << 21) | (j11 << 20) | (j19_12 << 12) | (rd << 7) | 0x6F
        else:
            raise ValueError(f"Unknown instruction: {text}")

        hex_lines.append(f"{word:08x} // 0x{pc:02x}: {text}")

    Path(dst_path).write_text("\n".join(hex_lines) + "\n", encoding="utf-8")
    print(f"[+] Assembled {len(hex_lines)} instructions: {src_path} -> {dst_path}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python tools/asm.py input.s output.hex")
    else:
        assemble_file(sys.argv[1], sys.argv[2])

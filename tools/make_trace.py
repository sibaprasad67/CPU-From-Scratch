"""
make_trace.py - runs your real CPU (Icarus Verilog) on each demo program and records,
for every clock cycle, what is in each pipeline stage, the stall/flush/forwarding
signals, all 32 registers and the first 16 words of data memory.

Output (plain .js files so a visualizer can load them straight from disk, no server needed):
    visualizer/data/traces.js    ->  window.CPU_TRACES  = { program_name: {...}, ... }
    visualizer/data/sources.js   ->  window.CPU_SOURCES = { "rtl/alu.v": "...", ... }

Run from the project root:   python tools/make_trace.py
"""
import json, subprocess, sys, tempfile, os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "visualizer" / "data"
PROGRAMS = ["bubble_sort", "fibonacci", "binary_search", "bfs_traversal", "dfs_traversal"]   # programs/<name>.hex (each must set x31 = 1 when finished)
DRAIN = 6          # extra cycles recorded after the program sets its done flag (x31 = 1)
MAXCYC = 3000

TB = r"""
`timescale 1ns/1ps
module trace_tb;
    reg clk, reset;
    integer cycle, i;

    cpu_pipeline #(.PROGRAM_FILE("__PROGRAM__")) uut (.clk(clk), .reset(reset));

    always #5 clk = ~clk;

    task emit;
        begin
            $write("T %0d %h %h %h %h %h %h", cycle, uut.pc, uut.ifid_pc, uut.idex_pc,
                   uut.exmem_pc_plus4, uut.memwb_pc_plus4, uut.pc_target_ex);
            $write(" %h %h %h %h %h", uut.instr_if, uut.ifid_instr, uut.idex_instr,
                   uut.exmem_instr, uut.memwb_instr);
            $write(" %b %b %h %h %h", uut.stall, uut.pc_src, uut.fwd_a_sel, uut.fwd_b_sel,
                   uut.ex_alu_result);
            $write(" %b %h %h", uut.wb_reg_write, uut.wb_rd, uut.wb_data);
            for (i = 0; i < 32; i = i + 1) $write(" %h", uut.u_rf.regs[i]);
            for (i = 0; i < 16; i = i + 1) $write(" %h", uut.u_dmem.mem[i]);
            $write("\n");
        end
    endtask

    initial begin
        clk = 0; reset = 1; cycle = 0;
        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;
        cycle = 1; emit;
        while (uut.u_rf.regs[31] !== 32'd1 && cycle < __MAXCYC__) begin
            @(negedge clk); cycle = cycle + 1; emit;
        end
        repeat (__DRAIN__) begin
            @(negedge clk); cycle = cycle + 1; emit;
        end
        $finish;
    end
endmodule
"""

REGNAMES = [f"x{i}" for i in range(32)]

def s(v, bits):
    return v - (1 << bits) if v >> (bits - 1) & 1 else v

def disasm(w):
    if w == 0x13:
        return "nop"
    op = w & 0x7F; rd = (w >> 7) & 31; f3 = (w >> 12) & 7
    a = (w >> 15) & 31; b = (w >> 20) & 31; f7 = (w >> 25) & 0x7F
    if op == 0x33:
        name = {(0,0):"add",(0x20,0):"sub",(0,7):"and",(0,6):"or",(0,2):"slt"}.get((f7,f3),"r-type?")
        return f"{name} x{rd}, x{a}, x{b}"
    if op == 0x13:
        return f"addi x{rd}, x{a}, {s(w >> 20, 12)}"
    if op == 0x03:
        return f"lw x{rd}, {s(w >> 20, 12)}(x{a})"
    if op == 0x23:
        im = s(((w >> 25) << 5) | ((w >> 7) & 31), 12)
        return f"sw x{b}, {im}(x{a})"
    if op == 0x63:
        im = s((((w >> 31) & 1) << 12) | (((w >> 7) & 1) << 11) |
               (((w >> 25) & 63) << 5) | (((w >> 8) & 15) << 1), 13)
        return f"{'beq' if f3 == 0 else 'bne'} x{a}, x{b}, {im:+d}"
    if op == 0x6F:
        im = s((((w >> 31) & 1) << 20) | (((w >> 12) & 255) << 12) |
               (((w >> 20) & 1) << 11) | (((w >> 21) & 1023) << 1), 21)
        return f"jal x{rd}, {im:+d}"
    return "?"

def read_program(path):
    words = []
    for line in path.read_text(encoding="utf-8").splitlines():
        t = line.split("//")[0].strip()
        if t:
            words.append(int(t.split()[0], 16))
    return [{"pc": 4 * i, "hex": f"{w:08x}", "asm": disasm(w)} for i, w in enumerate(words)]

def run_program(name, rtl_files):
    tb = (TB.replace("__PROGRAM__", f"programs/{name}.hex")
            .replace("__MAXCYC__", str(MAXCYC)).replace("__DRAIN__", str(DRAIN)))
    with tempfile.TemporaryDirectory() as tmp:
        tbf = Path(tmp) / "trace_tb.v"; tbf.write_text(tb)
        vvp = Path(tmp) / "trace.vvp"
        subprocess.run(["iverilog", "-s", "trace_tb", "-o", str(vvp)] + rtl_files + [str(tbf)],
                       cwd=ROOT, check=True)
        res = subprocess.run(["vvp", str(vvp)], cwd=ROOT, check=True,
                             capture_output=True, text=True)
    cycles = []
    for line in res.stdout.splitlines():
        if not line.startswith("T "):
            continue
        f = line.split()[1:]
        it = iter(f)
        n = lambda: next(it)
        cyc = int(n())
        pc, ifid_pc, idex_pc, exmem_p4, memwb_p4, target = [int(n(), 16) for _ in range(6)]
        instr = [int(n(), 16) for _ in range(5)]
        stall = int(n()); flush = int(n()); fa = int(n(), 16); fb = int(n(), 16)
        alu = int(n(), 16)
        wbwe = int(n()); wbrd = int(n(), 16); wbdata = int(n(), 16)
        regs = [int(n(), 16) for _ in range(32)]
        mem = [int(n(), 16) for _ in range(16)]
        def stage(w, pc, is_if=False):
            bub = (w == 0x13)
            return {"pc": None if (bub and not is_if) else pc,
                    "hex": f"{w:08x}", "asm": disasm(w), "bubble": bub}
        cycles.append({
            "cycle": cyc,
            "stages": {
                "IF":  stage(instr[0], pc, True),
                "ID":  stage(instr[1], ifid_pc),
                "EX":  stage(instr[2], idex_pc),
                "MEM": stage(instr[3], (exmem_p4 - 4) & 0xFFFFFFFF),
                "WB":  stage(instr[4], (memwb_p4 - 4) & 0xFFFFFFFF),
            },
            "stall": stall, "flush": flush, "branch_target": target,
            "fwd_a": fa, "fwd_b": fb,           # 0 = register file, 2 = from EX/MEM, 1 = from WB
            "alu_result": alu,
            "wb": {"write": wbwe, "reg": wbrd, "data": wbdata},
            "regs": regs, "mem": mem,
        })
    retired = sum(1 for c in cycles if not c["stages"]["WB"]["bubble"])
    summary = {"cycles": len(cycles), "instructions": retired,
               "stalls": sum(c["stall"] for c in cycles),
               "branch_flushes": sum(c["flush"] for c in cycles)}
    summary["cpi"] = round(summary["cycles"] / max(retired, 1), 2)
    return {"program": read_program(ROOT / "programs" / f"{name}.hex"),
            "cycles": cycles, "summary": summary}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rtl = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "rtl").glob("*.v"))
    traces = {}
    for name in PROGRAMS:
        if not (ROOT / "programs" / f"{name}.hex").exists():
            print("skip (no hex):", name); continue
        traces[name] = run_program(name, rtl)
        sm = traces[name]["summary"]
        print(f"{name:12s} cycles={sm['cycles']} instructions={sm['instructions']} "
              f"stalls={sm['stalls']} flushes={sm['branch_flushes']} CPI={sm['cpi']}")
    (OUT / "traces.js").write_text("window.CPU_TRACES = " + json.dumps(traces) + ";\n", encoding="utf-8")
    sources = {}
    for p in sorted((ROOT / "rtl").glob("*.v")):
        sources[f"rtl/{p.name}"] = p.read_text(encoding="utf-8")
    for name in PROGRAMS:
        p = ROOT / "programs" / f"{name}.hex"
        if p.exists():
            sources[f"programs/{name}.hex"] = p.read_text(encoding="utf-8")
    (OUT / "sources.js").write_text("window.CPU_SOURCES = " + json.dumps(sources) + ";\n", encoding="utf-8")
    print("wrote", OUT / "traces.js", "and", OUT / "sources.js")

if __name__ == "__main__":
    main()
`timescale 1ns/1ps
module pipeline_tb;
    reg     clk, reset;
    integer errors, cycle;

    cpu_pipeline #(.PROGRAM_FILE("programs/pipe_test.hex")) uut (
        .clk(clk), .reset(reset)
    );

    always #5 clk = ~clk;

    task check(input [31:0] got, input [31:0] expected, input [159:0] name);
        begin
            if (got !== expected) begin
                $display("FAIL %0s: got=%h expected=%h", name, got, expected);
                errors = errors + 1;
            end else
                $display("PASS %0s: got=%h", name, got);
        end
    endtask

    // one line per cycle: the instruction sitting in each pipeline stage
    always @(posedge clk)
        if (!reset) begin
            $display("cycle %2d | IF %h | ID %h | EX %h | MEM %h | WB %h",
                     cycle, uut.instr_if, uut.ifid_instr, uut.idex_instr,
                     uut.exmem_instr, uut.memwb_instr);
            cycle = cycle + 1;
        end

    initial begin
        $dumpfile("simulation/pipeline.vcd");
        $dumpvars(0, pipeline_tb);
        errors = 0; cycle = 0;
        clk = 0; reset = 1;
        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;

        repeat (32) @(posedge clk);
        @(negedge clk);

        check(uut.u_rf.regs[1],  32'd5,        "x1  addi");
        check(uut.u_rf.regs[2],  32'd10,       "x2  addi");
        check(uut.u_rf.regs[3],  32'd15,       "x3  add");
        check(uut.u_rf.regs[4],  32'd10,       "x4  sub");
        check(uut.u_rf.regs[5],  32'd10,       "x5  and");
        check(uut.u_rf.regs[6],  32'd15,       "x6  or");
        check(uut.u_rf.regs[7],  32'd1,        "x7  slt");
        check(uut.u_dmem.mem[0], 32'd15,       "mem[0] sw");
        check(uut.u_dmem.mem[1], 32'd10,       "mem[1] sw");
        check(uut.u_rf.regs[8],  32'd15,       "x8  lw");
        check(uut.u_rf.regs[9],  32'd10,       "x9  lw");
        check(uut.u_rf.regs[10], 32'd25,       "x10 lw+lw");
        check(uut.u_rf.regs[11], 32'hFFFFFFFF, "x11 negative imm");
        check(uut.u_rf.regs[12], 32'hFFFFFFFE, "x12 -1 + -1");
        check(uut.u_rf.regs[0],  32'd0,        "x0 still 0");
        check(uut.pc,            32'h80,       "pc straight-line");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
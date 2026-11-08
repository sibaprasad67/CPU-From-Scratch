`timescale 1ns/1ps
module forward_test_tb;
    reg     clk, reset;
    integer errors, stalls;

    cpu_pipeline #(.PROGRAM_FILE("programs/forward_test.hex")) uut (
        .clk(clk), .reset(reset)
    );

    always #5 clk = ~clk;

    task check(input [31:0] got, input [31:0] expected, input [255:0] name);
        begin
            if (got !== expected) begin
                $display("FAIL %0s: got=%h expected=%h", name, got, expected);
                errors = errors + 1;
            end else
                $display("PASS %0s: got=%h", name, got);
        end
    endtask

    always @(posedge clk)
        if (!reset && uut.stall) stalls = stalls + 1;

    initial begin
        $dumpfile("simulation/forward_test.vcd");
        $dumpvars(0, forward_test_tb);
        errors = 0; stalls = 0;
        clk = 0; reset = 1;
        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;

        repeat (30) @(posedge clk);
        @(negedge clk);

        check(uut.u_rf.regs[1],  32'd5,  "x1 addi");
        check(uut.u_rf.regs[2],  32'd7,  "x2 addi");
        check(uut.u_rf.regs[3],  32'd12, "x3 add (WB + MEM fwd)");
        check(uut.u_rf.regs[0],  32'd0,  "x0 still 0");
        check(uut.u_rf.regs[4],  32'd12, "x4 add x0,x3 (x0 not fwd)");
        check(uut.u_rf.regs[5],  32'd7,  "x5 sub (fwd)");
        check(uut.u_dmem.mem[1], 32'd7,  "mem[1] sw (fwd store data)");
        check(uut.u_rf.regs[6],  32'd7,  "x6 lw");
        check(uut.u_rf.regs[7],  32'd14, "x7 add (load-use)");
        check(uut.u_rf.regs[8],  32'd15, "x8 addi (EX/MEM rs1)");
        $display("stall cycles = %0d", stalls);

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
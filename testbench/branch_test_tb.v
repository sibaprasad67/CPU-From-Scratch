`timescale 1ns/1ps
module branch_test_tb;
    reg     clk, reset;
    integer errors;

    cpu_pipeline #(.PROGRAM_FILE("programs/branch_test.hex")) uut (
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

    initial begin
        $dumpfile("simulation/branch_test.vcd");
        $dumpvars(0, branch_test_tb);
        errors = 0;
        clk = 0; reset = 1;
        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;

        repeat (60) @(posedge clk);
        @(negedge clk);

        check(uut.u_rf.regs[1],  32'd5,   "x1 setup");
        check(uut.u_rf.regs[2],  32'd5,   "x2 setup");
        check(uut.u_rf.regs[3],  32'd0,   "x3 skipped by beq");
        check(uut.u_rf.regs[4],  32'd0,   "x4 skipped by beq");
        check(uut.u_rf.regs[5],  32'd7,   "x5 beq target");
        check(uut.u_rf.regs[6],  32'd9,   "x6 bne not taken");
        check(uut.u_rf.regs[7],  32'h24,  "x7 jal link (pc+4)");
        check(uut.u_rf.regs[8],  32'd0,   "x8 skipped by jal");
        check(uut.u_rf.regs[9],  32'd0,   "x9 skipped by jal");
        check(uut.u_rf.regs[10], 32'd3,   "x10 jal target");
        check(uut.u_rf.regs[11], 32'd0,   "x11 loop counter");
        check(uut.u_rf.regs[12], 32'd3,   "x12 loop ran 3 times");
        check(uut.u_rf.regs[13], 32'd99,  "x13 after loop");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
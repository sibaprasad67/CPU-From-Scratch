`timescale 1ns/1ps
module hazard_test_tb;
    reg     clk, reset;
    integer errors, stalls;

    cpu_pipeline #(.PROGRAM_FILE("programs/hazard_test.hex")) uut (
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

    // count cycles where the hazard unit froze the front of the pipe
    always @(posedge clk)
        if (!reset && uut.stall) stalls = stalls + 1;

    initial begin
        $dumpfile("simulation/hazard_test.vcd");
        $dumpvars(0, hazard_test_tb);
        errors = 0; stalls = 0;
        clk = 0; reset = 1;
        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;

        repeat (30) @(posedge clk);
        @(negedge clk);

        check(uut.u_rf.regs[1],  32'd5,  "x1 addi");
        check(uut.u_rf.regs[2],  32'd8,  "x2 addi uses x1");
        check(uut.u_rf.regs[3],  32'd13, "x3 add uses x1,x2");
        check(uut.u_dmem.mem[0], 32'd13, "mem[0] sw uses x3");
        check(uut.u_rf.regs[4],  32'd13, "x4 lw");
        check(uut.u_rf.regs[5],  32'd26, "x5 add uses lw result");
        $display("stall cycles = %0d", stalls);

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
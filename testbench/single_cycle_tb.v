`timescale 1ns/1ps
module single_cycle_tb;
    reg     clk, reset;
    integer errors, cycle;

    cpu_single_cycle #(.PROGRAM_FILE("programs/test_imem.hex")) uut (
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

    // one trace line per executed cycle
    always @(posedge clk)
        if (!reset) begin
            $display("cycle %0d: pc=%h instr=%h", cycle, uut.pc, uut.instr);
            cycle = cycle + 1;
        end

    initial begin
        $dumpfile("simulation/single_cycle.vcd");
        $dumpvars(0, single_cycle_tb);
        errors = 0; cycle = 0;
        clk = 0; reset = 1;
        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;

        repeat (8) @(posedge clk);
        @(negedge clk);

        check(uut.u_rf.regs[1], 32'd5,        "x1 = 5");
        check(uut.u_rf.regs[2], 32'd10,       "x2 = 10");
        check(uut.u_rf.regs[3], 32'd15,       "x3 = 15");
        check(uut.u_rf.regs[4], 32'hFFFFFFFB, "x4 = -5");
        check(uut.u_rf.regs[0], 32'd0,        "x0 = 0");
        check(uut.pc,           32'd32,       "pc after 8 cycles");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
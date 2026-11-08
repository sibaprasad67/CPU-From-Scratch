`timescale 1ns/1ps
module bubble_sort_tb;
    reg     clk, reset;
    integer errors, cycles, retired, stalls, flushes, i;

    cpu_pipeline #(.PROGRAM_FILE("programs/bubble_sort.hex")) uut (
        .clk(clk), .reset(reset)
    );

    always #5 clk = ~clk;

    task check(input [31:0] got, input [31:0] expected, input [255:0] name);
        begin
            if (got !== expected) begin
                $display("FAIL %0s: got=%0d expected=%0d", name, got, expected);
                errors = errors + 1;
            end else
                $display("PASS %0s: got=%0d", name, got);
        end
    endtask

    // statistics: one count per clock after reset
    always @(posedge clk)
        if (!reset) begin
            cycles = cycles + 1;
            if (uut.memwb_instr !== 32'h00000013) retired = retired + 1;  // real instruction reaches WB
            if (uut.stall)  stalls  = stalls  + 1;
            if (uut.pc_src) flushes = flushes + 1;
        end

    initial begin
        $dumpfile("simulation/bubble_sort.vcd");
        $dumpvars(0, bubble_sort_tb);
        errors = 0; cycles = 0; retired = 0; stalls = 0; flushes = 0;
        clk = 0; reset = 1;
        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;

        // run until the program writes its "done" flag into x31 (or give up)
        while (uut.u_rf.regs[31] !== 32'd1 && cycles < 3000) @(posedge clk);
        repeat (6) @(posedge clk);          // let the pipeline drain
        @(negedge clk);

        $display("--- memory after sort ---");
        for (i = 0; i < 8; i = i + 1)
            $display("mem[%0d] = %0d", i, uut.u_dmem.mem[i]);
        $display("-------------------------");

        check(uut.u_dmem.mem[0], 32'd1, "mem[0]");
        check(uut.u_dmem.mem[1], 32'd2, "mem[1]");
        check(uut.u_dmem.mem[2], 32'd3, "mem[2]");
        check(uut.u_dmem.mem[3], 32'd4, "mem[3]");
        check(uut.u_dmem.mem[4], 32'd5, "mem[4]");
        check(uut.u_dmem.mem[5], 32'd7, "mem[5]");
        check(uut.u_dmem.mem[6], 32'd8, "mem[6]");
        check(uut.u_dmem.mem[7], 32'd9, "mem[7]");
        check(uut.u_rf.regs[31], 32'd1, "done flag x31");

        $display("cycles = %0d   instructions = %0d   stalls = %0d   branch flushes = %0d",
                 cycles, retired, stalls, flushes);
        $display("CPI = %0d.%02d", cycles / retired, ((cycles * 100) / retired) % 100);

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
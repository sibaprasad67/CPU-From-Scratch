`timescale 1ns/1ps
module hazard_demo_tb;
    reg clk, reset;

    cpu_pipeline #(.PROGRAM_FILE("programs/hazard_demo.hex")) uut (
        .clk(clk), .reset(reset)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; reset = 1;
        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;

        repeat (12) @(posedge clk);
        @(negedge clk);

        $display("x1 = %0d   (addi x1, x0, 5)", uut.u_rf.regs[1]);
        $display("x2 = %0d   (add x2, x1, x1 -- should be 10)", uut.u_rf.regs[2]);
        if (uut.u_rf.regs[2] !== 32'd10)
            $display("HAZARD: add read x1 before addi wrote it, so x2 is wrong");
        else
            $display("no hazard visible");
        $finish;
    end
endmodule
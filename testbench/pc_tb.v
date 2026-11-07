`timescale 1ns/1ps
module pc_tb;
    reg         clk, reset, enable, branch_taken;
    reg  [31:0] branch_target;
    wire [31:0] pc, pc_plus4, pc_next;
    integer     errors;

    adder #(.WIDTH(32)) u_add4 (.a(pc), .b(32'd4), .sum(pc_plus4));
    mux2  #(.WIDTH(32)) u_mux  (.a(pc_plus4), .b(branch_target),
                                .sel(branch_taken), .y(pc_next));
    program_counter u_pc (.clk(clk), .reset(reset), .enable(enable),
                          .pc_next(pc_next), .pc(pc));

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

    initial begin
        $dumpfile("simulation/pc.vcd");
        $dumpvars(0, pc_tb);
        errors = 0;
        clk = 0; reset = 1; enable = 1;
        branch_taken = 0; branch_target = 0;
        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;

        check(pc, 32'd0, "reset to 0");
        check(pc_plus4, 32'd4, "pc+4 logic");

        @(negedge clk); check(pc, 32'd4,  "step 1");
        @(negedge clk); check(pc, 32'd8,  "step 2");
        @(negedge clk); check(pc, 32'd12, "step 3");

        branch_taken = 1; branch_target = 32'h40;
        @(negedge clk);
        check(pc, 32'h40, "branch taken");
        branch_taken = 0;
        @(negedge clk);
        check(pc, 32'h44, "continues +4");

        enable = 0;
        @(negedge clk); @(negedge clk);
        check(pc, 32'h44, "stall holds");
        enable = 1;
        @(negedge clk);
        check(pc, 32'h48, "resume");

        reset = 1;
        @(negedge clk);
        check(pc, 32'd0, "reset again");
        reset = 0;

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
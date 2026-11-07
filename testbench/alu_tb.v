`timescale 1ns/1ps
module alu_tb;
    reg  [31:0] a, b;
    reg  [3:0]  alu_ctrl;
    wire [31:0] result;
    wire        zero;
    integer     errors;

    alu uut (.a(a), .b(b), .alu_ctrl(alu_ctrl), .result(result), .zero(zero));

    task check(input [31:0] exp_result, input exp_zero, input [119:0] name);
        begin
            #10;
            if (result !== exp_result || zero !== exp_zero) begin
                $display("FAIL %0s: a=%h b=%h ctrl=%b got=%h zero=%b expected=%h zero=%b",
                         name, a, b, alu_ctrl, result, zero, exp_result, exp_zero);
                errors = errors + 1;
            end else
                $display("PASS %0s: a=%h b=%h result=%h zero=%b",
                         name, a, b, result, zero);
        end
    endtask

    initial begin
        $dumpfile("simulation/alu.vcd");
        $dumpvars(0, alu_tb);
        errors = 0;

        a = 32'hF0F0F0F0; b = 32'h0FF0FF00;
        alu_ctrl = 4'b0000; check(32'h00F0F000, 1'b0, "AND");
        alu_ctrl = 4'b0001; check(32'hFFF0FFF0, 1'b0, "OR");

        a = 32'd10; b = 32'd20;
        alu_ctrl = 4'b0010; check(32'd30, 1'b0, "ADD");

        a = 32'hFFFFFFFF; b = 32'd1;
        alu_ctrl = 4'b0010; check(32'd0, 1'b1, "ADD wrap");

        a = 32'd20; b = 32'd10;
        alu_ctrl = 4'b0110; check(32'd10, 1'b0, "SUB");

        a = 32'd7; b = 32'd7;
        alu_ctrl = 4'b0110; check(32'd0, 1'b1, "SUB equal");

        a = 32'd5; b = 32'd10;
        alu_ctrl = 4'b0110; check(32'hFFFFFFFB, 1'b0, "SUB neg");
        alu_ctrl = 4'b0111; check(32'd1, 1'b0, "SLT true");

        a = 32'd10; b = 32'd5;
        alu_ctrl = 4'b0111; check(32'd0, 1'b1, "SLT false");

        a = 32'hFFFFFFFF; b = 32'd1;
        alu_ctrl = 4'b0111; check(32'd1, 1'b0, "SLT signed");

        a = 32'd1; b = 32'hFFFFFFFF;
        alu_ctrl = 4'b0111; check(32'd0, 1'b1, "SLT signed2");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
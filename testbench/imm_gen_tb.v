`timescale 1ns/1ps
module imm_gen_tb;
    reg  [31:0] instr;
    wire [31:0] imm;
    integer     errors;

    imm_gen uut (.instr(instr), .imm(imm));

    task check(input [31:0] i, input [31:0] expected, input [159:0] name);
        begin
            instr = i; #1;
            if (imm !== expected) begin
                $display("FAIL %0s: instr=%h got=%h expected=%h", name, i, imm, expected);
                errors = errors + 1;
            end else
                $display("PASS %0s: imm=%h", name, imm);
        end
    endtask

    initial begin
        errors = 0;
        check(32'h00500093, 32'd5,        "I addi +5");
        check(32'hFFF00093, 32'hFFFFFFFF, "I addi -1");
        check(32'h00C0A283, 32'd12,       "I lw +12");
        check(32'h0020A423, 32'd8,        "S sw +8");
        check(32'h00208463, 32'd8,        "B beq +8");
        check(32'hFE209EE3, 32'hFFFFFFFC, "B bne -4");
        check(32'h010000EF, 32'd16,       "J jal +16");
        check(32'hFF9FF06F, 32'hFFFFFFF8, "J jal -8");
        check(32'h00000000, 32'd0,        "unknown opcode");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
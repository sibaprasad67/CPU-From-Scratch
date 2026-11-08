`timescale 1ns/1ps
module forwarding_unit_tb;
    reg  [4:0] rs1, rs2, exmem_rd, wb_rd;
    reg        exmem_we, wb_we;
    wire [1:0] fa, fb;
    integer    errors;

    forwarding_unit uut (
        .idex_rs1(rs1), .idex_rs2(rs2),
        .exmem_reg_write(exmem_we), .exmem_rd(exmem_rd),
        .wb_reg_write(wb_we), .wb_rd(wb_rd),
        .forward_a(fa), .forward_b(fb)
    );

    task check(input [4:0] r1, input [4:0] r2,
               input mem_we, input [4:0] mem_rd, input w_we, input [4:0] w_rd,
               input [1:0] exp_a, input [1:0] exp_b, input [255:0] name);
        begin
            rs1 = r1; rs2 = r2;
            exmem_we = mem_we; exmem_rd = mem_rd;
            wb_we = w_we; wb_rd = w_rd;
            #1;
            if (fa !== exp_a || fb !== exp_b) begin
                $display("FAIL %0s: a=%b b=%b expected a=%b b=%b", name, fa, fb, exp_a, exp_b);
                errors = errors + 1;
            end else
                $display("PASS %0s: a=%b b=%b", name, fa, fb);
        end
    endtask

    initial begin
        errors = 0;
        //    rs1 rs2  mem_we mem_rd  wb_we wb_rd   a     b     name
        check(1,  2,   0, 0,          0, 0,        2'b00, 2'b00, "no forwarding");
        check(1,  2,   1, 1,          0, 0,        2'b10, 2'b00, "EX/MEM -> rs1");
        check(1,  2,   1, 2,          0, 0,        2'b00, 2'b10, "EX/MEM -> rs2");
        check(1,  2,   0, 0,          1, 1,        2'b01, 2'b00, "WB -> rs1");
        check(1,  2,   0, 0,          1, 2,        2'b00, 2'b01, "WB -> rs2");
        check(1,  1,   1, 1,          1, 1,        2'b10, 2'b10, "EX/MEM beats WB");
        check(1,  2,   1, 2,          1, 1,        2'b01, 2'b10, "split: WB rs1, MEM rs2");
        check(0,  0,   1, 0,          1, 0,        2'b00, 2'b00, "x0 never forwarded");
        check(1,  2,   0, 1,          0, 2,        2'b00, 2'b00, "reg_write off");
        check(3,  4,   1, 5,          1, 6,        2'b00, 2'b00, "writers elsewhere");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
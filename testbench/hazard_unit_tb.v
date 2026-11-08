`timescale 1ns/1ps
module hazard_unit_tb;
    reg  [6:0] id_opcode;
    reg  [4:0] id_rs1, id_rs2, idex_rd, exmem_rd;
    reg        idex_reg_write, exmem_reg_write;
    wire       stall;
    integer    errors;

    hazard_unit uut (
        .id_opcode(id_opcode), .id_rs1(id_rs1), .id_rs2(id_rs2),
        .idex_reg_write(idex_reg_write), .idex_rd(idex_rd),
        .exmem_reg_write(exmem_reg_write), .exmem_rd(exmem_rd),
        .stall(stall)
    );

    localparam RTYPE = 7'b0110011, ADDI = 7'b0010011, SW = 7'b0100011,
               JAL   = 7'b1101111;

    task check(input [6:0] op, input [4:0] rs1, input [4:0] rs2,
               input ex_we, input [4:0] ex_rd, input mem_we, input [4:0] mem_rd,
               input expected, input [255:0] name);
        begin
            id_opcode = op; id_rs1 = rs1; id_rs2 = rs2;
            idex_reg_write = ex_we; idex_rd = ex_rd;
            exmem_reg_write = mem_we; exmem_rd = mem_rd;
            #1;
            if (stall !== expected) begin
                $display("FAIL %0s: stall=%b expected=%b", name, stall, expected);
                errors = errors + 1;
            end else
                $display("PASS %0s: stall=%b", name, stall);
        end
    endtask

    initial begin
        errors = 0;
        //     op     rs1 rs2  ex_we ex_rd  mem_we mem_rd  expect  name
        check(RTYPE,  1,  2,   0, 0,        0, 0,          0, "no writers in flight");
        check(RTYPE,  1,  2,   1, 1,        0, 0,          1, "EX writes rs1");
        check(RTYPE,  1,  2,   1, 2,        0, 0,          1, "EX writes rs2");
        check(RTYPE,  1,  2,   0, 0,        1, 1,          1, "MEM writes rs1");
        check(RTYPE,  1,  2,   0, 0,        1, 2,          1, "MEM writes rs2");
        check(RTYPE,  1,  2,   1, 5,        1, 6,          0, "writers elsewhere");
        check(RTYPE,  1,  2,   0, 1,        0, 2,          0, "reg_write off");
        check(RTYPE,  0,  0,   1, 0,        1, 0,          0, "x0 never hazard");
        check(ADDI,   1,  2,   1, 2,        0, 0,          0, "addi ignores rs2 field");
        check(ADDI,   1,  2,   1, 1,        0, 0,          1, "addi uses rs1");
        check(SW,     3,  4,   0, 0,        1, 4,          1, "sw uses rs2 (store data)");
        check(JAL,    1,  2,   1, 1,        1, 2,          0, "jal uses no registers");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
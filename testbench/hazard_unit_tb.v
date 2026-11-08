`timescale 1ns/1ps
module hazard_unit_tb;
    reg  [6:0] id_opcode;
    reg  [4:0] id_rs1, id_rs2, idex_rd;
    reg        idex_mem_read;
    wire       stall;
    integer    errors;

    hazard_unit uut (
        .id_opcode(id_opcode), .id_rs1(id_rs1), .id_rs2(id_rs2),
        .idex_mem_read(idex_mem_read), .idex_rd(idex_rd),
        .stall(stall)
    );

    localparam RTYPE = 7'b0110011, ADDI = 7'b0010011, SW = 7'b0100011,
               JAL   = 7'b1101111;

    task check(input [6:0] op, input [4:0] rs1, input [4:0] rs2,
               input ex_load, input [4:0] ex_rd,
               input expected, input [255:0] name);
        begin
            id_opcode = op; id_rs1 = rs1; id_rs2 = rs2;
            idex_mem_read = ex_load; idex_rd = ex_rd;
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
        //     op     rs1 rs2  ex_load ex_rd  expect  name
        check(RTYPE,  1,  2,   0, 1,          0, "EX not a load");
        check(RTYPE,  1,  2,   1, 1,          1, "load-use on rs1");
        check(RTYPE,  1,  2,   1, 2,          1, "load-use on rs2");
        check(RTYPE,  1,  2,   1, 5,          0, "load to other reg");
        check(RTYPE,  0,  0,   1, 0,          0, "x0 never hazard");
        check(ADDI,   1,  2,   1, 2,          0, "addi ignores rs2 field");
        check(ADDI,   1,  2,   1, 1,          1, "addi uses rs1");
        check(SW,     3,  4,   1, 4,          1, "sw uses rs2 (store data)");
        check(JAL,    1,  2,   1, 1,          0, "jal uses no registers");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
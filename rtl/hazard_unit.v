module hazard_unit (
    input  [6:0] id_opcode,
    input  [4:0] id_rs1,
    input  [4:0] id_rs2,
    input        idex_reg_write,
    input  [4:0] idex_rd,
    input        exmem_reg_write,
    input  [4:0] exmem_rd,
    output       stall
);
    // which source registers does the instruction in ID actually use?
    wire uses_rs1 = (id_opcode == 7'b0110011) |   // R-type
                    (id_opcode == 7'b0010011) |   // addi
                    (id_opcode == 7'b0000011) |   // lw
                    (id_opcode == 7'b0100011) |   // sw
                    (id_opcode == 7'b1100011);    // beq, bne
    wire uses_rs2 = (id_opcode == 7'b0110011) |   // R-type
                    (id_opcode == 7'b0100011) |   // sw
                    (id_opcode == 7'b1100011);    // beq, bne

    // is a source register still waiting to be written by EX or MEM?
    wire hazard_rs1 = uses_rs1 && (id_rs1 != 5'd0) &&
                      ((idex_reg_write  && idex_rd  == id_rs1) ||
                       (exmem_reg_write && exmem_rd == id_rs1));
    wire hazard_rs2 = uses_rs2 && (id_rs2 != 5'd0) &&
                      ((idex_reg_write  && idex_rd  == id_rs2) ||
                       (exmem_reg_write && exmem_rd == id_rs2));

    assign stall = hazard_rs1 | hazard_rs2;
endmodule
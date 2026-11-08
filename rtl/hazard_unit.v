module hazard_unit (
    input  [6:0] id_opcode,
    input  [4:0] id_rs1,
    input  [4:0] id_rs2,
    input        idex_mem_read,     // instruction in EX is a load
    input  [4:0] idex_rd,
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

    // forwarding fixes everything except a load followed straight by its user:
    // the loaded value only exists after MEM, so wait one cycle
    wire load_use_rs1 = uses_rs1 && (id_rs1 != 5'd0) && idex_mem_read && (idex_rd == id_rs1);
    wire load_use_rs2 = uses_rs2 && (id_rs2 != 5'd0) && idex_mem_read && (idex_rd == id_rs2);

    assign stall = load_use_rs1 | load_use_rs2;
endmodule
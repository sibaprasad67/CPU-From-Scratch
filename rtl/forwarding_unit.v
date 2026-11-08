module forwarding_unit (
    input  [4:0] idex_rs1,
    input  [4:0] idex_rs2,
    input        exmem_reg_write,
    input  [4:0] exmem_rd,
    input        wb_reg_write,
    input  [4:0] wb_rd,
    output [1:0] forward_a,     // 00 register file, 10 from EX/MEM, 01 from WB
    output [1:0] forward_b
);
    // EX/MEM is the newest result, so it wins over WB
    assign forward_a = (exmem_reg_write && exmem_rd != 5'd0 && exmem_rd == idex_rs1) ? 2'b10 :
                       (wb_reg_write    && wb_rd    != 5'd0 && wb_rd    == idex_rs1) ? 2'b01 :
                                                                                        2'b00;
    assign forward_b = (exmem_reg_write && exmem_rd != 5'd0 && exmem_rd == idex_rs2) ? 2'b10 :
                       (wb_reg_write    && wb_rd    != 5'd0 && wb_rd    == idex_rs2) ? 2'b01 :
                                                                                        2'b00;
endmodule
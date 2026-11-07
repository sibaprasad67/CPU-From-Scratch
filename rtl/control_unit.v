module control_unit (
    input      [6:0] opcode,
    output reg       reg_write,
    output reg       alu_src,
    output reg       mem_read,
    output reg       mem_write,
    output reg [1:0] result_src,
    output reg       branch,
    output reg       jump,
    output reg [1:0] alu_op
);
    always @(*) begin
        // defaults: everything off, so unknown opcodes do nothing
        reg_write = 0; alu_src = 0; mem_read = 0; mem_write = 0;
        result_src = 2'b00; branch = 0; jump = 0; alu_op = 2'b00;

        case (opcode)
            7'b0110011: begin reg_write = 1; alu_op = 2'b10; end             // R-type
            7'b0010011: begin reg_write = 1; alu_src = 1; end                // addi
            7'b0000011: begin reg_write = 1; alu_src = 1; mem_read = 1;
                              result_src = 2'b01; end                        // lw
            7'b0100011: begin alu_src = 1; mem_write = 1; end                // sw
            7'b1100011: begin branch = 1; alu_op = 2'b01; end                // beq, bne
            7'b1101111: begin reg_write = 1; jump = 1; result_src = 2'b10; end // jal
            default: begin end
        endcase
    end
endmodule
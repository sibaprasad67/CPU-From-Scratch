module imm_gen (
    input      [31:0] instr,
    output reg [31:0] imm
);
    always @(*) begin
        case (instr[6:0])
            7'b0010011,
            7'b0000011: imm = {{20{instr[31]}}, instr[31:20]};                // I-type
            7'b0100011: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};   // S-type
            7'b1100011: imm = {{19{instr[31]}}, instr[31], instr[7],
                               instr[30:25], instr[11:8], 1'b0};              // B-type
            7'b1101111: imm = {{11{instr[31]}}, instr[31], instr[19:12],
                               instr[20], instr[30:21], 1'b0};                // J-type
            default:    imm = 32'd0;
        endcase
    end
endmodule
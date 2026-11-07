module alu_control (
    input      [1:0] alu_op,
    input      [2:0] funct3,
    input            funct7_5,
    output reg [3:0] alu_ctrl
);
    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0010;                         // add (lw, sw, addi)
            2'b01: alu_ctrl = 4'b0110;                         // subtract (branches)
            2'b10: begin                                       // R-type
                case (funct3)
                    3'b000:  alu_ctrl = funct7_5 ? 4'b0110 : 4'b0010;  // sub : add
                    3'b010:  alu_ctrl = 4'b0111;                       // slt
                    3'b110:  alu_ctrl = 4'b0001;                       // or
                    3'b111:  alu_ctrl = 4'b0000;                       // and
                    default: alu_ctrl = 4'b0010;
                endcase
            end
            default: alu_ctrl = 4'b0010;
        endcase
    end
endmodule
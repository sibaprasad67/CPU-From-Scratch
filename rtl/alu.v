module alu (
    input  [31:0]     a,
    input  [31:0]     b,
    input  [3:0]      alu_ctrl,
    output reg [31:0] result,
    output            zero
);
    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = a & b;
            4'b0001: result = a | b;
            4'b0010: result = a + b;
            4'b0110: result = a - b;
            4'b0111: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);
endmodule
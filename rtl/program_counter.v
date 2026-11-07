module program_counter (
    input             clk,
    input             reset,
    input             enable,
    input      [31:0] pc_next,
    output reg [31:0] pc
);
    always @(posedge clk) begin
        if (reset)
            pc <= 32'd0;
        else if (enable)
            pc <= pc_next;
    end
endmodule
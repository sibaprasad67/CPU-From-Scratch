module register_file #(parameter BYPASS = 1) (
    input         clk,
    input         reset,
    input         write_en,
    input  [4:0]  read_reg1,
    input  [4:0]  read_reg2,
    input  [4:0]  write_reg,
    input  [31:0] write_data,
    output [31:0] read_data1,
    output [31:0] read_data2
);
    reg [31:0] regs [0:31];
    integer i;

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (write_en  && write_reg != 5'd0) begin
            regs[write_reg] <= write_data;
        end
    end

    assign read_data1 = (read_reg1 == 5'd0)                  ? 32'd0 :
                        (BYPASS && write_en && write_reg == read_reg1) ? write_data :
                                                               regs[read_reg1];

    assign read_data2 = (read_reg2 == 5'd0)                  ? 32'd0 :
                        (BYPASS && write_en && write_reg == read_reg2) ? write_data :
                                                               regs[read_reg2];
endmodule
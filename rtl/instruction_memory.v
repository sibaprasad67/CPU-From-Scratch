module instruction_memory #(
    parameter MEM_FILE = "programs/program.hex"
) (
    input  [31:0] addr,
    output [31:0] instr
);
    reg [31:0] mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'h00000013;      // fill with NOP (addi x0, x0, 0)
        $readmemh(MEM_FILE, mem);       // then load the program over it
    end

    assign instr = mem[addr[9:2]];
endmodule
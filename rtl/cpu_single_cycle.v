module cpu_single_cycle #(
    parameter PROGRAM_FILE = "programs/program.hex"
) (
    input clk,
    input reset
);
    // ---------- wires ----------
    wire [31:0] pc, pc_plus4, pc_target, pc_next;
    wire [31:0] instr, imm;
    wire [31:0] rd1, rd2, alu_b, alu_result, mem_rdata, write_back;
    wire [3:0]  alu_ctrl;
    wire [1:0]  result_src, alu_op;
    wire        reg_write, alu_src, mem_read, mem_write, branch, jump;
    wire        zero, branch_taken;

    // ---------- instruction fields ----------
    wire [6:0] opcode   = instr[6:0];
    wire [4:0] rd       = instr[11:7];
    wire [2:0] funct3   = instr[14:12];
    wire [4:0] rs1      = instr[19:15];
    wire [4:0] rs2      = instr[24:20];
    wire       funct7_5 = instr[30];

    // ---------- fetch ----------
    program_counter u_pc (.clk(clk), .reset(reset), .enable(1'b1),
                          .pc_next(pc_next), .pc(pc));
    instruction_memory #(.MEM_FILE(PROGRAM_FILE)) u_imem (.addr(pc), .instr(instr));
    adder #(.WIDTH(32)) u_pc4 (.a(pc), .b(32'd4), .sum(pc_plus4));

    // ---------- decode ----------
    control_unit u_ctrl (.opcode(opcode), .reg_write(reg_write), .alu_src(alu_src),
                         .mem_read(mem_read), .mem_write(mem_write),
                         .result_src(result_src), .branch(branch), .jump(jump),
                         .alu_op(alu_op));
    imm_gen u_imm (.instr(instr), .imm(imm));
    register_file #(.BYPASS(0)) u_rf (.clk(clk), .reset(reset), .write_en(reg_write),
                         .read_reg1(rs1), .read_reg2(rs2), .write_reg(rd),
                         .write_data(write_back), .read_data1(rd1), .read_data2(rd2));

    // ---------- execute ----------
    alu_control u_aluctrl (.alu_op(alu_op), .funct3(funct3), .funct7_5(funct7_5),
                           .alu_ctrl(alu_ctrl));
    mux2 #(.WIDTH(32)) u_alusrc (.a(rd2), .b(imm), .sel(alu_src), .y(alu_b));
    alu u_alu (.a(rd1), .b(alu_b), .alu_ctrl(alu_ctrl), .result(alu_result), .zero(zero));

    // ---------- branch / jump ----------
    adder #(.WIDTH(32)) u_target (.a(pc), .b(imm), .sum(pc_target));
    assign branch_taken = jump | (branch & (zero ^ funct3[0]));
    mux2 #(.WIDTH(32)) u_pcmux (.a(pc_plus4), .b(pc_target), .sel(branch_taken), .y(pc_next));

    // ---------- memory ----------
    data_memory u_dmem (.clk(clk), .mem_read(mem_read), .mem_write(mem_write),
                        .addr(alu_result), .write_data(rd2), .read_data(mem_rdata));

    // ---------- write back ----------
    assign write_back = (result_src == 2'b01) ? mem_rdata :
                        (result_src == 2'b10) ? pc_plus4  :
                                                alu_result;
endmodule
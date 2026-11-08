module cpu_pipeline #(
    parameter PROGRAM_FILE = "programs/program.hex"
) (
    input clk,
    input reset
);
    // ---- control hooks (Phase 12 drives stall; Phase 14 drives flush_ifid) ----
    wire stall;                // from hazard_unit (bottom of file)
    wire flush_ifid = 1'b0;    // turn IF/ID into a bubble    (Phase 14)
    wire flush_idex = stall;   // stall -> bubble into ID/EX  (Phases 12, 14)

    // =====================================================================
    // IF: instruction fetch
    // =====================================================================
    wire [31:0] pc, pc_plus4_if, pc_next, instr_if;
    wire [31:0] pc_target_ex;
    wire        pc_src;

    program_counter u_pc (.clk(clk), .reset(reset), .enable(~stall),
                          .pc_next(pc_next), .pc(pc));
    instruction_memory #(.MEM_FILE(PROGRAM_FILE)) u_imem (.addr(pc), .instr(instr_if));
    adder #(.WIDTH(32)) u_pc4_if (.a(pc), .b(32'd4), .sum(pc_plus4_if));
    mux2  #(.WIDTH(32)) u_pcmux  (.a(pc_plus4_if), .b(pc_target_ex),
                                  .sel(pc_src), .y(pc_next));

    // ---------------- IF/ID pipeline register ----------------
    reg [31:0] ifid_pc, ifid_instr;
    always @(posedge clk) begin
        if (reset || flush_ifid) begin
            ifid_pc    <= 32'd0;
            ifid_instr <= 32'h00000013;          // NOP
        end else if (!stall) begin
            ifid_pc    <= pc;
            ifid_instr <= instr_if;
        end
    end

    // =====================================================================
    // ID: decode and register read
    // =====================================================================
    wire [6:0] id_opcode   = ifid_instr[6:0];
    wire [4:0] id_rd       = ifid_instr[11:7];
    wire [2:0] id_funct3   = ifid_instr[14:12];
    wire [4:0] id_rs1      = ifid_instr[19:15];
    wire [4:0] id_rs2      = ifid_instr[24:20];
    wire       id_funct7_5 = ifid_instr[30];

    wire        id_reg_write, id_alu_src, id_mem_read, id_mem_write;
    wire        id_branch, id_jump;
    wire [1:0]  id_result_src, id_alu_op;
    wire [31:0] id_imm, id_rd1, id_rd2;

    // write-back wires (come from the WB stage)
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    control_unit u_ctrl (.opcode(id_opcode), .reg_write(id_reg_write),
                         .alu_src(id_alu_src), .mem_read(id_mem_read),
                         .mem_write(id_mem_write), .result_src(id_result_src),
                         .branch(id_branch), .jump(id_jump), .alu_op(id_alu_op));
    imm_gen u_imm (.instr(ifid_instr), .imm(id_imm));

    // BYPASS=1: a register written in WB can be read in ID in the same cycle
    register_file #(.BYPASS(1)) u_rf (
        .clk(clk), .reset(reset), .write_en(wb_reg_write),
        .read_reg1(id_rs1), .read_reg2(id_rs2),
        .write_reg(wb_rd), .write_data(wb_data),
        .read_data1(id_rd1), .read_data2(id_rd2));

    // ---------------- ID/EX pipeline register ----------------
    reg [31:0] idex_pc, idex_rd1, idex_rd2, idex_imm, idex_instr;
    reg [4:0]  idex_rd, idex_rs1, idex_rs2;
    reg [2:0]  idex_funct3;
    reg        idex_funct7_5;
    reg        idex_reg_write, idex_alu_src, idex_mem_read, idex_mem_write;
    reg        idex_branch, idex_jump;
    reg [1:0]  idex_result_src, idex_alu_op;

    always @(posedge clk) begin
        if (reset || flush_idex) begin
            // bubble: all control signals off, so nothing happens downstream
            idex_reg_write <= 0; idex_alu_src <= 0; idex_mem_read <= 0;
            idex_mem_write <= 0; idex_branch <= 0;  idex_jump <= 0;
            idex_result_src <= 2'b00; idex_alu_op <= 2'b00;
            idex_pc <= 0; idex_rd1 <= 0; idex_rd2 <= 0; idex_imm <= 0;
            idex_rd <= 0; idex_rs1 <= 0; idex_rs2 <= 0;
            idex_funct3 <= 0; idex_funct7_5 <= 0;
            idex_instr <= 32'h00000013;
        end else begin
            idex_reg_write <= id_reg_write; idex_alu_src <= id_alu_src;
            idex_mem_read <= id_mem_read;   idex_mem_write <= id_mem_write;
            idex_branch <= id_branch;       idex_jump <= id_jump;
            idex_result_src <= id_result_src; idex_alu_op <= id_alu_op;
            idex_pc <= ifid_pc; idex_rd1 <= id_rd1; idex_rd2 <= id_rd2;
            idex_imm <= id_imm;
            idex_rd <= id_rd; idex_rs1 <= id_rs1; idex_rs2 <= id_rs2;
            idex_funct3 <= id_funct3; idex_funct7_5 <= id_funct7_5;
            idex_instr <= ifid_instr;                // kept for trace/visualizer
        end
    end

    // =====================================================================
    // EX: execute
    // =====================================================================
    wire [3:0]  ex_alu_ctrl;
    wire [31:0] ex_alu_b, ex_alu_result, ex_pc_plus4;
    wire        ex_zero;

    alu_control u_aluctrl (.alu_op(idex_alu_op), .funct3(idex_funct3),
                           .funct7_5(idex_funct7_5), .alu_ctrl(ex_alu_ctrl));
    wire [31:0] fwd_a, fwd_b;   // forwarded operands (driven at bottom of file)
    mux2 #(.WIDTH(32)) u_alusrc (.a(fwd_b), .b(idex_imm),
                                 .sel(idex_alu_src), .y(ex_alu_b));
    alu u_alu (.a(fwd_a), .b(ex_alu_b), .alu_ctrl(ex_alu_ctrl),
               .result(ex_alu_result), .zero(ex_zero));

    adder #(.WIDTH(32)) u_target (.a(idex_pc), .b(idex_imm), .sum(pc_target_ex));
    adder #(.WIDTH(32)) u_pc4_ex (.a(idex_pc), .b(32'd4),    .sum(ex_pc_plus4));
    assign pc_src = idex_jump | (idex_branch & (ex_zero ^ idex_funct3[0]));

    // ---------------- EX/MEM pipeline register ----------------
    reg [31:0] exmem_alu_result, exmem_rd2, exmem_pc_plus4, exmem_instr;
    reg [4:0]  exmem_rd;
    reg        exmem_reg_write, exmem_mem_read, exmem_mem_write;
    reg [1:0]  exmem_result_src;

    always @(posedge clk) begin
        if (reset) begin
            exmem_reg_write <= 0; exmem_mem_read <= 0; exmem_mem_write <= 0;
            exmem_result_src <= 2'b00;
            exmem_alu_result <= 0; exmem_rd2 <= 0; exmem_pc_plus4 <= 0;
            exmem_rd <= 0; exmem_instr <= 32'h00000013;
        end else begin
            exmem_reg_write <= idex_reg_write; exmem_mem_read <= idex_mem_read;
            exmem_mem_write <= idex_mem_write; exmem_result_src <= idex_result_src;
            exmem_alu_result <= ex_alu_result; exmem_rd2 <= fwd_b;
            exmem_pc_plus4 <= ex_pc_plus4;     exmem_rd <= idex_rd;
            exmem_instr <= idex_instr;
        end
    end

    // =====================================================================
    // MEM: data memory access
    // =====================================================================
    wire [31:0] mem_rdata;
    data_memory u_dmem (.clk(clk), .mem_read(exmem_mem_read),
                        .mem_write(exmem_mem_write), .addr(exmem_alu_result),
                        .write_data(exmem_rd2), .read_data(mem_rdata));

    // ---------------- MEM/WB pipeline register ----------------
    reg [31:0] memwb_alu_result, memwb_mem_rdata, memwb_pc_plus4, memwb_instr;
    reg [4:0]  memwb_rd;
    reg        memwb_reg_write;
    reg [1:0]  memwb_result_src;

    always @(posedge clk) begin
        if (reset) begin
            memwb_reg_write <= 0; memwb_result_src <= 2'b00;
            memwb_alu_result <= 0; memwb_mem_rdata <= 0; memwb_pc_plus4 <= 0;
            memwb_rd <= 0; memwb_instr <= 32'h00000013;
        end else begin
            memwb_reg_write <= exmem_reg_write; memwb_result_src <= exmem_result_src;
            memwb_alu_result <= exmem_alu_result; memwb_mem_rdata <= mem_rdata;
            memwb_pc_plus4 <= exmem_pc_plus4;     memwb_rd <= exmem_rd;
            memwb_instr <= exmem_instr;
        end
    end

    // =====================================================================
    // WB: write back
    // =====================================================================
    assign wb_reg_write = memwb_reg_write;
    assign wb_rd        = memwb_rd;
    assign wb_data = (memwb_result_src == 2'b01) ? memwb_mem_rdata :
                     (memwb_result_src == 2'b10) ? memwb_pc_plus4  :
                                                   memwb_alu_result;

    // ---------- Hazard detection (Phase 12, load-use only since Phase 13) ----------
    hazard_unit u_hazard (
        .id_opcode(id_opcode), .id_rs1(id_rs1), .id_rs2(id_rs2),
        .idex_mem_read(idex_mem_read), .idex_rd(idex_rd),
        .stall(stall)
    );

    // ---------- Forwarding (Phase 13) ----------
    wire [1:0]  fwd_a_sel, fwd_b_sel;
    // value sitting in EX/MEM: jal's result is pc+4, everything else the ALU result
    wire [31:0] exmem_fwd_val = (exmem_result_src == 2'b10) ? exmem_pc_plus4
                                                            : exmem_alu_result;

      forwarding_unit u_fwd (
        .idex_rs1(idex_rs1), .idex_rs2(idex_rs2),
        .exmem_reg_write(exmem_reg_write), .exmem_rd(exmem_rd),
        .wb_reg_write(wb_reg_write), .wb_rd(wb_rd),
        .forward_a(fwd_a_sel), .forward_b(fwd_b_sel)
    );

    assign fwd_a = (fwd_a_sel == 2'b10) ? exmem_fwd_val :
                   (fwd_a_sel == 2'b01) ? wb_data       : idex_rd1;
    assign fwd_b = (fwd_b_sel == 2'b10) ? exmem_fwd_val :
                   (fwd_b_sel == 2'b01) ? wb_data       : idex_rd2;
endmodule
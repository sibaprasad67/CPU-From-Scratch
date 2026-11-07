`timescale 1ns/1ps
module control_tb;
    reg  [6:0] opcode;
    wire       reg_write, alu_src, mem_read, mem_write, branch, jump;
    wire [1:0] result_src, alu_op;
    wire [9:0] ctrl_bus = {reg_write, alu_src, mem_read, mem_write,
                           result_src, branch, jump, alu_op};

    reg  [1:0] alu_op_in;
    reg  [2:0] funct3;
    reg        funct7_5;
    wire [3:0] alu_ctrl;
    integer    errors;

    control_unit cu (
        .opcode(opcode), .reg_write(reg_write), .alu_src(alu_src),
        .mem_read(mem_read), .mem_write(mem_write), .result_src(result_src),
        .branch(branch), .jump(jump), .alu_op(alu_op)
    );

    alu_control ac (
        .alu_op(alu_op_in), .funct3(funct3), .funct7_5(funct7_5),
        .alu_ctrl(alu_ctrl)
    );

    task check_ctrl(input [6:0] op, input [9:0] expected, input [159:0] name);
        begin
            opcode = op; #1;
            if (ctrl_bus !== expected) begin
                $display("FAIL %0s: got=%b expected=%b", name, ctrl_bus, expected);
                errors = errors + 1;
            end else
                $display("PASS %0s: ctrl=%b", name, ctrl_bus);
        end
    endtask

    task check_alu(input [1:0] op, input [2:0] f3, input f7,
                   input [3:0] expected, input [159:0] name);
        begin
            alu_op_in = op; funct3 = f3; funct7_5 = f7; #1;
            if (alu_ctrl !== expected) begin
                $display("FAIL %0s: got=%b expected=%b", name, alu_ctrl, expected);
                errors = errors + 1;
            end else
                $display("PASS %0s: alu_ctrl=%b", name, alu_ctrl);
        end
    endtask

    initial begin
        $dumpfile("simulation/control.vcd");
        $dumpvars(0, control_tb);
        errors = 0;
        #1;
        $display("ctrl = {reg_write, alu_src, mem_read, mem_write, result_src[1:0], branch, jump, alu_op[1:0]}");

        check_ctrl(7'b0110011, 10'b1000000010, "R-type");
        check_ctrl(7'b0010011, 10'b1100000000, "addi");
        check_ctrl(7'b0000011, 10'b1110010000, "lw");
        check_ctrl(7'b0100011, 10'b0101000000, "sw");
        check_ctrl(7'b1100011, 10'b0000001001, "beq/bne");
        check_ctrl(7'b1101111, 10'b1000100100, "jal");
        check_ctrl(7'b0000000, 10'b0000000000, "unknown opcode");
        check_ctrl(7'b1111111, 10'b0000000000, "unknown opcode 2");

        check_alu(2'b00, 3'b000, 1'b0, 4'b0010, "alu lw/sw/addi");
        check_alu(2'b01, 3'b000, 1'b0, 4'b0110, "alu branch");
        check_alu(2'b10, 3'b000, 1'b0, 4'b0010, "R add");
        check_alu(2'b10, 3'b000, 1'b1, 4'b0110, "R sub");
        check_alu(2'b10, 3'b111, 1'b0, 4'b0000, "R and");
        check_alu(2'b10, 3'b110, 1'b0, 4'b0001, "R or");
        check_alu(2'b10, 3'b010, 1'b0, 4'b0111, "R slt");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
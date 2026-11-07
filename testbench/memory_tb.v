`timescale 1ns/1ps
module memory_tb;
    reg         clk, mem_read, mem_write;
    reg  [31:0] pc_addr, d_addr, d_wdata;
    wire [31:0] instr, d_rdata;
    integer     errors;

    instruction_memory #(.MEM_FILE("programs/test_imem.hex")) imem (
        .addr(pc_addr), .instr(instr)
    );

    data_memory dmem (
        .clk(clk), .mem_read(mem_read), .mem_write(mem_write),
        .addr(d_addr), .write_data(d_wdata), .read_data(d_rdata)
    );

    always #5 clk = ~clk;

    task check(input [31:0] got, input [31:0] expected, input [159:0] name);
        begin
            if (got !== expected) begin
                $display("FAIL %0s: got=%h expected=%h", name, got, expected);
                errors = errors + 1;
            end else
                $display("PASS %0s: got=%h", name, got);
        end
    endtask

    task dwrite(input [31:0] a, input [31:0] v);
        begin
            @(negedge clk);
            d_addr = a; d_wdata = v; mem_write = 1;
            @(negedge clk);
            mem_write = 0;
        end
    endtask

    initial begin
        $dumpfile("simulation/memory.vcd");
        $dumpvars(0, memory_tb);
        errors = 0;
        clk = 0; mem_read = 0; mem_write = 0;
        pc_addr = 0; d_addr = 0; d_wdata = 0;

        // ---- instruction memory ----
        pc_addr = 32'd0;  #1; check(instr, 32'h00500093, "imem word 0");
        pc_addr = 32'd4;  #1; check(instr, 32'h00A00113, "imem word 1");
        pc_addr = 32'd8;  #1; check(instr, 32'h002081B3, "imem word 2");
        pc_addr = 32'd12; #1; check(instr, 32'h40208233, "imem word 3");
        pc_addr = 32'd16; #1; check(instr, 32'h00000013, "imem NOP fill");

        // ---- data memory ----
        mem_read = 1; d_addr = 32'h20; #1;
        check(d_rdata, 32'd0, "dmem starts 0");

        dwrite(32'h10, 32'hAABBCCDD);
        d_addr = 32'h10; #1;
        check(d_rdata, 32'hAABBCCDD, "dmem write/read");

        dwrite(32'h14, 32'h11223344);
        d_addr = 32'h10; #1;
        check(d_rdata, 32'hAABBCCDD, "dmem no alias");
        d_addr = 32'h14; #1;
        check(d_rdata, 32'h11223344, "dmem 2nd word");

        @(negedge clk);
        d_addr = 32'h10; d_wdata = 32'hFFFFFFFF; mem_write = 0;
        @(negedge clk); #1;
        check(d_rdata, 32'hAABBCCDD, "write_en=0");

        mem_read = 0; #1;
        check(d_rdata, 32'd0, "read gated");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
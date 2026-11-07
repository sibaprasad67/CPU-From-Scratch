`timescale 1ns/1ps
module register_file_tb;
    reg         clk, reset, write_en;
    reg  [4:0]  read_reg1, read_reg2, write_reg;
    reg  [31:0] write_data;
    wire [31:0] read_data1, read_data2;
    integer     errors, k, sweep_errors;

    register_file uut (
        .clk(clk), .reset(reset), .write_en(write_en),
        .read_reg1(read_reg1), .read_reg2(read_reg2),
        .write_reg(write_reg), .write_data(write_data),
        .read_data1(read_data1), .read_data2(read_data2)
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

    task write_to(input [4:0] r, input [31:0] v);
        begin
            @(negedge clk);
            write_reg = r; write_data = v; write_en = 1;
            @(negedge clk);
            write_en = 0;
        end
    endtask

    initial begin
        $dumpfile("simulation/register_file.vcd");
        $dumpvars(0, register_file_tb);
        errors = 0;
        clk = 0; reset = 1; write_en = 0;
        read_reg1 = 0; read_reg2 = 0; write_reg = 0; write_data = 0;
        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;

        read_reg1 = 5; #1;
        check(read_data1, 32'd0, "reset clears");

        write_to(5, 32'hDEADBEEF);
        write_to(10, 32'h12345678);
        read_reg1 = 5; read_reg2 = 10; #1;
        check(read_data1, 32'hDEADBEEF, "port 1");
        check(read_data2, 32'h12345678, "port 2");

        write_to(0, 32'hFFFFFFFF);
        read_reg1 = 0; #1;
        check(read_data1, 32'd0, "x0 read");
        check(uut.regs[0], 32'd0, "x0 storage");

        @(negedge clk);
        write_reg = 5; write_data = 32'h11111111; write_en = 0;
        @(negedge clk);
        read_reg1 = 5; #1;
        check(read_data1, 32'hDEADBEEF, "we=0 no write");

        @(negedge clk);
        write_reg = 7; write_data = 32'hCAFEF00D; write_en = 1;
        read_reg1 = 7; #1;
        check(read_data1, 32'hCAFEF00D, "write-through");
        @(negedge clk);
        write_en = 0; read_reg1 = 7; #1;
        check(read_data1, 32'hCAFEF00D, "after write");

        write_to(5, 32'hA5A5A5A5);
        read_reg1 = 5; #1;
        check(read_data1, 32'hA5A5A5A5, "overwrite");

        for (k = 1; k < 32; k = k + 1)
            write_to(k, k * 100);
        sweep_errors = 0;
        for (k = 1; k < 32; k = k + 1) begin
            read_reg1 = k; #1;
            if (read_data1 !== k * 100) sweep_errors = sweep_errors + 1;
        end
        if (sweep_errors == 0)
            $display("PASS sweep: all 31 registers hold their values");
        else begin
            $display("FAIL sweep: %0d registers wrong", sweep_errors);
            errors = errors + 1;
        end

        @(negedge clk); reset = 1;
        @(negedge clk); reset = 0;
        read_reg1 = 5; read_reg2 = 10; #1;
        check(read_data1, 32'd0, "reset port 1");
        check(read_data2, 32'd0, "reset port 2");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
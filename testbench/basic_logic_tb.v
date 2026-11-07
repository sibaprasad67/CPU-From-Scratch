`timescale 1ns/1ps
module basic_logic_tb;
    reg  [31:0] a, b;
    reg         sel;
    wire [31:0] mux_out;
    wire [31:0] sum;
    integer     errors;

    mux2  #(.WIDTH(32)) u_mux (.a(a), .b(b), .sel(sel), .y(mux_out));
    adder #(.WIDTH(32)) u_add (.a(a), .b(b), .sum(sum));

    task check_mux(input [31:0] expected);
        begin
            if (mux_out !== expected) begin
                $display("FAIL mux: sel=%b got=%h expected=%h", sel, mux_out, expected);
                errors = errors + 1;
            end else
                $display("PASS mux: sel=%b -> %h", sel, mux_out);
        end
    endtask

    task check_add(input [31:0] expected);
        begin
            if (sum !== expected) begin
                $display("FAIL add: %h + %h got=%h expected=%h", a, b, sum, expected);
                errors = errors + 1;
            end else
                $display("PASS add: %h + %h = %h", a, b, sum);
        end
    endtask

    initial begin
        $dumpfile("simulation/basic_logic.vcd");
        $dumpvars(0, basic_logic_tb);
        errors = 0;

        a = 32'd10; b = 32'd20; sel = 0; #10;
        check_mux(32'd10);
        check_add(32'd30);

        sel = 1; #10;
        check_mux(32'd20);

        a = 32'hFFFFFFFF; b = 32'd1; sel = 0; #10;
        check_mux(32'hFFFFFFFF);
        check_add(32'd0);

        a = 32'd100; b = 32'd4; sel = 1; #10;
        check_mux(32'd4);
        check_add(32'd104);

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
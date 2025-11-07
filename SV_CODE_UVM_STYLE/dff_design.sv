
interface dff_ff;
    logic clk;
    logic rst;
    logic din;
    logic out;
endinterface

module dff (dff_ff dif);
    // Use the interface signals inside the module
    always_ff @(posedge dif.clk) begin
        if (dif.rst) begin
            dif.out <= 1'b0;
        end else begin
            dif.out <= dif.din;
        end
    end
endmodule

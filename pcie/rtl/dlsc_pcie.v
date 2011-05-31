
module dlsc_pcie (
    input   wire            clk,
    input   wire    [31:0]  data,
    input   wire            last,
    input   wire            valid,
    output  reg             ready
);

always @(posedge clk) begin
    ready   <= $random;

    if(valid && ready) begin
        $display("*** %t: %x", $time, data);
        if(last) begin
            $display("*** last ***");
        end
    end
end

endmodule


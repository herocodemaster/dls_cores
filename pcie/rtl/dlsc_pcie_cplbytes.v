
module dlsc_pcie_cplbytes (
    input   wire    [9:0]   len,
    input   wire    [3:0]   be_first,
    input   wire    [3:0]   be_last,
    input   wire            type_mem,
    output  reg     [11:0]  bytes_remaining,
    output  reg     [1:0]   byte_offset
);

// calculate bytes remaining
// (why does PCIe make this so complicated??)

reg  [1:0]      bef_sub;
reg  [1:0]      bel_sub;

always @* begin
    // first
    casez(be_first)
        4'b???1: bef_sub = 2'd0;
        4'b??10: bef_sub = 2'd1;
        4'b?100: bef_sub = 2'd2;
        4'b1000: bef_sub = 2'd3;
        default: bef_sub = 2'd0;
    endcase
    // last
    casez(be_last)
        4'b1???: bel_sub = 2'd0;
        4'b01??: bel_sub = 2'd1;
        4'b001?: bel_sub = 2'd2;
        4'b0001: bel_sub = 2'd3;
        default: bel_sub = 2'd0;
    endcase
end

always @* begin
    if(type_mem) begin
        if(len == 10'd1) begin
            // consider only 1st BE
            casez(be_first)
                4'b1??1: bytes_remaining = 12'd4;
                4'b01?1: bytes_remaining = 12'd3;
                4'b1?10: bytes_remaining = 12'd3;
                4'b0011: bytes_remaining = 12'd2;
                4'b0110: bytes_remaining = 12'd2;
                4'b1100: bytes_remaining = 12'd2;
                default: bytes_remaining = 12'd1;
            endcase
        end else begin
            // consider both BEs
            bytes_remaining = {len,2'd0} - {10'd0,bef_sub} - {10'd0,bel_sub};
        end
    end else begin
        bytes_remaining = 12'd4;
    end
end

always @* begin
    casez(be_first)
        4'b???1: byte_offset = 2'd0;
        4'b??10: byte_offset = 2'd1;
        4'b?100: byte_offset = 2'd2;
        4'b1000: byte_offset = 2'd3;
        default: byte_offset = 2'd0;
    endcase
end

endmodule


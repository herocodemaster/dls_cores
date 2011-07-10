
module dlsc_pcie_s6_inbound_read_rcb #(
    parameter MAX_SIZE  = 4096,     // max read completion size
    parameter REGISTER  = 1
) (
    // System
    input   wire                clk,
    input   wire                rst,
    
    // TLP header input
    output  wire                tlp_h_ready,
    input   wire                tlp_h_valid,
    input   wire                tlp_h_mem,
    input   wire    [11:2]      tlp_h_addr,
    input   wire    [9:0]       tlp_h_len,
    input   wire    [3:0]       tlp_h_be_first,
    input   wire    [3:0]       tlp_h_be_last,

    // Read completion output
    input   wire                rcb_ready,
    output  wire                rcb_valid,
    output  wire    [6:0]       rcb_addr,
    output  wire    [9:0]       rcb_len,
    output  reg     [11:0]      rcb_bytes,
    output  wire                rcb_last,       // last completion for this request
    
    // Config
    input   wire    [2:0]       max_payload_size
);


// split into completions (reads only)

wire [11:2]     split_rcb_addr;
wire            split_mem;

dlsc_pcie_s6_cmdsplit #(
    .ADDR           ( 12 ),
    .LEN            ( 10 ),
    .OUT_SUB        ( 0 ),
    .MAX_SIZE       ( MAX_SIZE ),
    .ALIGN          ( 1 ),
    .META           ( 1 ),
    .REGISTER       ( REGISTER )
) dlsc_pcie_s6_cmdsplit_rcb (
    .clk            ( clk ),
    .rst            ( rst ),
    .in_ready       ( tlp_h_ready ),
    .in_valid       ( tlp_h_valid ),
    .in_addr        ( tlp_h_addr ),
    .in_len         ( tlp_h_len ),
    .in_meta        ( tlp_h_mem ),
    .max_size       ( max_payload_size ),
    .out_ready      ( rcb_ready ),
    .out_valid      ( rcb_valid ),
    .out_addr       ( split_rcb_addr ),
    .out_len        ( rcb_len ),
    .out_meta       ( split_mem ),
    .out_last       ( rcb_last )
);


// calculate bytes remaining
// (why does PCIe make this so complicated??)

reg  [1:0]      bef_sub;
reg  [1:0]      bel_sub;

always @* begin
    // first
    casez(tlp_h_be_first)
        4'b???1: bef_sub = 2'd0;
        4'b??10: bef_sub = 2'd1;
        4'b?100: bef_sub = 2'd2;
        4'b1000: bef_sub = 2'd3;
        default: bef_sub = 2'd0;
    endcase
    // last
    casez(tlp_h_be_last)
        4'b1???: bel_sub = 2'd0;
        4'b01??: bel_sub = 2'd1;
        4'b001?: bel_sub = 2'd2;
        4'b0001: bel_sub = 2'd3;
        default: bel_sub = 2'd0;
    endcase
end

reg  [11:0]     bytes_remaining;

always @* begin
    if(tlp_h_mem) begin
        if(tlp_h_len == 10'd1) begin
            // consider only 1st BE
            casez(tlp_h_be_first)
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
            bytes_remaining = {tlp_h_len,2'd0} - {10'd0,bef_sub} - {10'd0,bel_sub};
        end
    end else begin
        bytes_remaining = 12'd4;
    end
end

reg  [1:0]      byte_offset;

always @* begin
    casez(tlp_h_be_first)
        4'b???1: byte_offset = 2'd0;
        4'b??10: byte_offset = 2'd1;
        4'b?100: byte_offset = 2'd2;
        4'b1000: byte_offset = 2'd3;
        default: byte_offset = 2'd0;
    endcase
end

// update bytes_remaining field
reg  [1:0]      rcb_boff;

assign          rcb_addr        = split_mem ? { split_rcb_addr[6:2], rcb_boff[1:0] } : 7'd0;

always @(posedge clk) begin
    if(tlp_h_ready && tlp_h_valid) begin
        rcb_boff        <= byte_offset;
        rcb_bytes       <= bytes_remaining;
    end
    if(rcb_ready && rcb_valid && !rcb_last) begin
        rcb_boff        <= 2'd0;
        rcb_bytes       <= rcb_bytes - {rcb_len,2'd0} + {10'd0,rcb_boff};
    end
end

endmodule


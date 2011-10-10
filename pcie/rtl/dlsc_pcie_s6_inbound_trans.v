
module dlsc_pcie_s6_inbound_trans #(
    parameter            ADDR            = 32,
    parameter [ADDR-1:0] TRANS_BAR0_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_BAR0_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_BAR1_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_BAR1_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_BAR2_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_BAR2_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_BAR3_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_BAR3_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_BAR4_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_BAR4_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_BAR5_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_BAR5_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_ROM_MASK  = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_ROM_BASE  = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_CFG_MASK  = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_CFG_BASE  = {ADDR{1'b0}}
) (
    // System
    input   wire                clk,
    input   wire                rst,

    // Translation request
    input   wire                trans_req,
    input   wire    [2:0]       trans_req_bar,
    input   wire    [63:2]      trans_req_addr,
    input   wire                trans_req_64,

    // Translation response
    output  reg                 trans_ack,
    output  reg     [ADDR-1:2]  trans_ack_addr
);


// mask ROM

reg [ADDR-1:2] mask;
always @* begin
    mask = {(ADDR-2){1'bx}};
    case(trans_req_bar)
        3'h0: mask = TRANS_BAR0_MASK[ADDR-1:2];
        3'h1: mask = TRANS_BAR1_MASK[ADDR-1:2];
        3'h2: mask = TRANS_BAR2_MASK[ADDR-1:2];
        3'h3: mask = TRANS_BAR3_MASK[ADDR-1:2];
        3'h4: mask = TRANS_BAR4_MASK[ADDR-1:2];
        3'h5: mask = TRANS_BAR5_MASK[ADDR-1:2];
        3'h6: mask = TRANS_ROM_MASK [ADDR-1:2];
        3'h7: mask = TRANS_CFG_MASK [ADDR-1:2];
    endcase
end


// base ROM

reg [ADDR-1:2] base;
always @* begin
    base = {(ADDR-2){1'bx}};
    case(trans_req_bar)
        3'h0: base = TRANS_BAR0_BASE[ADDR-1:2] & ~TRANS_BAR0_MASK[ADDR-1:2];
        3'h1: base = TRANS_BAR1_BASE[ADDR-1:2] & ~TRANS_BAR1_MASK[ADDR-1:2];
        3'h2: base = TRANS_BAR2_BASE[ADDR-1:2] & ~TRANS_BAR2_MASK[ADDR-1:2];
        3'h3: base = TRANS_BAR3_BASE[ADDR-1:2] & ~TRANS_BAR3_MASK[ADDR-1:2];
        3'h4: base = TRANS_BAR4_BASE[ADDR-1:2] & ~TRANS_BAR4_MASK[ADDR-1:2];
        3'h5: base = TRANS_BAR5_BASE[ADDR-1:2] & ~TRANS_BAR5_MASK[ADDR-1:2];
        3'h6: base = TRANS_ROM_BASE [ADDR-1:2] & ~TRANS_ROM_MASK [ADDR-1:2];
        3'h7: base = TRANS_CFG_BASE [ADDR-1:2] & ~TRANS_CFG_MASK [ADDR-1:2];
    endcase
end


// output

always @(posedge clk) begin
    trans_ack_addr  <= (trans_req_addr[ADDR-1:2] & mask) | base;
end

always @(posedge clk) begin
    if(rst) begin
        trans_ack       <= 1'b0;
    end else begin
        trans_ack       <= trans_req;
    end
end


endmodule



module dlsc_pcie_s6_outbound_trans #(
    parameter ADDR          = 32,
    parameter TRANS_REGIONS = 1, // number of enabled output regions (1-8)
    parameter [ADDR-1:0] TRANS_0_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_0_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_1_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_1_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_2_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_2_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_3_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_3_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_4_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_4_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_5_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_5_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_6_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_6_BASE = {ADDR{1'b0}},
    parameter [ADDR-1:0] TRANS_7_MASK = {ADDR{1'b1}},
    parameter [ADDR-1:0] TRANS_7_BASE = {ADDR{1'b0}}
) (
    // System
    input   wire                clk,
    input   wire                rst,

    // APB access to outbound base RAM
    input   wire    [5:2]       apb_addr,
    input   wire                apb_sel,
    input   wire                apb_enable,
    input   wire                apb_write,
    input   wire    [31:0]      apb_wdata,
    input   wire    [3:0]       apb_strb,
    output  wire                apb_ready,
    output  wire    [31:0]      apb_rdata,

    // Translation request
    input   wire                trans_req,
    input   wire    [ADDR-1:2]  trans_req_addr,

    // Translation response
    output  wire                trans_ack,
    output  wire    [63:2]      trans_ack_addr,
    output  wire                trans_ack_64
);

`include "dlsc_synthesis.vh"
`include "dlsc_clog2.vh"

localparam      MEM_DEPTH       = TRANS_REGIONS*2;
localparam      MEM_ADDR        = `dlsc_clog2(MEM_DEPTH);


// timing

reg  [2:0]      cyc;

always @(posedge clk) begin
    if(rst || !trans_req) begin
        cyc     <= 3'h1;
    end else if(!cyc[2] && !apb_sel) begin
        cyc     <= { cyc[1:0], 1'b0 };
    end
end


// decode region (cycle 0)

reg  [2:0]      region;

always @(posedge clk) if(cyc[0]) begin
    region  <= 3'h0;
    if( TRANS_REGIONS > 1 && ((trans_req_addr & ~TRANS_1_MASK[ADDR-1:2]) == (TRANS_1_BASE[ADDR-1:2] & ~TRANS_1_MASK[ADDR-1:2])) ) region <= 3'h1;
    if( TRANS_REGIONS > 2 && ((trans_req_addr & ~TRANS_2_MASK[ADDR-1:2]) == (TRANS_2_BASE[ADDR-1:2] & ~TRANS_2_MASK[ADDR-1:2])) ) region <= 3'h2;
    if( TRANS_REGIONS > 3 && ((trans_req_addr & ~TRANS_3_MASK[ADDR-1:2]) == (TRANS_3_BASE[ADDR-1:2] & ~TRANS_3_MASK[ADDR-1:2])) ) region <= 3'h3;
    if( TRANS_REGIONS > 4 && ((trans_req_addr & ~TRANS_4_MASK[ADDR-1:2]) == (TRANS_4_BASE[ADDR-1:2] & ~TRANS_4_MASK[ADDR-1:2])) ) region <= 3'h4;
    if( TRANS_REGIONS > 5 && ((trans_req_addr & ~TRANS_5_MASK[ADDR-1:2]) == (TRANS_5_BASE[ADDR-1:2] & ~TRANS_5_MASK[ADDR-1:2])) ) region <= 3'h5;
    if( TRANS_REGIONS > 6 && ((trans_req_addr & ~TRANS_6_MASK[ADDR-1:2]) == (TRANS_6_BASE[ADDR-1:2] & ~TRANS_6_MASK[ADDR-1:2])) ) region <= 3'h6;
    if( TRANS_REGIONS > 7 && ((trans_req_addr & ~TRANS_7_MASK[ADDR-1:2]) == (TRANS_7_BASE[ADDR-1:2] & ~TRANS_7_MASK[ADDR-1:2])) ) region <= 3'h7;
end


// mask ROM

reg  [ADDR-1:2] mask;
always @* begin
    mask = {(ADDR-2){1'bx}};
    case(region)
        3'h0: mask = TRANS_0_MASK[ADDR-1:2];
        3'h1: mask = TRANS_1_MASK[ADDR-1:2];
        3'h2: mask = TRANS_2_MASK[ADDR-1:2];
        3'h3: mask = TRANS_3_MASK[ADDR-1:2];
        3'h4: mask = TRANS_4_MASK[ADDR-1:2];
        3'h5: mask = TRANS_5_MASK[ADDR-1:2];
        3'h6: mask = TRANS_6_MASK[ADDR-1:2];
        3'h7: mask = TRANS_7_MASK[ADDR-1:2];
    endcase
end


// full padded and masked input address

wire [63:2]     addr            = { {(64-ADDR){1'b0}}, (trans_req_addr & mask) };


// outbound base RAM

`DLSC_LUTRAM reg [7:0] mem0 [MEM_DEPTH-1:0];
`DLSC_LUTRAM reg [7:0] mem1 [MEM_DEPTH-1:0];
`DLSC_LUTRAM reg [7:0] mem2 [MEM_DEPTH-1:0];
`DLSC_LUTRAM reg [7:0] mem3 [MEM_DEPTH-1:0];

wire [3:0]      mem_addr_full   = apb_sel ? apb_addr[5:2] : { region, cyc[2] };

wire [MEM_ADDR-1:0] mem_addr    = mem_addr_full[MEM_ADDR-1:0];

wire [31:0]     mem_rd          = { mem3[mem_addr],
                                    mem2[mem_addr],
                                    mem1[mem_addr],
                                    mem0[mem_addr] };

// access via APB

assign          apb_ready       = apb_sel && apb_enable;
assign          apb_rdata       = apb_sel ? mem_rd : 32'h0;

wire            mem_wr_en       = apb_sel && apb_write;

always @(posedge clk) begin
    if(mem_wr_en && apb_strb[0]) begin
        mem0[mem_addr] <= apb_wdata[ 7: 0];
    end
end
always @(posedge clk) begin
    if(mem_wr_en && apb_strb[1]) begin
        mem1[mem_addr] <= apb_wdata[15: 8];
    end
end
always @(posedge clk) begin
    if(mem_wr_en && apb_strb[2]) begin
        mem2[mem_addr] <= apb_wdata[23:16];
    end
end
always @(posedge clk) begin
    if(mem_wr_en && apb_strb[3]) begin
        mem3[mem_addr] <= apb_wdata[31:24];
    end
end


// low address (cycle 1)

reg  [31:2]     ack_addr_low;

always @(posedge clk) if(cyc[1]) begin
    ack_addr_low    <= (addr[31:2] | mem_rd[31:2]);
end


// high address (cycle 2)

reg  [63:32]    ack_addr_high;
always @* begin
    ack_addr_high   = (addr[63:32] | mem_rd[31:0]);
end


// output

assign          trans_ack       = cyc[2] && !apb_sel;
assign          trans_ack_addr  = { ack_addr_high, ack_addr_low };
assign          trans_ack_64    = |ack_addr_high;


endmodule


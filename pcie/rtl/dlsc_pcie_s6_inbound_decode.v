
module dlsc_pcie_s6_inbound_decode #(
    parameter ADDR      = 32
) (
    // System
    input   wire                clk,
    input   wire                rst,

    // Address translation
    output  reg                 trans_req,
    output  reg     [2:0]       trans_req_bar,
    output  reg     [63:2]      trans_req_addr,
    output  reg                 trans_req_64,
    input   wire                trans_ack,
    input   wire    [ADDR-1:2]  trans_ack_addr,

    // TLP receive input (requests only)
    output  reg                 rx_ready,
    input   wire                rx_valid,
    input   wire    [31:0]      rx_data,
    input   wire                rx_last,
    input   wire                rx_err,
    input   wire    [6:0]       rx_bar,

    // Parsed TLP header
    input   wire                tlp_h_ready,
    output  wire                tlp_h_valid,
    output  reg                 tlp_h_np,           // non-posted (e.g. any read, or a config/IO write)
    output  reg                 tlp_h_write,
    output  reg                 tlp_h_mem,
    output  wire    [ADDR-1:2]  tlp_h_addr,
    output  reg     [9:0]       tlp_h_len,
    output  reg     [3:0]       tlp_h_be_first,
    output  reg     [3:0]       tlp_h_be_last,

    // TLP ID to completer (non-posted only)
    input   wire                tlp_id_ready,
    output  wire                tlp_id_valid,
    output  wire                tlp_id_write,
    output  wire    [28:0]      tlp_id_data,

    // TLP data payload (writes only)
    input   wire                tlp_d_ready,
    output  wire                tlp_d_valid,
    output  wire                tlp_d_last,
    output  wire    [31:0]      tlp_d_data,
    output  reg     [3:0]       tlp_d_strb
);

`include "dlsc_pcie_tlp_params.vh"


// Fields

wire        h0_fmt_write        = rx_data[30];
wire        h0_fmt_64           = rx_data[29];

wire [4:0]  h0_type             = rx_data[28:24];

wire        h0_type_mem         = (h0_type == TYPE_MEM);
wire        h0_type_cfg         = (h0_type == TYPE_CONFIG_0 || h0_type == TYPE_CONFIG_1);
wire        h0_type_io          = (h0_type == TYPE_IO);

wire        h0_err              = rx_data[14] || rx_err;


// States

localparam  ST_H0       = 3'd0,
            ST_H1       = 3'd1,
            ST_H2       = 3'd2,
            ST_H3       = 3'd3,
            ST_DATA     = 3'd4,
            ST_FLUSH    = 3'd5;

reg  [2:0]      st              = ST_H0;
reg  [2:0]      next_st;


// Latch outputs

// temporary holding registers (allows H0 and H1 to overlap previous TLP's
// address translation phase)
reg             h_fmt_write;
reg             h_fmt_64;
reg             h_type_mem;
reg             h_type_cfg;
reg             h_type_np;
reg  [2:0]      h_tc;
reg  [1:0]      h_attr;
reg  [9:0]      h_len;
reg  [3:0]      h_be_first;
reg  [3:0]      h_be_last;
reg  [6:0]      h_bar;

// ID output; only valid in H1
assign          tlp_id_data     = { h_tc, h_attr, rx_data[31:8] };
assign          tlp_id_write    = h_fmt_write;

// encode bar
reg  [2:0]      h_bar_encoded;
always @* begin
    casez({h_type_cfg,h_bar})
        8'b1???_????: h_bar_encoded = 3'd7;
        8'b0???_???1: h_bar_encoded = 3'd0;
        8'b0???_??10: h_bar_encoded = 3'd1;
        8'b0???_?100: h_bar_encoded = 3'd2;
        8'b0???_1000: h_bar_encoded = 3'd3;
        8'b0??1_0000: h_bar_encoded = 3'd4;
        8'b0?10_0000: h_bar_encoded = 3'd5;
        8'b0100_0000: h_bar_encoded = 3'd6;
        default:      h_bar_encoded = 3'd0;
    endcase
end

always @(posedge clk) begin
    if(rx_ready && rx_valid) begin
        if(st == ST_H0) begin
            h_fmt_write     <= h0_fmt_write;
            h_fmt_64        <= h0_fmt_64;
            h_type_cfg      <= h0_type_cfg;
            h_type_mem      <= h0_type_mem;
            h_type_np       <= !h0_fmt_write || h0_type_cfg || h0_type_io;
            h_tc            <= rx_data[22:20];
            h_attr          <= rx_data[13:12];
            h_len           <= rx_data[9:0];
            h_bar           <= rx_bar;
        end
        if(st == ST_H1) begin
            h_be_last       <= rx_data[7:4];
            h_be_first      <= rx_data[3:0];
        end
        if(st == ST_H2) begin
            // transfer to output and begin address translation
            tlp_h_write     <= h_fmt_write;
            tlp_h_mem       <= h_type_mem;
            tlp_h_np        <= h_type_np;
            tlp_h_len       <= h_len;
            tlp_h_be_first  <= h_be_first;
            tlp_h_be_last   <= h_be_last;
            trans_req_bar   <= h_bar_encoded;
            trans_req_64    <= h_fmt_64;
            if(!h_fmt_64) begin
                if(!h_type_cfg) begin
                    // 32-bit memory or I/O request
                    trans_req_addr      <= { 32'b0, rx_data[31:2] };
                end else begin
                    // 32-bit config request
                    trans_req_addr      <= { 32'b0, 20'b0, rx_data[11:2] };
                end
            end else begin
                // 64-bit memory request
                trans_req_addr      <= { rx_data[31:0], 30'b0 };
            end
        end
        if(st == ST_H3) begin
            trans_req_addr[31:2]<= rx_data[31:2];
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        trans_req       <= 1'b0;
    end else begin
        if(tlp_h_ready && tlp_h_valid) begin
            trans_req       <= 1'b0;
        end
        if(rx_ready && rx_valid && ((st == ST_H2 && !h_fmt_64) || (st == ST_H3))) begin
            trans_req       <= 1'b1;
        end
    end
end

assign          tlp_h_valid     = trans_req && trans_ack;
assign          tlp_h_addr      = trans_ack_addr;


// Create 'first' flag for data payload

reg             tlp_d_first     = 1'b0;

always @(posedge clk) begin
    if(st != ST_DATA) begin
        tlp_d_first     <= 1'b1;
    end else if(rx_ready && rx_valid) begin
        tlp_d_first     <= 1'b0;
    end
end


// Control

assign          tlp_d_data      = rx_data;
assign          tlp_d_last      = rx_last;

always @* begin
    next_st         = st;

    rx_ready        = 1'b0;

    tlp_id_valid    = 1'b0;

    tlp_d_valid     = 1'b0;
    tlp_d_strb      = 4'hF;

    if(st == ST_H0) begin
        // TODO: currently, errored TLPs are silently dropped, but we may want to report this condition..
        rx_ready        = 1'b1;
        next_st         = h0_err ? ST_FLUSH : ST_H1;
    end
    if(st == ST_H1) begin
        rx_ready        = tlp_id_ready || !h_type_np;
        tlp_id_valid    = rx_valid && h_type_np;
        next_st         = ST_H2;
    end
    if(st == ST_H2) begin
        rx_ready        = !trans_req;
        next_st         = h_fmt_64 ? ST_H3 : (h_fmt_write ? ST_DATA : ST_H0);
    end
    if(st == ST_H3) begin
        rx_ready        = 1'b1;
        next_st         = h_fmt_write ? ST_DATA : ST_H0;
    end
    if(st == ST_DATA) begin
        rx_ready        = tlp_d_ready;
        tlp_d_valid     = rx_valid;
        tlp_d_strb      = tlp_d_first ? tlp_h_be_first : (rx_last ? tlp_h_be_last : 4'hF);
        next_st         = rx_last ? ST_H0 : ST_DATA;
    end
    if(st == ST_FLUSH) begin
        rx_ready        = 1'b1;
        next_st         = rx_last ? ST_H0 : ST_FLUSH;
    end
end

always @(posedge clk) begin
    if(rst) begin
        st          <= ST_H0;
    end else if(rx_ready && rx_valid) begin
        st          <= next_st;
    end
end


endmodule


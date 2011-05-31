
module dlsc_pcie_s6_tlp_decoder (
    // ** pcie common interface
    input   wire            clk,        // user_clk_out
    input   wire            rst,        // user_reset_out

    // ** pcie receive interface
    output  reg             rx_ready,   // m_axis_rx_tready
    input   wire            rx_valid,   // m_axis_rx_tvalid
    input   wire            rx_last,    // m_axis_rx_tlast
    input   wire    [31:0]  rx_data,    // m_axis_rx_tdata[31:0]
    input   wire    [6:0]   rx_bar,     // m_axis_tx_tuser[9:2]
    input   wire            rx_err,     // m_axis_tx_tuser[1]

    // ** pcie error reporting
    input   wire            err_ready,
    output  reg             err_valid,
    output  reg     [47:0]  err_header, // cfg_err_tlp_cpl_header
    output  reg             err_ur,     // cfg_err_ur
    output  reg             err_posted, // cfg_err_posted

    // ** config
    input   wire    [2:0]   cfg_max_payload, // cfg_dcommand[7:5]

    // ** decoded TLPs
    // handshake
    input   wire            tlp_ready,
    output  reg             tlp_valid,

    // decoded format/type
    output  reg             tlp_mem_read,   // read
    output  reg             tlp_mem_write,  // write
    output  reg             tlp_cpl,        // completion with data

    // common
    output  reg     [2:0]   tlp_tc,         // traffic class
    output  reg     [9:0]   tlp_length,     // payload/request length
    output  reg     [15:0]  tlp_src,        // requester/completer ID

    // memory requests
    output  reg     [7:0]   req_tag,
    output  reg     [3:0]   req_be_last,
    output  reg     [3:0]   req_be_first,
    output  reg     [63:2]  req_addr,

    // completions
    output  reg     [2:0]   cpl_status,
    output  reg             cpl_bcm,
    output  reg     [11:0]  cpl_bytes,
    output  reg     [7:0]   cpl_tag,
    output  reg     [6:0]   cpl_addr,

    // payload
    input   wire            pl_ready,
    output  reg             pl_valid,
    output  reg             pl_last,
    output  reg     [31:0]  pl_data
);

`include "dlsc_pcie_tlp_params.vh"

// friendly field names
wire [1:0]  fmt     = rx_data[30:29];
wire [4:0]  type    = rx_data[28:24];
wire        td      = rx_data[15];
wire        ep      = rx_data[14];

// decoded fields
reg         fmt_4dw;
reg         fmt_data;

// error flags
reg         err_unsupported;
reg         err_unexpected;
reg         err_malformed;


wire        rx_accept   = rx_valid && rx_ready;
wire        tlp_accept  = tlp_valid && tlp_ready;
wire        pl_accept   = pl_valid && pl_ready;

localparam  ST_HDR0     = 0,
            ST_HDR1     = 1,
            ST_HDR2     = 2,
            ST_HDR3     = 3,
            ST_PAYLOAD  = 4,
            ST_DIGEST   = 5;

reg [2:0] st = ST_HDR0;

always @(posedge clk or posedge rst) begin
    if(rst) begin
    
    end else begin
        if(rx_accept) begin
            if(st == ST_HDR0) begin
                fmt_4dw         <= fmt[0];
                fmt_data        <= fmt[1];

                tlp_mem_read    <= (type == TYPE_MEM && fmt[1] == 1'b0);
                tlp_mem_write   <= (type == TYPE_MEM && fmt[1] == 1'b1);
                tlp_cpl         <= (type == TYPE_CPL);

                err_unsupported <= (type != TYPE_MEM || type != TYPE_CPL);

                st              <= ST_HDR1;
            end else if(st == ST_HDR1) begin

                st              <= ST_HDR2;
            end else if(st == ST_HDR2) begin

                st              <= fmt_4dw  ? ST_HDR3 :
                                   fmt_data ? ST_PAYLOAD : 
                                   td       ? ST_DIGEST : ;
            end
        end

        // acceptance of the last word always returns us to initial state
        if(rx_accept && rx_last) begin
            st              <= ST_HDR0;
        end
    end
end

endmodule



module dlsc_pcie_s6_tx (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // TLP transmit interface to PCIe core
    input   wire                    pcie_tx_ready,      // s_axis_tx_tready
    output  reg                     pcie_tx_valid,      // s_axis_tx_tvalid
    output  reg                     pcie_tx_last,       // s_axis_tx_tlast
    output  reg     [31:0]          pcie_tx_data,       // s_axis_tx_tdata
    output  wire                    pcie_tx_dsc,        // s_axis_tx_tuser[3]
    output  wire                    pcie_tx_stream,     // s_axis_tx_tuser[2]
    output  wire                    pcie_tx_err_fwd,    // s_axis_tx_tuser[1]
    input   wire    [5:0]           pcie_tx_buf_av,     // tx_buf_av
    input   wire                    pcie_tx_drop,       // tx_err_drop
    input   wire                    pcie_tx_cfg_req,    // tx_cfg_req
    output  wire                    pcie_tx_cfg_gnt,    // tx_cfg_gnt

    // Error reporting to PCIe core
    input   wire                    pcie_err_ready,     // cfg_err_cpl_rdy
    output  reg     [47:0]          pcie_err_header,    // cfg_err_tlp_cpl_header
    output  reg                     pcie_err_posted,    // cfg_err_posted
    output  reg                     pcie_err_locked,    // cfg_err_locked
    output  reg                     pcie_err_cor,       // cfg_err_cor
    output  reg                     pcie_err_abort,     // cfg_err_cpl_abort
    output  reg                     pcie_err_timeout,   // cfg_err_cpl_timeout
    output  reg                     pcie_err_ecrc,      // cfg_err_ecrc
    output  reg                     pcie_err_unsupported, // cfg_err_ur

    // Errors from _rx
    output  reg                     rx_err_ready,
    input   wire                    rx_err_valid,
    input   wire    [47:0]          rx_err_header,
    input   wire                    rx_err_posted,
    input   wire                    rx_err_locked,
    input   wire                    rx_err_unsupported,
    input   wire                    rx_err_unexpected,
    input   wire                    rx_err_malformed,

    // TLPs from _inbound
    output  wire                    ib_tx_ready,
    input   wire                    ib_tx_valid,
    input   wire                    ib_tx_last,
    input   wire                    ib_tx_error,    // indicates TLP is an unsuccessful completion
    input   wire    [31:0]          ib_tx_data,

    // Errors from _inbound
    output  reg                     ib_err_ready,
    input   wire                    ib_err_valid,
    input   wire                    ib_err_unsupported,

    // TLPs from _outbound
    output  wire                    ob_tx_ready,
    input   wire                    ob_tx_valid,
    input   wire                    ob_tx_last,
    input   wire    [31:0]          ob_tx_data,

    // Errors from _outbound
    output  reg                     ob_err_ready,
    input   wire                    ob_err_valid,
    input   wire                    ob_err_unexpected,
    input   wire                    ob_err_timeout
);

`include "dlsc_pcie_tlp_params.vh"

// tie-off
assign  pcie_tx_cfg_gnt     = 1'b1;     // internal core TLPs can always proceed
assign  pcie_tx_dsc         = 1'b0;     // we never discontinue TLPs
assign  pcie_tx_stream      = 1'b1;     // we always stream TLPs
assign  pcie_tx_err_fwd     = 1'b0;     // we never poison TLPs

// error mux
wire            err_ready;
reg             err_valid;
reg  [47:0]     err_header;
reg             err_posted;
reg             err_locked;
reg             err_cor;
reg             err_abort;
reg             err_timeout;
reg             err_ecrc;
reg             err_unsupported;

reg             pcie_err_valid;
reg  [2:0]      pcie_err_status;

always @* begin
    err_valid       = 1'b0;
    err_header      = {48{1'bx}};
    err_posted      = 1'b1;
    err_locked      = 1'b0;
    err_cor         = 1'b0;
    err_abort       = 1'b0;
    err_timeout     = 1'b0;
    err_ecrc        = 1'b0;
    err_unsupported = 1'b0;
    
    if(rx_err_valid) begin
        rx_err_ready    = err_ready;
        err_valid       = 1'b1;
        err_header      = rx_err_header;
        err_posted      = rx_err_posted;
        err_locked      = rx_err_locked;
        err_unsupported = rx_err_unsupported;
        err_cor         = rx_err_unexpected || rx_err_malformed;
    end else if(ib_err_valid) begin
        ib_err_ready    = err_ready;
        err_valid       = 1'b1;
        err_unsupported = ib_err_unsupported;
    end else if(ob_err_valid) begin
        ob_err_ready    = err_ready;
        err_valid       = 1'b1;
        err_cor         = ob_err_unexpected;
        err_timeout     = ob_err_timeout;
    end
end

// states
localparam  ST_ARB      = 3'b000,
            ST_TLP_H0   = 3'b001,
            ST_TLP_H1   = 3'b011,
            ST_TLP_H2   = 3'b101,
            ST_TLP      = 3'b111;

reg  [2:0]      st;
wire            st_arb          = (st[0] == 1'b0);
wire            st_tlp          = (st[0] == 1'b1);

// TLP arbiter and mux
reg             arb_ib;

wire            arb_ready       = st_tlp && (pcie_tx_ready || !pcie_tx_valid);
wire            arb_valid       = arb_ib ? ib_tx_valid  : ob_tx_valid;
wire            arb_last        = arb_ib ? ib_tx_last   : ob_tx_last;
wire            arb_error       = arb_ib ? ib_tx_error  : 1'b0;
wire [31:0]     arb_data        = arb_ib ? ib_tx_data   : ob_tx_data;

assign          ib_tx_ready     = arb_ib ? arb_ready    : 1'b0;
assign          ob_tx_ready     = arb_ib ? 1'b0         : arb_ready;

assign          err_ready       = st_arb && pcie_err_ready && !pcie_err_valid;

always @(posedge clk) begin
    if(rst) begin
        pcie_tx_valid   <= 1'b0;
    end else begin
        if(pcie_tx_ready) begin
            pcie_tx_valid   <= 1'b0;
        end
        if(arb_ready && arb_valid && !arb_error) begin
            pcie_tx_valid   <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(arb_ready && arb_valid && !arb_error) begin
        pcie_tx_last    <= arb_last;
        pcie_tx_data    <= arb_data;
    end
end

always @(posedge clk) begin
    if(rst) begin
        st              <= ST_ARB;
        arb_ib          <= 1'b0;
    end else begin
        if(st_arb && pcie_err_ready && !pcie_err_valid && !err_valid) begin
            if(ib_tx_valid || ob_tx_valid) begin
                st              <= ST_TLP_H0;
                if( !(arb_ib ? ib_tx_valid : ob_tx_valid) ) begin
                    arb_ib          <= !arb_ib;
                end
            end
        end
        if(arb_ready && arb_valid) begin
            if(st == ST_TLP_H0) begin
                st          <= ST_TLP_H1;
            end
            if(st == ST_TLP_H1) begin
                st          <= ST_TLP_H2;
            end
            if(st == ST_TLP_H2) begin
                st          <= ST_TLP;
            end
            if(arb_last) begin
                st          <= ST_ARB;
                if( !err_valid && !arb_error && (arb_ib ? ob_tx_valid : ib_tx_valid) ) begin
                    // can skip arb and go straight to TLP transfer for other channel (ib/ob)
                    st              <= ST_TLP_H0;
                    arb_ib          <= !arb_ib;
                end
            end
        end
    end
end

// TODO: prevent assertion of errors when link is in not in D0 power state

always @(posedge clk) begin
    // all error signals deassert after 1 cycle
    pcie_err_valid      <= 1'b0;
    pcie_err_cor        <= 1'b0;
    pcie_err_abort      <= 1'b0;
    pcie_err_timeout    <= 1'b0;
    pcie_err_ecrc       <= 1'b0;
    pcie_err_unsupported<= 1'b0;

    if(err_ready && err_valid) begin
        // sending error from dedicated error input
        pcie_err_valid      <= 1'b1;
        pcie_err_cor        <= err_cor;
        pcie_err_abort      <= err_abort;
        pcie_err_timeout    <= err_timeout;
        pcie_err_ecrc       <= err_ecrc;
        pcie_err_unsupported<= err_unsupported;

        pcie_err_header     <= err_header;
        pcie_err_posted     <= err_posted;
        pcie_err_locked     <= err_locked;
        pcie_err_status     <= {3{1'bx}};
    end
    if(arb_ready && arb_valid && arb_error) begin
        // extracting error from TLP
        // header is:
        // [47:41]  = lower address (h2[ 6: 0])
        // [40:29]  = byte count    (h1[11: 0])
        // [28:26]  = traffic class (h0[22:20])
        // [25:24]  = attributes    (h0[13:12])
        // [23: 8]  = requester ID  (h2[31:16])
        // [ 7: 0]  = tag           (h2[15: 8])
        if(st == ST_TLP_H0) begin
            pcie_err_header[28:26]  <= arb_data[22:20];
            pcie_err_header[25:24]  <= arb_data[13:12];
        end
        if(st == ST_TLP_H1) begin
            pcie_err_header[40:29]  <= arb_data[11: 0];
            pcie_err_status         <= arb_data[15:13]; // completion status
        end
        if(st == ST_TLP_H2) begin
            pcie_err_header[47:41]  <= arb_data[ 6: 0];
            pcie_err_header[23: 8]  <= arb_data[31:16];
            pcie_err_header[ 7: 0]  <= arb_data[15: 8];
        end
        pcie_err_posted     <= 1'b0;    // completion TLPs are never for posted requests
        pcie_err_locked     <= 1'b0;    // completion TLPs are never for locked requests
        if(arb_last) begin
            pcie_err_valid      <= 1'b1;
            // completion status (saved during TLP_H1)
            case(pcie_err_status)
                CPL_CA:     pcie_err_abort          <= 1'b1;
                default:    pcie_err_unsupported    <= 1'b1;
            endcase
        end
    end
end


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge clk) begin
    if(pcie_err_valid && !pcie_err_ready) begin
        `dlsc_error("pcie_err_valid asserted without pcie_err_ready");
    end
end

`include "dlsc_sim_bot.vh"
`endif


endmodule


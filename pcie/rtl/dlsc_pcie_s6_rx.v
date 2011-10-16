
module dlsc_pcie_s6_rx #(
    parameter IB_READ_EN        = 1,
    parameter IB_WRITE_EN       = 1,
    parameter OB_READ_EN        = 1,
    parameter OB_WRITE_EN       = 1,
    parameter TRANS_BAR0_EN     = 1,
    parameter TRANS_BAR1_EN     = 1,
    parameter TRANS_BAR2_EN     = 1,
    parameter TRANS_BAR3_EN     = 1,
    parameter TRANS_BAR4_EN     = 1,
    parameter TRANS_BAR5_EN     = 1,
    parameter TRANS_ROM_EN      = 1,
    parameter TRANS_CFG_EN      = 1
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // TLP receive interface from PCIe core
    output  wire                    pcie_rx_ready,      // m_axis_rx_tready
    input   wire                    pcie_rx_valid,      // m_axis_rx_tvalid
    input   wire                    pcie_rx_last,       // m_axis_rx_tlast
    input   wire    [31:0]          pcie_rx_data,       // m_axis_rx_tdata
    input   wire                    pcie_rx_err,        // m_axis_rx_tuser[1]
    input   wire    [6:0]           pcie_rx_bar,        // m_axis_rx_tuser[8:2]

    // Errors to _tx
    input   wire                    rx_err_ready,
    output  reg                     rx_err_valid,
    output  reg     [47:0]          rx_err_header,
    output  reg                     rx_err_posted,
    output  reg                     rx_err_locked,
    output  reg                     rx_err_unsupported,
    output  reg                     rx_err_unexpected,
    output  reg                     rx_err_malformed,

    // TLPs to _inbound
    input   wire                    ib_rx_ready,
    output  wire                    ib_rx_valid,
    output  wire                    ib_rx_last,
    output  wire    [31:0]          ib_rx_data,
    output  wire                    ib_rx_err,
    output  wire    [6:0]           ib_rx_bar,

    // TLPs to _outbound
    input   wire                    ob_rx_ready,
    output  wire                    ob_rx_valid,
    output  wire                    ob_rx_last,
    output  wire    [31:0]          ob_rx_data,
    output  wire                    ob_rx_err
);

`include "dlsc_pcie_tlp_params.vh"

// buffer input

wire            rx_ready;
reg             rx_valid;
reg             rx_last;
reg  [31:0]     rx_data;
reg             rx_err;
reg  [6:0]      rx_bar;

assign          pcie_rx_ready   = (rx_ready || !rx_valid);

always @(posedge clk) begin
    if(rst) begin
        rx_valid    <= 1'b0;
    end else begin
        if(rx_ready) begin
            rx_valid    <= 1'b0;
        end
        if(pcie_rx_ready && pcie_rx_valid) begin
            rx_valid    <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(pcie_rx_ready && pcie_rx_valid) begin
        rx_last     <= pcie_rx_last;
        rx_data     <= pcie_rx_data;
        rx_err      <= pcie_rx_err;
        rx_bar      <= pcie_rx_bar;
    end
end

assign          ib_rx_last      = rx_last;
assign          ib_rx_data      = rx_data;
assign          ib_rx_err       = rx_err;
assign          ib_rx_bar       = rx_bar;

assign          ob_rx_last      = rx_last;
assign          ob_rx_data      = rx_data;
assign          ob_rx_err       = rx_err;


// TLP decoder

wire [1:0]      tlp_fmt         = rx_data[30:29];
wire            tlp_fmt_4dw     = tlp_fmt[0];
wire            tlp_fmt_data    = tlp_fmt[1];
wire [4:0]      tlp_type        = rx_data[28:24];
wire [2:0]      tlp_tc          = rx_data[22:20];
wire            tlp_digest      = rx_data[15];
wire            tlp_poisoned    = rx_data[14];
wire [1:0]      tlp_attr        = rx_data[13:12];
wire [1:0]      tlp_at          = rx_data[11:10];
wire [9:0]      tlp_len         = rx_data[9:0];

reg             tlp_inbound;
reg             tlp_outbound;
reg             tlp_locked;
reg             tlp_posted;
reg             tlp_unsupported;    // valid request, but we don't support it
reg             tlp_unexpected;     // completion not expected
reg             tlp_malformed;      // unable to decode TLP
reg             tlp_ignore;         // TLP isn't supported, but also not an error

always @* begin

    tlp_inbound     = 1'b0;
    tlp_outbound    = 1'b0;
    tlp_locked      = 1'b0;
    tlp_posted      = 1'b1;
    tlp_unsupported = 1'b0;
    tlp_unexpected  = 1'b0;
    tlp_malformed   = 1'b1;
    tlp_ignore      = 1'b0;

    if(tlp_type == TYPE_MEM || (!tlp_fmt_4dw && (
       tlp_type == TYPE_IO ||
       tlp_type == TYPE_CONFIG_0 ||
       tlp_type == TYPE_CONFIG_1) ) )
    begin
        // inbound read/write
        tlp_malformed   = 1'b0;
        tlp_posted      = (tlp_type == TYPE_MEM && tlp_fmt_data);   // only memory writes are posted
        if(tlp_fmt_data) begin
            // write
            tlp_inbound     = (IB_WRITE_EN != 0);
            tlp_unsupported = (IB_WRITE_EN == 0);
        end else begin
            // read
            tlp_inbound     = (IB_READ_EN != 0);
            tlp_unsupported = (IB_READ_EN == 0);
        end
    end

    if(tlp_type == TYPE_CPL) begin
        // only outbound reads will generate completions
        tlp_outbound    = (OB_READ_EN != 0);
        tlp_unexpected  = (OB_READ_EN == 0);
    end

    if(tlp_type == TYPE_MEM_LOCKED) begin
        tlp_malformed   = 1'b0;
        tlp_locked      = 1'b1;
        tlp_posted      = tlp_fmt_data;
        tlp_unsupported = 1'b1;
    end

    if(tlp_type == TYPE_CPL_LOCKED) begin
        tlp_malformed   = 1'b0;
        tlp_locked      = 1'b1;
        tlp_unexpected  = 1'b1;
    end

    if(tlp_type == TYPE_MSG_TO_RC ||
       tlp_type == TYPE_MSG_BY_ADDR ||
       tlp_type == TYPE_MSG_BY_ID ||
       tlp_type == TYPE_MSG_FROM_RC ||
       tlp_type == TYPE_MSG_LOCAL ||
       tlp_type == TYPE_MSG_PME_RC)
    begin
        // we don't support messages
        // (PCIe core should act on them)
        tlp_malformed   = 1'b0;
        tlp_ignore      = 1'b1;
    end

end


// states
localparam  ST_H0       = 3'b000,
            ST_H1       = 3'b001,
            ST_H2       = 3'b011,
            ST_H3       = 3'b101,
            ST_DATA     = 3'b111;

reg  [2:0]      st;
reg             st_ib;      // routing TLP to _inbound
reg             st_ob;      // routing TLP to _outbound
reg             st_err;     // flushing errored TLP

wire            st_h0           = (st[0] == 1'b0);

wire            next_st_ib      = (!st_h0) ? st_ib    : tlp_inbound;
wire            next_st_ob      = (!st_h0) ? st_ob    : tlp_outbound;
wire            next_st_err     = (!st_h0) ? st_err   : !(tlp_inbound || tlp_outbound);

assign          ib_rx_valid     = rx_valid && next_st_ib;
assign          ob_rx_valid     = rx_valid && next_st_ob;

assign          rx_ready        = next_st_err || (next_st_ib && ib_rx_ready) || (next_st_ob && ob_rx_ready);

always @(posedge clk) begin
    if(rst) begin
        st      <= ST_H0;
        st_ib   <= 1'b0;
        st_ob   <= 1'b0;
        st_err  <= 1'b0;
    end else if(rx_ready && rx_valid) begin

        st_ib   <= next_st_ib;
        st_ob   <= next_st_ob;
        st_err  <= next_st_err;

        case(st)
            ST_H0:      st <= ST_H1;
            ST_H1:      st <= ST_H2;
            ST_H2:      st <= ST_H3;
            ST_H3:      st <= ST_DATA;
            ST_DATA:    st <= ST_DATA;
            default:    st <= ST_H0;
        endcase

        if(rx_last)     st <= ST_H0;

    end
end


// capture errors
reg             err_ignore;
reg  [9:0]      err_len;
reg  [3:0]      err_be_first;
reg  [3:0]      err_be_last;
reg             err_fmt_4dw;
reg             err_type_memrd;

wire [11:0]     bytes_remaining;
wire [1:0]      byte_offset;

generate
if(!IB_READ_EN) begin:GEN_CPLBYTES
    // only need to calculate bytes_remaining for memory read completions
    dlsc_pcie_cplbytes dlsc_pcie_cplbytes_inst (
        .len            ( err_len ),
        .be_first       ( err_be_first ),
        .be_last        ( err_be_last ),
        .type_mem       ( err_type_memrd ),
        .bytes_remaining ( bytes_remaining ),
        .byte_offset    ( byte_offset )
    );
end else begin:GEN_NO_CPLBYTES
    assign bytes_remaining  = 12'd4;
    assign byte_offset      = 2'd0;
end
endgenerate

always @(posedge clk) begin
    if(st == ST_H0) begin
        rx_err_posted           <= tlp_posted;
        rx_err_locked           <= tlp_locked;
        rx_err_unsupported      <= tlp_unsupported;
        rx_err_unexpected       <= tlp_unexpected;
        rx_err_malformed        <= tlp_malformed;
        err_ignore              <= tlp_ignore;
    end
    if(!IB_READ_EN || !IB_WRITE_EN) begin
        if(st == ST_H0) begin
            rx_err_header[28:26]    <= tlp_tc;          // traffic class
            rx_err_header[25:24]    <= tlp_attr;        // attributes
            err_len                 <= tlp_len;
            err_fmt_4dw             <= tlp_fmt_4dw;
            err_type_memrd          <= (tlp_type == TYPE_MEM || tlp_type == TYPE_MEM_LOCKED) && !tlp_fmt_data;
        end
        if(st == ST_H1 && !rx_err_posted) begin
            rx_err_header[23: 8]    <= rx_data[31:16];  // requester ID
            rx_err_header[ 7: 0]    <= rx_data[15: 8];  // tag
            err_be_last             <= rx_data[ 7: 4];
            err_be_first            <= rx_data[ 3: 0];
        end
        if( (err_fmt_4dw ? (st == ST_H3) : (st == ST_H2)) && !rx_err_posted) begin
            if(err_type_memrd && !IB_READ_EN) begin
                rx_err_header[47:41]    <= { rx_data[6:2], byte_offset }; // lower address
                rx_err_header[40:29]    <= bytes_remaining; // byte count
            end else begin
                rx_err_header[47:41]    <= 7'd0;
                rx_err_header[40:29]    <= 12'd4;
            end
        end
    end else begin
        err_len                 <= 10'h0;
        err_fmt_4dw             <= 1'b0;
        err_type_memrd          <= 1'b0;
        err_be_last             <= 4'h0;
        err_be_first            <= 4'h0;
        rx_err_header           <= {48{1'b0}};
    end
end

always @(posedge clk) begin
    if(rst) begin
        rx_err_valid    <= 1'b0;
    end else begin
        if(rx_err_ready) begin
            rx_err_valid    <= 1'b0;
        end
        if(st_err && !err_ignore && rx_ready && rx_valid && rx_last) begin
            // set error on last
            rx_err_valid    <= 1'b1;
        end
    end
end

endmodule


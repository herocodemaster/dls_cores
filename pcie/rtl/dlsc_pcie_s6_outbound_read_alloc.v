
module dlsc_pcie_s6_outbound_read_alloc #(
    parameter ADDR      = 32,
    parameter TAG       = 5,
    parameter BUFA      = 9,
    parameter CPLH      = 8,    // receive buffer completion header space
    parameter CPLD      = 64,   // receive buffer completion data space
    parameter FCHB      = 8,
    parameter FCDB      = 12
) (
    // system
    input   wire                clk,
    input   wire                rst,
    
    // writes to tag memories in _cpl and _buffer
    output  reg                 alloc_init,
    output  reg                 alloc_valid,
    output  reg     [TAG:0]     alloc_tag,
    output  reg     [9:0]       alloc_len,
    output  reg     [6:2]       alloc_addr,
    output  reg     [BUFA:0]    alloc_bufa,

    // feedback from _cpl
    input   wire                dealloc_cplh,       // freed a header credit
    input   wire                dealloc_cpld,       // freed a data credit

    // feedback from _buffer
    input   wire                dealloc_tag,        // freed a tag
    input   wire                dealloc_data,       // freed a dword

    // TLP input from _req
    output  wire                tlp_h_ready,
    input   wire                tlp_h_valid,
    input   wire    [ADDR-1:2]  tlp_h_addr,
    input   wire    [9:0]       tlp_h_len,

    // TLP output to arbiter
    input   wire                rd_tlp_h_ready,
    output  reg                 rd_tlp_h_valid,
    output  reg     [ADDR-1:2]  rd_tlp_h_addr,
    output  reg     [9:0]       rd_tlp_h_len,
    output  reg     [TAG-1:0]   rd_tlp_h_tag,
    output  reg     [3:0]       rd_tlp_h_be_first,
    output  reg     [3:0]       rd_tlp_h_be_last,
    
    // PCIe config/status
    output  reg                 tlp_pending,        // transactions pending
    input   wire                dma_en,             // bus-mastering enabled
    input   wire                rcb                 // read completion boundary; 64 or 128 bytes
);

// ** Compute required space **

wire            h_ready;
reg             h_valid         = 1'b0;
wire            h_xfer          = h_ready && h_valid;

reg  [ADDR-1:2] h_addr          = 0;
reg  [10:0]     h_len           = 0;
reg  [6:0]      h_cplh          = 0;
reg  [8:0]      h_cpld          = 0;

// From Xilinx UG654:
// NP_CplH = ceiling[((Start_Address mod RCB     ) + Request_Size) / RCB] 
// NP_CplD = ceiling[((Start_Address mod 16 bytes) + Request_Size) / 16 bytes]

wire [9:0]      h_cplh_pre      = (rcb == 1'b1) ?
                                    ( {5'h0,tlp_h_addr[6:2]} + tlp_h_len + 10'd31 ) :  // 128
                                    ( {6'h0,tlp_h_addr[5:2]} + tlp_h_len + 10'd15 );   // 64

wire [9:0]      h_cpld_pre      =   ( {8'h0,tlp_h_addr[3:2]} + tlp_h_len + 10'd3  );   // 16

always @(posedge clk) begin
    if(tlp_h_ready && tlp_h_valid) begin
        h_addr      <= tlp_h_addr;
        if(tlp_h_len == 0) begin
            // special case for max length
            h_cplh      <= (rcb == 1'b0) ? 7'd64 : 7'd32;
            h_cpld      <= 9'd256;
            h_len       <= {1'b1,tlp_h_len};
        end else begin
            h_cplh      <= (rcb == 1'b0) ? {1'h0,h_cplh_pre[9:4]} : {2'h0,h_cplh_pre[9:5]};
            h_cpld      <= {1'b0,h_cpld_pre[9:2]};
            h_len       <= {1'b0,tlp_h_len};
        end
    end
end

assign          tlp_h_ready     = !h_valid && dma_en;

always @(posedge clk) begin
    if(rst) begin
        h_valid     <= 1'b0;
    end else begin
        if(h_ready) begin
            h_valid     <= 1'b0;
        end
        if(tlp_h_ready && tlp_h_valid) begin
            h_valid     <= 1'b1;
        end
    end
end


// ** Track space **

// Credits

reg  [FCHB-1:0] cplh_avail      = CPLH;
reg  [FCDB-1:0] cpld_avail      = CPLD;

wire [FCHB:0]   cplh_sub        = {1'b0, cplh_avail} - { {(FCHB-6){1'b0}}, h_cplh };
wire [FCDB:0]   cpld_sub        = {1'b0, cpld_avail} - { {(FCDB-8){1'b0}}, h_cpld };

// only okay if space is available (result of subtraction is non-negative)
wire            cplh_okay       = !cplh_sub[FCHB];
wire            cpld_okay       = !cpld_sub[FCDB];

always @(posedge clk) begin
    if(rst) begin
        cplh_avail          <= CPLH;
        cpld_avail          <= CPLD;
    end else begin
        if(h_xfer) begin
            cplh_avail              <= cplh_sub[FCHB-1:0] + { {(FCHB-1){1'b0}}, dealloc_cplh };
            cpld_avail              <= cpld_sub[FCDB-1:0] + { {(FCDB-1){1'b0}}, dealloc_cpld };
        end else begin
            cplh_avail              <= cplh_avail         + { {(FCHB-1){1'b0}}, dealloc_cplh };
            cpld_avail              <= cpld_avail         + { {(FCDB-1){1'b0}}, dealloc_cpld };
        end
    end
end

// Tags

reg  [TAG:0]    tag             = 0;
reg  [TAG-1:0]  tag_cnt         = 0;
reg             tag_zero        = 1'b1;
reg             tag_max         = 1'b0;
reg             tag_init        = 1'b1;
wire            tag_inc         = h_xfer;
wire            tag_dec         = dealloc_tag;

always @(posedge clk) begin
    if(rst) begin
        tag_cnt         <= 0;
        tag_zero        <= 1'b1;
        tag_max         <= 1'b0;
        tag             <= 0;
        tag_init        <= 1'b1;
    end else begin
        if(tag_init && (&tag)) begin
            // done initializing once we've written all tags once
            tag_init        <= 1'b0;
        end
        if(tag_init || tag_inc) begin
            tag             <= tag + 1;
        end
        if( tag_inc && !tag_dec) begin
            tag_cnt         <= tag_cnt + 1;
            tag_zero        <= 1'b0;
            tag_max         <= &tag_cnt;
        end
        if(!tag_inc &&  tag_dec) begin
            tag_cnt         <= tag_cnt - 1;
            tag_zero        <= (tag_cnt == 1);
            tag_max         <= 1'b0;
        end
    end
end

// Buffer

localparam      BUFS            = (BUFA<10) ? 10 : BUFA;
localparam      BUFA_PAD        = (BUFA<10) ? (10-BUFA) : 0;
localparam      LEN_PAD         = (BUFA>10) ? (BUFA-10) : 0;

reg  [BUFA:0]   buf_avail       = (2**BUFA);
wire [BUFS:0]   buf_avail_sub   = { {BUFA_PAD{1'b0}}, buf_avail } - { {LEN_PAD{1'b0}}, h_len };

reg  [BUFA:0]   buf_addr        = 0;
wire [BUFS:0]   buf_addr_add    = { {BUFA_PAD{1'b0}}, buf_addr } + { {LEN_PAD{1'b0}}, h_len };

wire            buf_okay        = !buf_avail_sub[BUFS];

always @(posedge clk) begin
    if(rst) begin
        buf_avail       <= (2**BUFA);
        buf_addr        <= 0;
    end else begin

        if(h_xfer) begin
            buf_addr        <= buf_addr_add[BUFA:0];
            buf_avail       <= buf_avail_sub[BUFA:0] + { {BUFA{1'b0}}, dealloc_data };
        end else begin
            buf_avail       <= buf_avail             + { {BUFA{1'b0}}, dealloc_data };
        end

    end
end


// Only if there is free space everywhere can we allow this transaction..
assign          h_ready         = !tag_init && !tag_max && !rd_tlp_h_valid &&
                                    cplh_okay && cpld_okay && buf_okay;

// register alloc outputs
always @(posedge clk) begin
    alloc_init      <= tag_init || rst;
    alloc_valid     <= tag_init || h_xfer;
    alloc_tag       <= tag;
    alloc_len       <= h_len[9:0];
    alloc_addr      <= h_addr[6:2];
    alloc_bufa      <= buf_addr;
    tlp_pending     <= !tag_zero;
end


// ** TLP output **

always @(posedge clk) begin
    if(rst) begin
        rd_tlp_h_valid  <= 1'b0;
    end else begin
        if(rd_tlp_h_ready) begin
            rd_tlp_h_valid  <= 1'b0;
        end
        if(h_xfer) begin
            rd_tlp_h_valid  <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(h_xfer) begin
        rd_tlp_h_addr       <= h_addr;
        rd_tlp_h_len        <= h_len[9:0];
        rd_tlp_h_tag        <= tag[TAG-1:0];
        rd_tlp_h_be_first   <= 4'hF;
        rd_tlp_h_be_last    <= (h_len[9:0] == 10'd1) ? 4'h0 : 4'hF;
    end
end


endmodule



module dlsc_pcie_s6_outbound_write_alloc #(
    parameter ADDR      = 32,
    parameter FCHB      = 8,
    parameter FCDB      = 12
) (
    // system
    input   wire                clk,
    input   wire                rst,

    // TLP header from write_core
    output  wire                tlp_h_ready,
    input   wire                tlp_h_valid,
    input   wire    [ADDR-1:2]  tlp_h_addr,
    input   wire    [9:0]       tlp_h_len,
    input   wire    [3:0]       tlp_h_be_first,
    input   wire    [3:0]       tlp_h_be_last,

    // TLP payload from write_core
    output  wire                tlp_d_ready,
    input   wire                tlp_d_valid,
    input   wire    [31:0]      tlp_d_data,

    // TLP header to arbiter
    input   wire                wr_tlp_h_ready,
    output  reg                 wr_tlp_h_valid,
    output  reg     [ADDR-1:2]  wr_tlp_h_addr,
    output  reg     [9:0]       wr_tlp_h_len,
    output  reg     [3:0]       wr_tlp_h_be_first,
    output  reg     [3:0]       wr_tlp_h_be_last,

    // TLP payload to arbiter
    input   wire                wr_tlp_d_ready,
    output  reg                 wr_tlp_d_valid,
    output  reg     [31:0]      wr_tlp_d_data,
    output  reg                 wr_tlp_d_last,

    // PCIe link partner credit info
    output  wire    [2:0]       fc_sel,     // selects 'transmit credits available'
    input   wire    [FCHB-1:0]  fc_ph,      // posted header credits
    input   wire    [FCDB-1:0]  fc_pd,      // posted data credits
    
    // PCIe config/status
    input   wire                dma_en      // bus-mastering enabled
);

assign          fc_sel          = 3'b100;   // transmit credits available

// register fc signals
reg  [FCHB-1:0] fc_ph_r;
reg  [FCDB-1:0] fc_pd_r;

always @(posedge clk) begin
    fc_ph_r     <= fc_ph;
    fc_pd_r     <= fc_pd;
end


// ** Compute required space **

wire            h_ready;
reg             h_valid         = 1'b0;
wire            h_xfer          = h_ready && h_valid;

always @(posedge clk) begin
    if(rst) begin
        h_valid     <= 1'b0;
    end else begin
        if(h_xfer) begin
            h_valid     <= 1'b0;
        end
        if(tlp_h_ready && tlp_h_valid) begin
            h_valid     <= 1'b1;
        end
    end
end

reg  [ADDR-1:2] h_addr          = 0;
reg  [9:0]      h_len           = 0;
reg  [3:0]      h_be_first      = 0;
reg  [3:0]      h_be_last       = 0;
reg  [8:0]      h_cpld          = 0;

// data credits
// TODO: this is based on read allocator.. does address alignment matter for writes?
wire [9:0]      h_cpld_pre      =   ( {8'h0,tlp_h_addr[3:2]} + tlp_h_len + 10'd3  );

assign          tlp_h_ready     = !h_valid && dma_en;

always @(posedge clk) begin
    if(tlp_h_ready && tlp_h_valid) begin
        h_addr      <= tlp_h_addr;
        h_len       <= tlp_h_len;
        h_be_first  <= tlp_h_be_first;
        h_be_last   <= tlp_h_be_last;
        if(tlp_h_len == 0) begin
            // special case for max length
            h_cpld      <= 9'd256;
        end else begin
            h_cpld      <= {1'b0,h_cpld_pre[9:2]};
        end
    end
end

// check space
wire            cplh_okay       = ( !fc_ph_r[FCHB-1] && fc_ph_r[FCHB-2:0] != 0 );                               // cplh >= 1
wire            cpld_okay       = ( !fc_pd_r[FCDB-1] && fc_pd_r[FCDB-2:0] >= { {(FCDB-1-9){1'b0}}, h_cpld } );  // cpld >= h_cpld

reg             d_active        = 1'b0;
reg             d_last          = 1'b0;

assign          h_ready         = !d_active && cplh_okay && cpld_okay;

assign          tlp_d_ready     = d_active && (!wr_tlp_d_valid || wr_tlp_d_ready);

wire            tlp_d_xfer      = tlp_d_ready && tlp_d_valid;

// header payload
always @(posedge clk) begin
    if(h_xfer) begin
        wr_tlp_h_addr       <= h_addr;
        wr_tlp_h_len        <= h_len;
        wr_tlp_h_be_first   <= h_be_first;
        wr_tlp_h_be_last    <= h_be_last;
        d_last              <= (h_len == 1);
    end
    if(tlp_d_xfer) begin
        wr_tlp_h_len        <= wr_tlp_h_len - 1;
        d_last              <= (wr_tlp_h_len == 2);
    end
end

// internal active flag
always @(posedge clk) begin
    if(rst) begin
        d_active        <= 1'b0;
    end else begin
        if(tlp_d_xfer && d_last) begin
            // done with tlp_h_ once last data is output
            d_active        <= 1'b0;
        end
        if(h_xfer) begin
            d_active        <= 1'b1;
        end
    end
end

// header valid
always @(posedge clk) begin
    if(rst) begin
        wr_tlp_h_valid  <= 1'b0;
    end else begin
        if(wr_tlp_h_ready) begin
            wr_tlp_h_valid  <= 1'b0;
        end
        if(h_xfer) begin
            wr_tlp_h_valid  <= 1'b1;
        end
    end
end

// data valid
always @(posedge clk) begin
    if(rst) begin
        wr_tlp_d_valid  <= 1'b0;
    end else begin
        if(wr_tlp_d_ready) begin
            wr_tlp_d_valid  <= 1'b0;
        end
        if(tlp_d_xfer) begin
            wr_tlp_d_valid  <= 1'b1;
        end
    end
end

// data payload
always @(posedge clk) begin
    if(tlp_d_xfer) begin
        wr_tlp_d_data   <= tlp_d_data;
        wr_tlp_d_last   <= d_last;
    end
end

endmodule



module dlsc_pcie_s6_inbound_tlp
(
    // System
    input   wire                clk,
    input   wire                rst,

    // Status
    output  wire                rx_np_ok,

    // TLP ID from decode
    output  wire                tlp_id_ready,
    input   wire                tlp_id_valid,
    input   wire                tlp_id_write,
    input   wire    [28:0]      tlp_id_data,        // { TC, attr, ReqID, Tag }

    // Write completion header (non-posted only)
    output  wire                wr_h_ready,
    input   wire                wr_h_valid,
    input   wire    [1:0]       wr_h_resp,

    // Read completion header
    output  wire                rd_h_ready,
    input   wire                rd_h_valid,
    input   wire    [6:0]       rd_h_addr,
    input   wire    [9:0]       rd_h_len,
    input   wire    [11:0]      rd_h_bytes,
    input   wire                rd_h_last,
    input   wire    [1:0]       rd_h_resp,

    // Read completion data
    output  reg                 rd_d_ready,
    input   wire                rd_d_valid,
    input   wire    [31:0]      rd_d_data,
    input   wire                rd_d_last,

    // TLP output
    input   wire                tx_ready,
    output  wire                tx_valid,
    output  wire    [31:0]      tx_data,
    output  wire                tx_last,

    // PCIe ID
    input   wire    [7:0]       bus_number,
    input   wire    [4:0]       dev_number,
    input   wire    [2:0]       func_number
);

localparam  AXI_RESP_OKAY       = 2'b00,
            AXI_RESP_SLVERR     = 2'b10,
            AXI_RESP_DECERR     = 2'b11;

// Buffer completion IDs

wire            id_ready;
wire            id_valid;
wire            id_write;
wire [2:0]      id_tc;
wire [1:0]      id_attr;
wire [15:0]     id_reqid;
wire [7:0]      id_tag;
wire            id_almost_full;

assign          rx_np_ok        = !id_almost_full;

dlsc_fifo_rvh #(
    .DATA           ( 30 ),
    .DEPTH          ( 16 ),
    .ALMOST_FULL    ( 4 )
) dlsc_fifo_rvh_id (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_ready       ( tlp_id_ready ),
    .wr_valid       ( tlp_id_valid ),
    .wr_data        ( { tlp_id_write, tlp_id_data } ),
    .wr_almost_full ( id_almost_full ),
    .rd_ready       ( id_ready ),
    .rd_valid       ( id_valid ),
    .rd_data        ( { id_write, id_tc, id_attr, id_reqid, id_tag } ),
    .rd_almost_empty(  )
);


// Buffer TLP output

wire            tlp_ready;
reg             tlp_valid;
reg  [31:0]     tlp_data;
reg             tlp_last;

dlsc_fifo_rvh #(
    .DATA           ( 33 ),
    .DEPTH          ( 16 )
) dlsc_fifo_rvh_tlp (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_ready       ( tlp_ready ),
    .wr_valid       ( tlp_valid ),
    .wr_data        ( { tlp_last, tlp_data } ),
    .wr_almost_full (  ),
    .rd_ready       ( tx_ready ),
    .rd_valid       ( tx_valid ),
    .rd_data        ( { tx_last, tx_data } ),
    .rd_almost_empty(  )
);


// Mux input

wire            h_write         = id_write;
reg  [6:0]      h_addr;
reg  [9:0]      h_len;
reg  [11:0]     h_bytes;
reg             h_err;
reg             h_last;

reg             h_ready;
assign          wr_h_ready      = id_valid && ( id_write && h_ready);
assign          rd_h_ready      = id_valid && (!id_write && h_ready);

wire            h_valid         = id_valid && (id_write ? wr_h_valid : rd_h_valid);

assign          id_ready        = h_ready && h_valid && h_last;

always @* begin

    h_addr      = 7'd0;
    h_len       = 10'd1;
    h_bytes     = 12'd4;
    h_err       = 1'b1;
    h_last      = 1'b1;

    if(id_write) begin
        h_err       = (wr_h_resp != AXI_RESP_OKAY);
    end else begin
        h_err       = (rd_h_resp != AXI_RESP_OKAY);
        h_addr      = rd_h_addr;
        h_len       = rd_h_len;
        h_bytes     = rd_h_bytes;
        h_last      = rd_h_last;
    end

end


// Generate TLP

localparam  ST_H0       = 0,
            ST_H1       = 1,
            ST_H2       = 2,
            ST_DATA     = 3,
            ST_FLUSH_D  = 4,
            ST_FLUSH_H  = 5;

reg  [2:0]      st;
reg  [2:0]      next_st;

always @(posedge clk) begin
    if(rst) begin
        st          <= ST_H0;
    end else begin
        st          <= next_st;
    end
end


always @* begin
    next_st             = st;

    h_ready             = 1'b0;
    rd_d_ready          = 1'b0;

    tlp_valid           = 1'b0;
    tlp_data            = 0;
    tlp_last            = 1'b0;

    if(st == ST_H0) begin
        tlp_data[30]        = !h_write && !h_err;   // has data only on successful read completion
        tlp_data[29]        = 1'b0;                 // 3DW
        tlp_data[28:24]     = 5'b01010;             // completion
        tlp_data[22:20]     = id_tc;
        tlp_data[13:12]     = id_attr;
        tlp_data[9:0]       = h_len;

        tlp_valid           = h_valid;

        if(tlp_ready && h_valid) begin
            next_st             = ST_H1;
        end
    end

    if(st == ST_H1) begin
        tlp_data[31:16]     = { bus_number, dev_number, func_number };
        tlp_data[15:13]     = h_err ? 3'b001 : 3'b000;  // UR or SC
        tlp_data[11:0]      = h_bytes;

        tlp_valid           = 1'b1;

        if(tlp_ready) begin
            next_st             = ST_H2;
        end
    end

    if(st == ST_H2) begin
        tlp_data[31:16]     = id_reqid;
        tlp_data[15:8]      = id_tag;
        tlp_data[6:0]       = h_addr;

        tlp_valid           = 1'b1;
        tlp_last            = h_write || h_err;

        if(tlp_ready) begin
            h_ready             = h_write ? 1'b1  : ( h_err ? 1'b0       : 1'b1 );
            next_st             = h_write ? ST_H0 : ( h_err ? ST_FLUSH_D : ST_DATA );
        end
    end

    if(st == ST_DATA) begin
        tlp_data[31:0]      = rd_d_data;
        tlp_valid           = rd_d_valid;
        tlp_last            = rd_d_last;
        
        rd_d_ready          = tlp_ready;

        if(tlp_ready && rd_d_valid && rd_d_last) begin
            next_st             = ST_H0;
        end
    end

    if(st == ST_FLUSH_D) begin
        rd_d_ready          = 1'b1;
        if(rd_d_valid && rd_d_last) begin
            h_ready             = 1'b1;
            next_st             = h_last ? ST_H0 : ST_FLUSH_H;
        end
    end

    if(st == ST_FLUSH_H) begin
        if(h_valid) begin
            next_st             = ST_FLUSH_D;
        end
    end
end


endmodule


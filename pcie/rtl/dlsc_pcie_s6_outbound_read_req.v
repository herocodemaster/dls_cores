
module dlsc_pcie_s6_outbound_read_req #(
    parameter ADDR      = 32,
    parameter LEN       = 4
) (
    // ** System **

    input   wire                clk,
    input   wire                rst,


    // ** AXI **

    // Read Command
    output  wire                axi_ar_ready,
    input   wire                axi_ar_valid,
    input   wire    [ADDR-1:0]  axi_ar_addr,
    input   wire    [LEN-1:0]   axi_ar_len,
    

    // ** PCIe **

    // Config
    input   wire    [2:0]       max_read_request,   // 128, 256, 512, 1024, 2048, 4096

    // TLP header
    input   wire                tlp_h_ready,
    output  reg                 tlp_h_valid,
    output  reg     [ADDR-1:2]  tlp_h_addr,
    output  reg     [9:0]       tlp_h_len
);


// ** Buffer read command (AR) **

wire            axi_ar_ready_r;
wire            axi_ar_valid_r;
wire [ADDR-1:0] axi_ar_addr_r;
wire [LEN-1:0]  axi_ar_len_r;

dlsc_rvh_decoupler #(
    .WIDTH          ( ADDR + LEN )
) dlsc_rvh_decoupler_ar (
    .clk            ( clk ),
    .rst            ( rst ),
    .in_en          ( 1'b1 ),
    .in_ready       ( axi_ar_ready ),
    .in_valid       ( axi_ar_valid ),
    .in_data        ( { axi_ar_addr, axi_ar_len } ),
    .out_en         ( 1'b1 ),
    .out_ready      ( axi_ar_ready_r ),
    .out_valid      ( axi_ar_valid_r ),
    .out_data       ( { axi_ar_addr_r, axi_ar_len_r } )
);


// ** Merge commands **

reg             cmd_present     = 0;
reg  [ADDR-1:2] cmd_addr        = 0;
reg  [11:2]     cmd_addr_last   = 0;
reg  [10:0]     cmd_len         = 0;

reg  [ADDR-1:2] next_cmd_addr;
reg  [11:2]     next_cmd_addr_last;
reg  [10:0]     next_cmd_len;

always @* begin
    if(!cmd_present) begin
        next_cmd_addr       = axi_ar_addr_r[ADDR-1:2];
        next_cmd_addr_last  = { {(10-LEN){1'b0}}, axi_ar_len_r } + 10'd1 + axi_ar_addr_r[11:2];
        next_cmd_len        = { {(11-LEN){1'b0}}, axi_ar_len_r } + 11'd1;
    end else begin
        next_cmd_addr       = cmd_addr;
        next_cmd_addr_last  = { {(10-LEN){1'b0}}, axi_ar_len_r } + 10'd1 + cmd_addr_last;
        next_cmd_len        = { {(11-LEN){1'b0}}, axi_ar_len_r } + 11'd1 + cmd_len;
    end
end

wire            cmd_can_merge   = cmd_present && axi_ar_valid_r &&
                                    (axi_ar_addr_r[ADDR-1:12] == cmd_addr[ADDR-1:12]) &&
                                    (axi_ar_addr_r[11:2] == cmd_addr_last) && (cmd_addr_last != 0);

assign          axi_ar_ready_r  = !cmd_present || cmd_can_merge;

wire            cmd_ready;
wire            cmd_valid       = cmd_present && !cmd_can_merge;

always @(posedge clk) begin
    if(rst) begin
        cmd_present     <= 1'b0;
    end else begin
        if(cmd_ready && cmd_valid) begin
            cmd_present     <= 1'b0;
        end
        if(axi_ar_ready_r && axi_ar_valid_r) begin
            cmd_present     <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(axi_ar_ready_r && axi_ar_valid_r) begin
        cmd_addr        <= next_cmd_addr;
        cmd_addr_last   <= next_cmd_addr_last;
        cmd_len         <= next_cmd_len;
    end
end


// ** Split commands into TLPs **

// Get maximum length
reg  [10:0]  max_len            = 11'd32;

always @(posedge clk) begin
    case(max_read_request)
        3'b000:  max_len <= 11'd32;
        3'b001:  max_len <= 11'd64;
        3'b010:  max_len <= 11'd128;
        3'b011:  max_len <= 11'd256;
        3'b100:  max_len <= 11'd512;
        3'b101:  max_len <= 11'd1024;
        default: max_len <= 11'd32;
    endcase
end

// Split
reg             split_valid     = 0;
reg  [ADDR-1:2] split_addr      = 0;
reg  [10:0]     split_len       = 0;
reg             split_last      = 0;

reg  [ADDR-1:2] next_split_addr;
reg  [10:0]     next_split_len;
reg             next_split_last;

always @* begin
    if(!split_valid) begin
        next_split_addr     = cmd_addr;
        next_split_len      = cmd_len;
        next_split_last     = ({cmd_len,1'b0} <= {max_len,1'b0});
    end else begin
        next_split_addr     = { split_addr[ADDR-1:12], (split_addr[11:2] + max_len[9:0]) };
        next_split_len      = split_len - max_len;
        next_split_last     = ({1'b0,split_len} <= {max_len,1'b0});
    end
end

assign          cmd_ready       = !split_valid;

wire            split_ready;

always @(posedge clk) begin
    if(rst) begin
        split_valid     <= 1'b0;
    end else begin
        if(split_ready && split_last) begin
            split_valid     <= 1'b0;
        end
        if(cmd_ready && cmd_valid) begin
            split_valid     <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(!split_valid || split_ready) begin
        split_addr      <= next_split_addr;
        split_len       <= next_split_len;
        split_last      <= next_split_last;
    end
end

// TLP

assign          split_ready     = !tlp_h_valid;

always @(posedge clk) begin
    if(rst) begin
        tlp_h_valid     <= 1'b0;
    end else begin
        if(tlp_h_ready) begin
            tlp_h_valid     <= 1'b0;
        end
        if(split_ready && split_valid) begin
            tlp_h_valid     <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(split_ready && split_valid) begin
        tlp_h_addr      <= split_addr;
        tlp_h_len       <= split_last ? split_len[9:0] : max_len[9:0];
    end
end

endmodule


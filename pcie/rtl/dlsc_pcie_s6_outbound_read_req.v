
module dlsc_pcie_s6_outbound_read_req #(
    parameter ADDR      = 32,
    parameter LEN       = 4,
    parameter MAX_SIZE  = 128,
    parameter MERGING   = 1
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

// must be able to split requests if they exceed 128 bytes
localparam  SPLITTING   = (MERGING>0) || (((2**LEN)*4)>128);

/* verilator lint_off WIDTH */
localparam [10:0] MAX_SIZE_DW = (MAX_SIZE < 1024) ? (MAX_SIZE/4) : 11'd1024;
/* verilator lint_on WIDTH */


// ** Merge commands **

wire            cmd_ready;
wire            cmd_valid;

reg  [ADDR-1:2] cmd_addr        = 0;
reg  [10:0]     cmd_len         = 0;

generate
if(MERGING>0) begin:GEN_MERGE
    
    reg             cmd_present     = 1'b0;
    reg  [11:2]     cmd_addr_last   = 0;

    reg  [ADDR-1:2] next_cmd_addr;
    reg  [11:2]     next_cmd_addr_last;
    reg  [10:0]     next_cmd_len;

    always @* begin
        if(!cmd_present) begin
            next_cmd_addr       = axi_ar_addr[ADDR-1:2];
            next_cmd_addr_last  = { {(10-LEN){1'b0}}, axi_ar_len } + 10'd1 + axi_ar_addr[11:2];
            next_cmd_len        = { {(11-LEN){1'b0}}, axi_ar_len } + 11'd1;
        end else begin
            next_cmd_addr       = cmd_addr;
            next_cmd_addr_last  = { {(10-LEN){1'b0}}, axi_ar_len } + 10'd1 + cmd_addr_last;
            next_cmd_len        = { {(11-LEN){1'b0}}, axi_ar_len } + 11'd1 + cmd_len;
        end
    end

    wire            cmd_can_merge   = cmd_present && axi_ar_valid &&
                                        (axi_ar_addr[ADDR-1:12] == cmd_addr[ADDR-1:12]) &&
                                        (axi_ar_addr[11:2] == cmd_addr_last) && (cmd_addr_last != 0);

    assign          axi_ar_ready    = !cmd_present || cmd_can_merge;

    assign          cmd_valid       = cmd_present && !cmd_can_merge;

    always @(posedge clk) begin
        if(rst) begin
            cmd_present     <= 1'b0;
        end else begin
            if(cmd_ready && cmd_valid) begin
                cmd_present     <= 1'b0;
            end
            if(axi_ar_ready && axi_ar_valid) begin
                cmd_present     <= 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if(axi_ar_ready && axi_ar_valid) begin
            cmd_addr        <= next_cmd_addr;
            cmd_addr_last   <= next_cmd_addr_last;
            cmd_len         <= next_cmd_len;
        end
    end

end else begin:GEN_NOMERGE

    assign          axi_ar_ready    = cmd_ready;

    always @* begin
        cmd_valid       = axi_ar_valid;
        cmd_addr        = axi_ar_addr[ADDR-1:2];
        cmd_len         = {{(11-LEN){1'b0}},axi_ar_len} + 11'd1;
    end

end
endgenerate


// ** Split commands into TLPs **

// Get maximum length
reg  [10:0]  max_len            = 11'd32;

always @(posedge clk) begin
    case(max_read_request)
        3'b101:  max_len <= ((MAX_SIZE_DW >= 11'd1024) ? 11'd1024 : MAX_SIZE_DW);
        3'b100:  max_len <= ((MAX_SIZE_DW >= 11'd512 ) ? 11'd512  : MAX_SIZE_DW);
        3'b011:  max_len <= ((MAX_SIZE_DW >= 11'd256 ) ? 11'd256  : MAX_SIZE_DW);
        3'b010:  max_len <= ((MAX_SIZE_DW >= 11'd128 ) ? 11'd128  : MAX_SIZE_DW);
        3'b001:  max_len <= ((MAX_SIZE_DW >= 11'd64  ) ? 11'd64   : MAX_SIZE_DW);
        default: max_len <= ((MAX_SIZE_DW >= 11'd32  ) ? 11'd32   : MAX_SIZE_DW);
    endcase
end

// Split
wire            split_ready;
reg             split_valid     = 0;
reg  [ADDR-1:2] split_addr      = 0;
reg  [10:0]     split_len       = 0;
reg             split_last      = 1'b1;

generate
if(SPLITTING>0) begin:GEN_SPLIT

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

end else begin:GEN_NOSPLIT

    assign          cmd_ready       = split_ready;

    always @* begin
        split_valid     = cmd_valid;
        split_addr      = cmd_addr;
        split_len       = cmd_len;
        split_last      = 1'b1;
    end

end
endgenerate

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


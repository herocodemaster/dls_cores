
module dlsc_pcie_s6_outbound_read_req #(
    parameter ADDR          = 32,
    parameter LEN           = 4,
    parameter MAX_SIZE      = 128,
    parameter MERGING       = 1,
    parameter MERGE_WINDOW  = 4     // number of inactive cycles allowed between incoming mergeable commands
) (
    // ** System **

    input   wire                clk,
    input   wire                rst,


    // ** AXI **

    // Read Command
    output  wire                axi_ar_ready,
    input   wire                axi_ar_valid,
    input   wire    [ADDR-1:2]  axi_ar_addr,
    input   wire    [LEN-1:0]   axi_ar_len,
    

    // ** PCIe **

    // Config
    input   wire    [2:0]       max_read_request,   // 128, 256, 512, 1024, 2048, 4096

    // TLP header
    input   wire                tlp_h_ready,
    output  wire                tlp_h_valid,
    output  wire    [ADDR-1:2]  tlp_h_addr,
    output  wire    [9:0]       tlp_h_len
);

`include "dlsc_clog2.vh"

localparam  MWB         = (MERGE_WINDOW>1) ? `dlsc_clog2(MERGE_WINDOW) : 1;

// must be able to split requests if they exceed 128 bytes
localparam  SPLITTING   = (MERGING>0) || (((2**LEN)*4)>128);

/* verilator lint_off WIDTH */
localparam [10:0] MAX_SIZE_DW = (MAX_SIZE < 1024) ? (MAX_SIZE/4) : 11'd1024;
/* verilator lint_on WIDTH */


// ** Merge commands **

wire            cmd_ready;
wire            cmd_valid;

reg  [ADDR-1:2] cmd_addr;
reg  [9:0]      cmd_len;

generate
if(MERGING>0) begin:GEN_MERGE

    // merge_mask is used in order to tolerate some dead-time between merged commands.
    // (external AXI routing may result in commands not being delivered back-to-back)
    // each time a command is accepted, merge_mask asserts for MERGE_WINDOW cycles. during
    // these cycles, cmd_valid can only be asserted if a new non-mergeable command is presented.
    reg             cmd_merge_mask;
    reg  [MWB-1:0]  cmd_merge_window;

    reg             cmd_present;
    reg  [11:2]     cmd_addr_last;

    reg  [ADDR-1:2] next_cmd_addr;
    reg  [11:2]     next_cmd_addr_last;
    reg  [9:0]      next_cmd_len;

    always @* begin
        if(!cmd_present) begin
            next_cmd_addr       = axi_ar_addr[ADDR-1:2];
            next_cmd_addr_last  = { {(10-LEN){1'b0}}, axi_ar_len } + 10'd1 + axi_ar_addr[11:2];
            next_cmd_len        = { {(10-LEN){1'b0}}, axi_ar_len } + 10'd1;
        end else begin
            next_cmd_addr       = cmd_addr;
            next_cmd_addr_last  = { {(10-LEN){1'b0}}, axi_ar_len } + 10'd1 + cmd_addr_last;
            next_cmd_len        = { {(10-LEN){1'b0}}, axi_ar_len } + 10'd1 + cmd_len;
        end
    end

    wire            cmd_can_merge   = cmd_present && axi_ar_valid &&
                                        (axi_ar_addr[ADDR-1:12] == cmd_addr[ADDR-1:12]) &&
                                        (axi_ar_addr[11:2] == cmd_addr_last) && (cmd_addr_last != 0);

    assign          axi_ar_ready    = !cmd_present || cmd_can_merge;

    assign          cmd_valid       = cmd_present && !cmd_can_merge && (!cmd_merge_mask || axi_ar_valid);

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

/* verilator lint_off WIDTH */
    always @(posedge clk) begin
        if(rst) begin
            cmd_merge_mask  <= 1'b0;
            cmd_merge_window<= 0;
        end else begin
            if(cmd_merge_window == 0 || MERGE_WINDOW <= 1) begin
                cmd_merge_mask  <= 1'b0;
            end else begin
                cmd_merge_window<= cmd_merge_window - 1;
            end
            if(axi_ar_ready && axi_ar_valid && MERGE_WINDOW > 0) begin
                cmd_merge_mask  <= 1'b1;
                cmd_merge_window<= (MERGE_WINDOW-1);
            end
        end
    end
/* verilator lint_on WIDTH */

    always @(posedge clk) begin
        if(axi_ar_ready && axi_ar_valid) begin
            cmd_addr        <= next_cmd_addr;
            cmd_addr_last   <= next_cmd_addr_last;
            cmd_len         <= next_cmd_len;
        end
    end

end else begin:GEN_NOMERGE

    assign          axi_ar_ready    = cmd_ready;
    assign          cmd_valid       = axi_ar_valid;

    always @* begin
        cmd_addr        = axi_ar_addr[ADDR-1:2];
        cmd_len         = {{(10-LEN){1'b0}},axi_ar_len} + 10'd1;
    end

end
endgenerate


// ** Split commands into TLPs **

generate
if(SPLITTING>0) begin:GEN_SPLIT

    dlsc_pcie_s6_cmdsplit #(
        .ADDR       ( ADDR ),
        .LEN        ( 10 ),
        .OUT_SUB    ( 0 ),
        .MAX_SIZE   ( MAX_SIZE ),
        .ALIGN      ( 0 )
    ) dlsc_pcie_s6_cmdsplit_inst (
        .clk        ( clk ),
        .rst        ( rst ),
        .in_ready   ( cmd_ready ),
        .in_valid   ( cmd_valid ),
        .in_addr    ( cmd_addr ),
        .in_len     ( cmd_len ),
        .in_meta    ( 1'b0 ),
        .max_size   ( max_read_request),
        .out_ready  ( tlp_h_ready ),
        .out_valid  ( tlp_h_valid ),
        .out_addr   ( tlp_h_addr ),
        .out_len    ( tlp_h_len ),
        .out_meta   (  ),
        .out_last   (  )
    );

end else begin:GEN_NOSPLIT

    assign          cmd_ready       = tlp_h_ready;
    assign          tlp_h_valid     = cmd_valid;
    assign          tlp_h_addr      = cmd_addr;
    assign          tlp_h_len       = cmd_len;

end
endgenerate

endmodule


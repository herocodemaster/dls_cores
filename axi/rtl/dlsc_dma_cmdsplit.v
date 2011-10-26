
module dlsc_dma_cmdsplit #(
    parameter ADDR      = 30,
    parameter ILEN      = 30,   // bits for input command length (must be >= OLEN)
    parameter OLEN      = 4     // bits for output command length
) (
    // system
    input   wire                clk,
    input   wire                rst,

    // command input
    output  wire                in_ready,
    input   wire                in_valid,
    input   wire    [ADDR-1:0]  in_addr,
    input   wire    [ILEN-1:0]  in_len,

    // AXI output
    input   wire                out_ready,
    output  wire                out_valid,
    output  wire    [ADDR-1:0]  out_addr,
    output  wire    [OLEN  :0]  out_len,
    output  wire                out_last
);

wire            split_ready;
reg             split_valid;

assign          in_ready        = !split_valid;

reg  [ADDR-1:0] split_addr;
reg  [ILEN-1:0] split_len;
reg  [OLEN  :0] split_inc;
wire            split_last      = (split_len <= { {(ILEN-OLEN-1){1'b0}}, split_inc });

reg  [ADDR-1:0] next_split_addr;
reg  [ILEN-1:0] next_split_len;
reg  [OLEN  :0] next_split_inc;

always @* begin
    if(!split_valid) begin
        next_split_addr             = in_addr;
        next_split_len              = in_len;
        next_split_inc              = (2**OLEN) - { 1'b0, in_addr[OLEN-1:0] };
    end else begin
        next_split_addr             = 0;
        next_split_addr[ADDR-1:OLEN]= split_addr[ADDR-1:OLEN] + 1;
        next_split_len              = split_len - { {(ILEN-OLEN-1){1'b0}}, split_inc };
        next_split_inc              = (2**OLEN);
    end
end

always @(posedge clk) begin
    if(rst) begin
        split_valid     <= 1'b0;
    end else begin
        if(split_ready && split_last) begin
            split_valid     <= 1'b0;
        end
        if(in_ready && in_valid) begin
            split_valid     <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(!split_valid || split_ready) begin
        split_addr      <= next_split_addr;
        split_len       <= next_split_len;
        split_inc       <= next_split_inc;
    end
end

assign          split_ready     = out_ready;
assign          out_valid       = split_valid;
assign          out_addr        = split_addr;
assign          out_len         = split_last ? split_len[OLEN:0] : split_inc;
assign          out_last        = split_last;

endmodule



module dlsc_pcie_s6_outbound_write_cmdmerge #(
    parameter ADDR      = 32,
    parameter LEN       = 4,
    parameter MAX_SIZE  = 128                       // maximum write payload size
) (
    // system
    input   wire                clk,
    input   wire                rst,
    
    // command stream input
    output  wire                cmd_ready,
    input   wire                cmd_valid,
    input   wire    [ADDR-1:2]  cmd_addr,
    input   wire                cmd_addr_cont,      // cmd_addr is contiguous with previous command
    input   wire    [3:0]       cmd_strb,
    input   wire                cmd_last,           // last split command for a particular AW command

    // TLP header output
    input   wire                tlp_ready,
    output  wire                tlp_valid,
    output  reg     [ADDR-1:2]  tlp_addr,
    output  reg     [9:0]       tlp_len,
    output  reg     [3:0]       tlp_be_first,
    output  reg     [3:0]       tlp_be_last,
    
    // Config
    input   wire    [2:0]       max_payload_size    // 128, 256, 512, 1024, 2048, 4096 (must be <= MAX_SIZE)
);

reg             tlp_valid_i;

reg             tlp_len_one;
reg             tlp_len_max;

reg             tlp_cmd_last;

reg             next_tlp_len_max;

reg             tlp_can_merge;

always @* begin
    tlp_can_merge       = 1'b0;

    if(cmd_addr_cont && !tlp_len_max) begin
        if( (tlp_be_first == 4'hF || tlp_be_first == 4'hE || tlp_be_first == 4'hC || tlp_be_first == 4'h8) &&
            (cmd_strb     == 4'hF || cmd_strb     == 4'h7 || cmd_strb     == 4'h3 || cmd_strb     == 4'h1) &&
            (tlp_len_one || tlp_be_last == 4'hF) )
        begin
            // contiguous
            tlp_can_merge       = 1'b1;
        end

        if(tlp_be_first != 4'h0 && cmd_strb != 4'h0 && tlp_len_one && tlp_addr[2] == 1'b0) begin
            // special case: QW aligned write allows sparse strobes
            tlp_can_merge       = 1'b1;
        end
    end
end

assign          cmd_ready       = !tlp_valid_i || tlp_can_merge;

// we'll push when the next command can't be merged, or if the command path is throttling (but only on command boundaries)
assign          tlp_valid       = tlp_valid_i && ( cmd_valid ? !tlp_can_merge : tlp_cmd_last );

wire            tlp_update      = cmd_ready && cmd_valid;

always @(posedge clk) begin
    if(rst) begin
        tlp_valid_i     <= 1'b0;
    end else begin
        if(tlp_ready && tlp_valid) begin
            tlp_valid_i     <= 1'b0;
        end
        if(tlp_update) begin
            tlp_valid_i     <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(tlp_update) begin
        tlp_cmd_last    <= cmd_last;
        if(!tlp_valid_i) begin
            tlp_addr        <= cmd_addr;
            tlp_len         <= 1;
            tlp_len_one     <= 1'b1;
            tlp_len_max     <= 1'b0;
            tlp_be_first    <= cmd_strb;
            tlp_be_last     <= 4'h0;
        end else begin
//          tlp_addr        <= tlp_addr;
            tlp_len         <= tlp_len + 1;
            tlp_len_one     <= 1'b0;
            tlp_len_max     <= next_tlp_len_max;
//          tlp_be_first    <= tlp_be_first;
            tlp_be_last     <= cmd_strb;
        end
    end
end

always @* begin
    next_tlp_len_max    = 1'b0;
    if( (MAX_SIZE == 128  || max_payload_size == 3'b000) && (&tlp_len[4:0])) next_tlp_len_max = 1'b1;
    if( (MAX_SIZE == 256  || max_payload_size == 3'b001) && (&tlp_len[5:0])) next_tlp_len_max = 1'b1;
    if( (MAX_SIZE == 512  || max_payload_size == 3'b010) && (&tlp_len[6:0])) next_tlp_len_max = 1'b1;
    if( (MAX_SIZE == 1024 || max_payload_size == 3'b011) && (&tlp_len[7:0])) next_tlp_len_max = 1'b1;
    if( (MAX_SIZE == 2048 || max_payload_size == 3'b100) && (&tlp_len[8:0])) next_tlp_len_max = 1'b1;
    if( (MAX_SIZE == 4096 || max_payload_size == 3'b101) && (&tlp_len[9:0])) next_tlp_len_max = 1'b1;
end

endmodule


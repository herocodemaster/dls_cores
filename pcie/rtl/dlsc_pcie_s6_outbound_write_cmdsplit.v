
module dlsc_pcie_s6_outbound_write_cmdsplit #(
    parameter ADDR      = 32,
    parameter LEN       = 4
) (
    // system
    input   wire                clk,
    input   wire                rst,

    // AXI write command input
    output  wire                axi_aw_ready,
    input   wire                axi_aw_valid,
    input   wire    [ADDR-1:2]  axi_aw_addr,
    input   wire    [LEN-1:0]   axi_aw_len,

    // AXI write data input (strobes only)
    output  wire                axi_w_ready,
    input   wire                axi_w_valid,
    input   wire    [3:0]       axi_w_strb,

    // command stream output
    input   wire                cmd_ready,
    output  reg                 cmd_valid,
    output  reg     [ADDR-1:2]  cmd_addr,
    output  reg                 cmd_addr_cont,      // cmd_addr is contiguous with previous command
    output  reg     [3:0]       cmd_strb,
    output  reg                 cmd_last            // last split command for a particular AW command
);

reg  [ADDR-1:2] cmd_addr_p1;
reg  [LEN-1:0]  cmd_len;

reg  [ADDR-1:2] next_cmd_addr;
reg             next_cmd_addr_cont;
reg  [LEN-1:0]  next_cmd_len;
reg             next_cmd_last;

always @* begin
    if(cmd_last) begin
        next_cmd_addr       = axi_aw_addr[ADDR-1:2];
        next_cmd_addr_cont  = (axi_aw_addr[ADDR-1:2] == cmd_addr_p1) && (cmd_addr_p1[11:2] != 10'd0);
        next_cmd_len        = axi_aw_len;
        next_cmd_last       = (axi_aw_len == 0);
    end else begin
        next_cmd_addr       = cmd_addr_p1;
        next_cmd_addr_cont  = 1'b1;
        next_cmd_len        = cmd_len - 1;
        next_cmd_last       = (cmd_len == 1);
    end
end

wire            next_cmd_valid  = axi_w_valid && (!cmd_last || axi_aw_valid);

wire            cmd_update      = next_cmd_valid && (!cmd_valid || cmd_ready);

assign          axi_aw_ready    = cmd_update && cmd_last;
assign          axi_w_ready     = cmd_update;

always @(posedge clk) begin
    if(rst) begin
        cmd_valid       <= 1'b0;
    end else begin
        if(cmd_ready) begin
            cmd_valid       <= 1'b0;
        end
        if(cmd_update) begin
            cmd_valid       <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        cmd_last        <= 1'b1;
    end else if(cmd_update) begin
        cmd_last        <= next_cmd_last;
    end
end

always @(posedge clk) begin
    if(cmd_update) begin
        cmd_strb        <= axi_w_strb;
        cmd_addr        <= next_cmd_addr;
        cmd_addr_p1     <= { next_cmd_addr[ADDR-1:12], (next_cmd_addr[11:2] + 10'd1) };
        cmd_addr_cont   <= next_cmd_addr_cont;
        cmd_len         <= next_cmd_len;
    end
end

endmodule


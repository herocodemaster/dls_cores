
module dlsc_pcie_s6_cmdsplit #(
    parameter ADDR          = 32,
    parameter LEN           = 4,
    parameter OUT_SUB       = 0,
    parameter META          = 1
) (
    // System
    input   wire                clk,
    input   wire                rst,
    
    // Command input (to be split)
    output  wire                in_ready,
    input   wire                in_valid,
    input   wire    [ADDR-1:2]  in_addr,
    input   wire    [10:0]      in_len,
    input   wire    [META-1:0]  in_meta,

    // Split config
    input   wire    [10:0]      max_len,

    // Command output (after splitting)
    input   wire                out_ready,
    output  reg                 out_valid,
    output  reg     [ADDR-1:2]  out_addr,
    output  reg     [LEN-1:0]   out_len,
    output  reg     [META-1:0]  out_meta
);

// handshake
wire            split_ready     = (!out_valid || out_ready);
reg             split_valid     = 0;
assign          in_ready        = !split_valid;

// splitter state
reg  [ADDR-1:2] split_addr      = 0;
reg  [10:0]     split_len       = 0;
reg             split_last      = 1'b1;

// next state
reg  [ADDR-1:2] next_split_addr;
reg  [10:0]     next_split_len;
reg             next_split_last;

always @* begin
    if(!split_valid) begin
        next_split_addr     = in_addr;
        next_split_len      = in_len;
        next_split_last     = ({in_len,1'b0} <= {max_len,1'b0});
    end else begin
        next_split_addr     = { split_addr[ADDR-1:12], (split_addr[11:2] + max_len[9:0]) };
        next_split_len      = split_len - max_len;
        next_split_last     = ({1'b0,split_len} <= {max_len,1'b0});
    end
end

// track split state validity
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

// update splitter state
always @(posedge clk) begin
    if(!split_valid || split_ready) begin
        split_addr      <= next_split_addr;
        split_len       <= next_split_len;
        split_last      <= next_split_last;
    end
end

// capture metadata
reg  [META-1:0] split_meta      = 0;

always @(posedge clk) begin
    if(!split_valid) begin
        split_meta      <= in_meta;
    end
end

// drive valid
always @(posedge clk) begin
    if(rst) begin
        out_valid   <= 1'b0;
    end else begin
        if(out_ready) begin
            out_valid   <= 1'b0;
        end
        if(split_ready && split_valid) begin
            out_valid   <= 1'b1;
        end
    end
end

// drive output
always @(posedge clk) begin
    if(split_ready && split_valid) begin
        out_meta    <= split_meta;
        out_addr    <= split_addr;
        out_len     <= (split_last ? split_len[LEN-1:0] : max_len[LEN-1:0]) - OUT_SUB;
    end
end


endmodule


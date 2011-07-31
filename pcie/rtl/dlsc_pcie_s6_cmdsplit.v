
module dlsc_pcie_s6_cmdsplit #(
    parameter ADDR          = 32,   // MSB of address port (LSB is always 2)
    parameter LEN           = 10,   // width of output length (must be <= 10)
    parameter OUT_SUB       = 0,    // value to subtract from output length (e.g. for AXI, set to 1)
    parameter MAX_SIZE      = 128,  // maximum output length (regardless of max_size input); must be power-of-2 if ALIGN is set
    parameter ALIGN         = 0,    // if larger than max_size, align to max_size boundaries
    parameter META          = 1,    // width of metadata ports
    parameter REGISTER      = 1     // register outputs
) (
    // System
    input   wire                clk,
    input   wire                rst,
    
    // Command input (to be split)
    output  wire                in_ready,
    input   wire                in_valid,
    input   wire    [ADDR-1:2]  in_addr,
    input   wire    [9:0]       in_len,
    input   wire    [META-1:0]  in_meta,

    // Split config
    input   wire    [2:0]       max_size,   // 128,256,512,1024,2048,4096

    // Command output (after splitting)
    input   wire                out_ready,
    output  reg                 out_valid,
    output  reg     [ADDR-1:2]  out_addr,
    output  reg     [LEN-1:0]   out_len,
    output  reg     [META-1:0]  out_meta,
    output  reg                 out_last
);

/* verilator lint_off WIDTH */
localparam [10:0] MAX_SIZE_DW   = (MAX_SIZE < 4096) ? (MAX_SIZE/4) : 11'd1024;
localparam [9:0]  MAX_MASK      = (MAX_SIZE_DW-1);
/* verilator lint_on WIDTH */
    
// Get maximum length
reg  [9:0]  max_len;
reg         max_len_4k;

always @(posedge clk) begin
    case(max_size)
        3'b101:  {max_len_4k,max_len} <= ((MAX_SIZE_DW >= 11'd1024) ? 11'd1024 : MAX_SIZE_DW);
        3'b100:  {max_len_4k,max_len} <= ((MAX_SIZE_DW >= 11'd512 ) ? 11'd512  : MAX_SIZE_DW);
        3'b011:  {max_len_4k,max_len} <= ((MAX_SIZE_DW >= 11'd256 ) ? 11'd256  : MAX_SIZE_DW);
        3'b010:  {max_len_4k,max_len} <= ((MAX_SIZE_DW >= 11'd128 ) ? 11'd128  : MAX_SIZE_DW);
        3'b001:  {max_len_4k,max_len} <= ((MAX_SIZE_DW >= 11'd64  ) ? 11'd64   : MAX_SIZE_DW);
        default: {max_len_4k,max_len} <= ((MAX_SIZE_DW >= 11'd32  ) ? 11'd32   : MAX_SIZE_DW);
    endcase
end

// handshake
wire            split_ready;
reg             split_valid;
assign          in_ready        = !split_valid;

// splitter state
reg  [ADDR-1:2] split_addr;
reg  [9:0]      split_len;
reg  [9:0]      split_inc;
wire            split_last      = max_len_4k || (split_len != 0 && split_len <= max_len);

// next state
reg  [ADDR-1:2] next_split_addr;
reg  [9:0]      next_split_len;

always @* begin
    if(!split_valid) begin
        next_split_addr         = in_addr;
        next_split_len          = in_len;
    end else begin
        next_split_addr         = split_addr;
        next_split_addr[11:2]   = split_addr[11:2] + split_inc;
        next_split_len          = split_len        - split_inc;
    end
end

generate
if(ALIGN>0) begin:GEN_ALIGN
    // get mask
    reg  [9:0]  max_mask;
    always @(posedge clk) begin
        case(max_size)
            3'b101:  max_mask <= ((MAX_SIZE_DW >= 11'd1024) ? 10'h3FF : MAX_MASK);
            3'b100:  max_mask <= ((MAX_SIZE_DW >= 11'd512 ) ? 10'h1FF : MAX_MASK);
            3'b011:  max_mask <= ((MAX_SIZE_DW >= 11'd256 ) ? 10'h0FF : MAX_MASK);
            3'b010:  max_mask <= ((MAX_SIZE_DW >= 11'd128 ) ? 10'h07F : MAX_MASK);
            3'b001:  max_mask <= ((MAX_SIZE_DW >= 11'd64  ) ? 10'h03F : MAX_MASK);
            default: max_mask <= ((MAX_SIZE_DW >= 11'd32  ) ? 10'h01F : MAX_MASK);
        endcase
    end
    // determine amount to increment by
    reg  [9:0]      next_split_inc;
    always @* begin
        if(!split_valid) begin
            // first one may be unaligned; find length to first boundary
            next_split_inc  = max_len - (in_addr[11:2] & max_mask);
        end else begin
            // remaining ones are aligned
            next_split_inc  = max_len;
        end
    end
    always @(posedge clk) begin
        if(!split_valid || split_ready) begin
            split_inc       <= next_split_inc;
        end
    end
end else begin:GEN_NOALIGN
    always @* begin
        split_inc       = max_len;
    end
end
endgenerate


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
    end
end

// capture metadata
reg  [META-1:0] split_meta;

always @(posedge clk) begin
    if(!split_valid) begin
        split_meta      <= in_meta;
    end
end


wire [LEN-1:0]  next_out_len    = (split_last ? split_len[LEN-1:0] : split_inc[LEN-1:0]) - OUT_SUB;

generate
if(REGISTER>0) begin:GEN_REG

    assign          split_ready     = (!out_valid || out_ready);

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
            out_len     <= next_out_len;
            out_last    <= split_last;
        end
    end

end else begin:GEN_NOREG

    assign          split_ready     = out_ready;

    always @* begin
        out_valid   = split_valid;
        out_meta    = split_meta;
        out_addr    = split_addr;
        out_len     = next_out_len;
        out_last    = split_last;
    end

end
endgenerate

endmodule


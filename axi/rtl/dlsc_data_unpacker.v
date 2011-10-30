
module dlsc_data_unpacker #(
    parameter WLEN          = 12,   // bits for cmd_word field
    parameter WORDS_ZERO    = 0     // if set, cmd_word is words-1 (ie, it is 0 based)
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // Status/control
    output  reg                     cmd_done,

    // Command input
    output  wire                    cmd_ready,
    input   wire                    cmd_valid,
    input   wire    [1:0]           cmd_offset,     // offset to 1st byte of 1st word
    input   wire    [1:0]           cmd_bpw,        // bytes per word
    input   wire    [WLEN-1:0]      cmd_words,      // number of words to unpack

    // Data input (packed)
    output  wire                    in_ready,
    input   wire                    in_valid,
    input   wire    [31:0]          in_data,

    // Data output (unpacked)
    input   wire                    out_ready,
    output  reg                     out_valid,
    output  reg                     out_last,
    output  reg     [31:0]          out_data
);

wire            set_out_valid;
reg             set_in_ready;

// track command

reg             c_valid;
reg             c_init;
reg             c_last;
reg  [WLEN-1:0] c_words;
reg  [1:0]      c_bpw;
reg  [3:0]      c_mask;
wire            c_ready         = c_last && set_out_valid;

assign          cmd_ready       = !c_valid;

always @(posedge clk) begin
    if(rst) begin
        c_valid     <= 1'b0;
        cmd_done    <= 1'b0;
    end else begin
        c_valid     <= (c_valid && !c_ready) || (cmd_ready && cmd_valid);
        cmd_done    <= c_valid && c_ready;
    end
end

always @(posedge clk) begin
    if(in_ready && in_valid) begin
        c_init      <= 1'b0;
    end
    if(set_out_valid && !c_last) begin
        c_last      <= WORDS_ZERO ? (c_words == 1) : (c_words == 2);
        c_words     <= c_words - 1;
    end
    if(cmd_ready && cmd_valid) begin
        c_init      <= (cmd_offset != 2'd0);    // non-zero offset means we need to fetch an extra word of input data before driving outputs
        c_last      <= WORDS_ZERO ? (cmd_words == 0) : (cmd_words == 1);
        c_words     <= cmd_words;
        c_bpw       <= cmd_bpw;
        case(cmd_bpw)
            2'd0: c_mask <= 4'b0001;
            2'd1: c_mask <= 4'b0011;
            2'd2: c_mask <= 4'b0111;
            2'd3: c_mask <= 4'b1111;
        endcase
    end
end

// track buffer

reg  [1:0]      buf_cnt;
reg  [31:8]     buf_data;

reg  [1:0]      next_buf_cnt;

always @(posedge clk) begin
    buf_cnt     <= next_buf_cnt;
    if(in_ready && in_valid) begin
        buf_data    <= in_data[31:8];
    end
end

always @* begin
    next_buf_cnt    = buf_cnt;
    set_in_ready    = 1'b0;

    if(c_valid) begin
        if(set_out_valid) begin
            // output driven; buffer data consumed
            next_buf_cnt    = buf_cnt - c_bpw - 2'd1;
        end
        if(!c_last || c_init) begin
            // must assert set_in_ready if we'll exhaust the buffer on the next cycle
            set_in_ready    = (next_buf_cnt <= c_bpw);
        end
    end

    if(cmd_ready && cmd_valid) begin
        // loading command; need to initialize buffer count and fetch 1st input
        set_in_ready    = 1'b1;
        case(cmd_offset)
            2'd0: next_buf_cnt = 2'd0;
            2'd1: next_buf_cnt = 2'd3;
            2'd2: next_buf_cnt = 2'd2;
            2'd3: next_buf_cnt = 2'd1;
        endcase
    end

end

// handshake input

reg             in_ready_pre;
assign          in_ready        = in_ready_pre && (out_ready || !out_valid);

always @(posedge clk) begin
    if(rst) begin
        in_ready_pre    <= 1'b0;
    end else begin
        if(in_ready && in_valid) begin
            in_ready_pre    <= 1'b0;
        end
        if(set_in_ready) begin
            in_ready_pre    <= 1'b1;
        end
    end
end

// handshake output

assign set_out_valid = c_valid && !c_init && (out_ready || !out_valid) && (!in_ready_pre || in_valid);

// mux output

reg  [31:0]     out_data_mux;

always @* begin
    case(buf_cnt[1:0])
        2'd0:    out_data_mux =   in_data[31:0];
        2'd1:    out_data_mux = { in_data[23:0], buf_data[31:24] };
        2'd2:    out_data_mux = { in_data[15:0], buf_data[31:16] };
        2'd3:    out_data_mux = { in_data[ 7:0], buf_data[31: 8] };
    endcase
end

// drive output

always @(posedge clk) begin
    if(rst) begin
        out_valid   <= 1'b0;
    end else begin
        out_valid   <= (out_valid && !out_ready) || set_out_valid;
    end
end

always @(posedge clk) begin
    if(set_out_valid) begin
        out_last    <= c_last;
        out_data    <= out_data_mux & { {8{c_mask[3]}},
                                        {8{c_mask[2]}},
                                        {8{c_mask[1]}},
                                        {8{c_mask[0]}} };
    end
end

endmodule


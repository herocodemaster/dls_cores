
module dlsc_data_packer #(
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
    input   wire    [1:0]           cmd_offset,     // offset to 1st byte of 1st output word
    input   wire    [1:0]           cmd_bpw,        // bytes per input word
    input   wire    [WLEN-1:0]      cmd_words,      // number of input words to pack

    // Data input (unpacked)
    output  wire                    in_ready,
    input   wire                    in_valid,
    input   wire    [31:0]          in_data,

    // Data output (packed)
    input   wire                    out_ready,
    output  reg                     out_valid,
    output  reg                     out_last,
    output  reg     [31:0]          out_data,
    output  reg     [3:0]           out_strb
);

reg             buf_rem;        // internal buffer has one last beat of data
wire            update;
reg             next_out_valid;


// track command

reg             c_valid;
reg             c_last;
reg  [WLEN-1:0] c_words;
reg  [1:0]      c_offset;
reg  [1:0]      c_bpw;
reg  [3:0]      c_strb;

wire            c_ready         = (in_ready && in_valid && c_last);

// c_* registers shouldn't be overwritten until buf_rem is cleared
assign          cmd_ready       = !c_valid && !buf_rem;

always @(posedge clk) begin
    if(rst) begin
        c_valid     <= 1'b0;
        cmd_done    <= 1'b0;
    end else begin
        c_valid     <= (c_valid && !c_ready) || (cmd_ready && cmd_valid);
        cmd_done    <= (out_ready && out_valid && out_last);
    end
end

always @(posedge clk) begin
    if(in_ready && in_valid && !c_last) begin
        c_last      <= WORDS_ZERO ? (c_words == 1) : (c_words == 2);
        c_words     <= c_words - 1;
        c_offset    <= c_offset + c_bpw + 2'd1;
    end
    if(update && next_out_valid) begin
        // reset strobes after 1st output beat
        c_strb      <= 4'b1111;
    end
    if(cmd_ready && cmd_valid) begin
        c_last      <= WORDS_ZERO ? (cmd_words == 0) : (cmd_words == 1);
        c_words     <= cmd_words;
        c_offset    <= cmd_offset;
        c_bpw       <= cmd_bpw;
        case(cmd_offset)
            2'd0: c_strb <= 4'b1111;
            2'd1: c_strb <= 4'b1110;
            2'd2: c_strb <= 4'b1100;
            2'd3: c_strb <= 4'b1000;
        endcase
    end
end


// handshake

assign          in_ready        = c_valid && (out_ready || !out_valid);

assign          update          = (out_ready || !out_valid) && ((c_valid && in_valid) || buf_rem);


// control

reg             next_out_last;
reg             next_buf_rem;

always @* begin
    next_out_valid  = 1'b0;
    next_out_last   = 1'b0;
    next_buf_rem    = 1'b0;

    if(c_valid && c_last) begin

        next_out_valid  = 1'b1;

        // last input beat may leave a remainder in the buffer;
        // an extra output beat will be required to finish in this case
        case(c_offset)
            2'd0: next_buf_rem = 1'b0;
            2'd1: next_buf_rem = (c_bpw == 2'd3);
            2'd2: next_buf_rem = (c_bpw >= 2'd2);
            2'd3: next_buf_rem = (c_bpw >= 2'd1);
        endcase

        // can only be last output beat if there is no remainder
        if(!next_buf_rem) begin
            next_out_last   = 1'b1;
        end

    end else begin

        if(buf_rem) begin
            // force last output on remainder
            next_out_valid  = 1'b1;
            next_out_last   = 1'b1;
        end else begin
            // can drive the output when the input overruns the buffer
            case(c_offset)
                2'd0: next_out_valid = (c_bpw == 2'd3);
                2'd1: next_out_valid = (c_bpw >= 2'd2);
                2'd2: next_out_valid = (c_bpw >= 2'd1);
                2'd3: next_out_valid = 1'b1;
            endcase
        end

    end
end


// buffer data

reg  [23:0]     buf_data;
reg  [23:0]     next_buf_data;

always @* begin
    next_buf_data   = {24{1'bx}};
    
    case( {next_out_valid,c_offset} )

        // output being driven (consuming some/all of input); capture remainder of input
        {1'b1,2'd0}: next_buf_data = {         24'd0                 };
        {1'b1,2'd1}: next_buf_data = {         16'd0, in_data[31:24] };
        {1'b1,2'd2}: next_buf_data = {          8'd0, in_data[31:16] };
        {1'b1,2'd3}: next_buf_data = {                in_data[31: 8] };

        // just filling buffer; capture all of input (not used for 4 bytes per word)
        {1'b0,2'd0}: next_buf_data = { in_data[23:0]                 }; // only used for <= 3 bytes per word
        {1'b0,2'd1}: next_buf_data = { in_data[15:0], buf_data[ 7:0] }; // only used for <= 2 bytes per word
        {1'b0,2'd2}: next_buf_data = { in_data[ 7:0], buf_data[15:0] }; // only used for    1 byte  per word

        // shouldn't happen
        default: next_buf_data = {24{1'bx}};

    endcase

end

always @(posedge clk) begin
    if(update) begin
        buf_data    <= next_buf_data;
    end
end


// output data

reg  [31:0]     next_out_data;

always @* begin
    next_out_data   = {32{1'bx}};
    case(c_offset)
        2'd0: next_out_data = { in_data[31:0]                 };
        2'd1: next_out_data = { in_data[23:0], buf_data[ 7:0] };
        2'd2: next_out_data = { in_data[15:0], buf_data[15:0] };
        2'd3: next_out_data = { in_data[ 7:0], buf_data[23:0] };
    endcase
end


// output strobes

reg  [3:0]      next_out_strb_mask;
reg  [3:0]      next_out_strb;

always @* begin

    // strobes for last output beat
    // (only meaningful when next_out_last is asserted)
    case( {buf_rem,c_bpw,c_offset} )

        // ** not remainder **
        // 1 byte per word
        { 1'b0, 2'd0, 2'd0 }: next_out_strb_mask = 4'b0001;
        { 1'b0, 2'd0, 2'd1 }: next_out_strb_mask = 4'b0011;
        { 1'b0, 2'd0, 2'd2 }: next_out_strb_mask = 4'b0111;
        { 1'b0, 2'd0, 2'd3 }: next_out_strb_mask = 4'b1111;
        // 2 bytes per word
        { 1'b0, 2'd1, 2'd0 }: next_out_strb_mask = 4'b0011;
        { 1'b0, 2'd1, 2'd1 }: next_out_strb_mask = 4'b0111;
        { 1'b0, 2'd1, 2'd2 }: next_out_strb_mask = 4'b1111;
        // 3 bytes per word
        { 1'b0, 2'd2, 2'd0 }: next_out_strb_mask = 4'b0111;
        { 1'b0, 2'd2, 2'd1 }: next_out_strb_mask = 4'b1111;
        // 4 bytes per word
        { 1'b0, 2'd3, 2'd0 }: next_out_strb_mask = 4'b1111;

        // ** remainder **
        // 1 byte per word
        // (can't have a remainder)
        // 2 bytes per word
        { 1'b1, 2'd1, 2'd3 }: next_out_strb_mask = 4'b0001;
        // 3 bytes per word
        { 1'b1, 2'd2, 2'd2 }: next_out_strb_mask = 4'b0001;
        { 1'b1, 2'd2, 2'd3 }: next_out_strb_mask = 4'b0011;
        // 4 bytes per word
        { 1'b1, 2'd3, 2'd1 }: next_out_strb_mask = 4'b0001;
        { 1'b1, 2'd3, 2'd2 }: next_out_strb_mask = 4'b0011;
        { 1'b1, 2'd3, 2'd3 }: next_out_strb_mask = 4'b0111;

        // unspecified cases shouldn't happen
        default: next_out_strb_mask = 4'bxxxx;
    endcase

    next_out_strb   = next_out_last ? (c_strb & next_out_strb_mask) : c_strb;

end


// registers

always @(posedge clk) begin
    if(rst) begin
        buf_rem     <= 1'b0;
        out_valid   <= 1'b0;
        out_last    <= 1'b0;
    end else begin
        if(out_ready) begin
            out_valid   <= 1'b0;
            out_last    <= 1'b0;
        end
        if(update) begin
            buf_rem     <= next_buf_rem;
        end
        if(update && next_out_valid) begin
            out_valid   <= 1'b1;
            out_last    <= next_out_last;
        end
    end
end

always @(posedge clk) begin
    if(update && next_out_valid) begin
        out_data    <= next_out_data & { {8{next_out_strb[3]}},
                                         {8{next_out_strb[2]}},
                                         {8{next_out_strb[1]}},
                                         {8{next_out_strb[0]}} };
        out_strb    <= next_out_strb;
    end
end


endmodule



module dlsc_pixel_unpacker #(
    parameter PLEN      = 12,       // bits for command pixel-length field
    parameter BPP       = 24,       // bits per pixel (8,16,24 or 32)
    parameter FAST      = 0         // enable back-to-back commands (required for completely uninterrupted pixel output)
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // Status/control
    output  reg                     cmd_done,

    // Command input
    output  wire                    cmd_ready,
    input   wire                    cmd_valid,
    input   wire    [1:0]           cmd_offset,     // offset to 1st byte of 1st pixel
    input   wire    [PLEN-1:0]      cmd_pixels,     // number of pixels to process

    // Data input
    output  wire                    in_ready,
    input   wire                    in_valid,
    input   wire    [31:0]          in_data,

    // Pixel output
    input   wire                    out_ready,
    output  reg                     out_valid,
    output  reg                     out_last,
    output  reg     [BPP-1:0]       out_data
);

// handshake output

reg             set_out_valid;

reg             next_last;

always @(posedge clk) begin
    if(rst) begin
        out_valid   <= 1'b0;
        out_last    <= 1'b0;
        cmd_done    <= 1'b0;
    end else begin
        cmd_done    <= 1'b0;
        if(out_ready) begin
            out_valid   <= 1'b0;
            out_last    <= 1'b0;
        end
        if(set_out_valid) begin
            out_valid   <= 1'b1;
            out_last    <= next_last;
            cmd_done    <= next_last;
        end
    end
end


// register command and track pixel count

wire            c_ready         = (set_out_valid && next_last);
reg             c_valid;
reg  [1:0]      c_offset;
reg  [PLEN-1:0] c_pixels;

assign          cmd_ready       = !c_valid || (FAST && c_ready);

always @(posedge clk) begin
    if(rst) begin
        c_valid     <= 1'b0;
    end else begin
        c_valid     <= (c_valid && !c_ready) || (cmd_ready && cmd_valid);
    end
end

always @(posedge clk) begin
    if(set_out_valid && !next_last) begin
        c_pixels    <= c_pixels - 1;
        next_last   <= (c_pixels == 2);
    end
    if(cmd_ready && cmd_valid) begin
        c_offset    <= cmd_offset;
        c_pixels    <= cmd_pixels;
        next_last   <= (cmd_pixels == 1);
    end
end


// unpack pixels

generate

if(BPP==8) begin:GEN_BPP_8

    reg  [1:0]      pxst;

    always @(posedge clk) begin
        if(set_out_valid) begin
            pxst    <= pxst + 1;
        end
        if(cmd_ready && cmd_valid) begin
            pxst    <= cmd_offset[1:0];
        end
    end

    always @* begin
        set_out_valid = (out_ready || !out_valid) && c_valid && in_valid;
    end

    // pop input on last pixel of word
    assign          in_ready        = set_out_valid && (pxst == 2'd3 || next_last);

    always @(posedge clk) begin
        if(set_out_valid) begin
            case(pxst)
                2'd0: out_data <= in_data[ 7: 0];
                2'd1: out_data <= in_data[15: 8];
                2'd2: out_data <= in_data[23:16];
                2'd3: out_data <= in_data[31:24];
            endcase
        end
    end

end else if(BPP==16) begin:GEN_BPP_16

    reg             pxst;

    always @(posedge clk) begin
        if(set_out_valid) begin
            pxst    <= pxst + 1;
        end
        if(cmd_ready && cmd_valid) begin
            pxst    <= cmd_offset[1];
        end
    end

    always @* begin
        set_out_valid = (out_ready || !out_valid) && c_valid && in_valid;
    end

    // pop input on last pixel of word
    assign          in_ready        = set_out_valid && (pxst == 1'b1 || next_last);

    always @(posedge clk) begin
        if(set_out_valid) begin
            case(pxst)
                1'b0: out_data <= in_data[15: 0];
                1'b1: out_data <= in_data[31:16];
            endcase
        end
    end

end else if(BPP==32) begin:GEN_BPP_32

    // the ridiculously easy case (1:1)
    
    always @* begin
        set_out_valid = (out_ready || !out_valid) && c_valid && in_valid;
    end

    assign          in_ready        = set_out_valid;

    always @(posedge clk) begin
        if(set_out_valid) begin
            out_data    <= in_data;
        end
    end

end else if(BPP==24) begin:GEN_BPP_24

    // the "hard" case

    // pixel alignment scenarios:
    //
    //      [31:24] [23:16] [15: 8] [ 7: 0]
    // 0:   p1[0]   p0[2]   p0[1]   p0[0]
    // 1:   p2[1]   p2[0]   p1[2]   p1[1]
    // 2:   p3[2]   p3[1]   p3[0]   p2[2]
    //

    reg  [1:0]      pxst;
    reg             pxst_adv;

    reg             first;

    always @(posedge clk) begin
        if(pxst_adv) begin
            // advance state
            pxst    <= pxst + 1;
            first   <= 1'b0;
        end
        if(cmd_ready && cmd_valid) begin
            first   <= 1'b1;
            // capture initial state on command load
            case(cmd_offset)
                2'b00: pxst <= 2'd0;    // 1st valid pixel in data[23: 0] (state 0 drives)
                2'b01: pxst <= 2'd2;    // 1st valid pixel in data[31: 8] (state 2 captures; 3 drives)
                2'b10: pxst <= 2'd1;    // 1st valid pixel in {next_data[15:0], data[31:16]} (state 1 & 2 capture; 2 drives)
                2'b11: pxst <= 2'd0;    // 1st valid pixel in {next_data[23:0], data[31:24]} (state 0 & 1 capture; 1 drives)
            endcase
        end
    end

    assign          in_ready        = (out_ready || !out_valid) && c_valid && (pxst != 2'd3);

    always @* begin
        pxst_adv        = 1'b0;
        set_out_valid   = 1'b0;
        if(in_ready && in_valid) begin
            pxst_adv        = 1'b1;
            if(pxst == 2'd0) begin
                set_out_valid   = !first || (c_offset == 2'b00);
            end
            if(pxst == 2'd1) begin
                set_out_valid   = !first;
            end
            if(pxst == 2'd2) begin
                set_out_valid   = !first;
            end
        end
        if(out_ready || !out_valid) begin
            if(pxst == 2'd3) begin
                pxst_adv        = 1'b1;
                set_out_valid   = c_valid;
            end
        end
    end

    reg  [31:0]     in_data_prev;

    always @(posedge clk) begin
        if(in_ready && in_valid) begin
            in_data_prev    <= in_data;
            if(pxst == 2'd0) begin
                out_data[23:16] <= in_data     [23:16];
                out_data[15: 8] <= in_data     [15: 8];
                out_data[ 7: 0] <= in_data     [ 7: 0];
            end
            if(pxst == 2'd1) begin
                out_data[23:16] <= in_data     [15: 8];
                out_data[15: 8] <= in_data     [ 7: 0];
                out_data[ 7: 0] <= in_data_prev[31:24];
            end
            if(pxst == 2'd2) begin
                out_data[23:16] <= in_data     [ 7: 0];
                out_data[15: 8] <= in_data_prev[31:24];
                out_data[ 7: 0] <= in_data_prev[23:16];
            end
        end
        if(out_ready || !out_valid) begin
            if(pxst == 2'd3) begin
                out_data[23:16] <= in_data_prev[31:24];
                out_data[15: 8] <= in_data_prev[23:16];
                out_data[ 7: 0] <= in_data_prev[15: 8];
            end
        end
    end
end

endgenerate


// simulation checks

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

initial begin
    if( !(BPP==8||BPP==16||BPP==24||BPP==32) ) begin
        `dlsc_error("BPP must be 8, 16, 24 or 32");
    end
end

always @(posedge clk) if(!rst) begin

    if(cmd_ready && cmd_valid) begin
        if(cmd_pixels == 0) begin
            `dlsc_error("cmd_pixels must be >= 1");
        end
        if(BPP==16 && cmd_offset[0] != 1'b0) begin
            `dlsc_error("cmd_offset must be aligned to BPP (16-bit) boundary");
        end
        if(BPP==32 && cmd_offset[1:0] != 2'b00) begin
            `dlsc_error("cmd_offset must be aligned to BPP (32-bit) boundary");
        end
    end

end

`include "dlsc_sim_bot.vh"
`endif

endmodule


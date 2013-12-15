// 
// Copyright (c) 2013, Daniel Strother < http://danstrother.com/ >
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//   - Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//   - Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//   - The name of the author may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

// Module Description:
// A full-featured asynchronous FIFO.

module dlsc_fifo_async_full #(
    parameter WR_CYCLES     = 1,    // max input rate
    parameter RD_CYCLES     = 1,    // max output rate
    parameter WR_PIPELINE   = 0,    // delay from wr_push to wr_data being valid (0 or 1)
    parameter RD_PIPELINE   = 0,    // delay from rd_pop to rd_data being valid (0 or 1)
    parameter DATA          = 8,    // width of data in FIFO
    parameter ADDR          = 4,    // depth of FIFO is 2**ADDR; width of free/count ports is ADDR+1
    parameter ALMOST_FULL   = 0,    // assert almost_full when <= ALMOST_FULL free spaces remain (0 makes it equivalent to full)
    parameter ALMOST_EMPTY  = 0,    // assert almost_empty when <= ALMOST_EMPTY valid entries remain (0 makes it equivalent to empty)
    parameter FREE          = 0,    // enable wr_free port
    parameter COUNT         = 0,    // enable rd_count port
    // use block RAMs (instead of LUTs)
    parameter BRAM          = (ADDR > 6) && (((2**ADDR)*DATA) > 1024)
) (
    // ** write domain **

    input   wire                wr_clk,
    input   wire                wr_rst,

    output  wire                wr_full,
    input   wire                wr_push,
    input   wire    [DATA-1:0]  wr_data,

    output  wire                wr_almost_full,
    output  wire    [ADDR  :0]  wr_free,
    
    // ** read domain **

    // output
    input   wire                rd_clk,
    input   wire                rd_rst,

    input   wire                rd_pop,
    output  wire                rd_empty,
    output  wire    [DATA-1:0]  rd_data,

    output  wire                rd_almost_empty,
    output  wire    [ADDR  :0]  rd_count
);

`include "dlsc_util.vh"
`include "dlsc_synthesis.vh"

genvar j;

localparam DEPTH = (2**ADDR);

`dlsc_static_assert_range(WR_PIPELINE,0,1)
`dlsc_static_assert_range(RD_PIPELINE,0,1)

`dlsc_static_assert_range(ALMOST_FULL,0,DEPTH-1)
`dlsc_static_assert_range(ALMOST_EMPTY,0,DEPTH-1)

localparam [ADDR:0] MSB = {1'b1,{ADDR{1'b0}}};

localparam WR_SLOW      = (WR_CYCLES>1);
localparam RD_SLOW      = (RD_CYCLES>1);

localparam WR_NEED_P1   = !WR_SLOW;
localparam RD_NEED_P1   = !RD_SLOW || (BRAM && RD_PIPELINE==0);

// ** memory **

// limit fanout to 4 slices
localparam LUT_SLICE_WIDTH  = (ADDR <= 5) ? (4*6) : // 6 bits per slice (RAM32X6SDP)
                              (ADDR <= 6) ? (4*3) : // 3 bits per slice (RAM64X3SDP)
                                            (4*1);  // 1 bit  per slice (RAM128X1D)

localparam LUT_SLICES       = (DATA+LUT_SLICE_WIDTH-1)/LUT_SLICE_WIDTH;

`DLSC_FANOUT_REG reg             wr_push_r;
`DLSC_FANOUT_REG reg  [ADDR  :0] wr_addr_r;
`DLSC_PIPE_REG   reg  [DATA-1:0] wr_data_r;
    
`DLSC_PIPE_REG   reg  [ADDR  :0] rd_addr;
`DLSC_PIPE_REG   reg  [ADDR  :0] rd_addr_p1;

generate
if(!BRAM) begin:GEN_LUTRAM
    if(RD_PIPELINE==0) begin:GEN_PIPE0

        `DLSC_LUTRAM    reg [DATA-1:0] mem[DEPTH-1:0];

        always @(posedge wr_clk) begin
            if(wr_push_r) begin
                mem[wr_addr_r[ADDR-1:0]] <= wr_data_r;
            end
        end
        
        assign rd_data = mem[rd_addr[ADDR-1:0]];

    end else if(RD_PIPELINE==1 && LUT_SLICES<=1) begin:GEN_PIPE1_NO_FAN

        `DLSC_LUTRAM    reg [DATA-1:0] mem[DEPTH-1:0];

        always @(posedge wr_clk) begin
            if(wr_push_r) begin
                mem[wr_addr_r[ADDR-1:0]] <= wr_data_r;
            end
        end

        `DLSC_PIPE_REG  reg [DATA-1:0] rd_data_r;

        always @(posedge rd_clk) begin
            rd_data_r <= mem[rd_addr[ADDR-1:0]];
        end

        assign rd_data = rd_data_r;

    end else if(RD_PIPELINE==1) begin:GEN_PIPE1_FAN

        `define lut_slice_width ((j<(LUT_SLICES-1)) ? (LUT_SLICE_WIDTH) : (DATA - ((LUT_SLICES-1)*LUT_SLICE_WIDTH)))

        for(j=0;j<LUT_SLICES;j=j+1) begin:GEN_SLICES

            `DLSC_LUTRAM reg [`lut_slice_width-1:0] mem[DEPTH-1:0];

            always @(posedge wr_clk) begin
                if(wr_push_r) begin
                    mem[wr_addr_r[ADDR-1:0]] <= wr_data_r[ j*LUT_SLICE_WIDTH +: `lut_slice_width ];
                end
            end

            `DLSC_PIPE_REG reg [ADDR-1:0] rd_addr_r;

            always @(posedge rd_clk) begin
                rd_addr_r <= rd_addr[ADDR-1:0];
            end

            assign rd_data[ j*LUT_SLICE_WIDTH +: `lut_slice_width ] = mem[rd_addr_r];

        end

        `undef lut_slice_width

    end

end else begin:GEN_BRAM

    wire [ADDR-1:0] bram_rd_addr;
    
    if(RD_PIPELINE==0) begin:GEN_RD_PIPELINE0

        assign bram_rd_addr = rd_pop ? rd_addr_p1[ADDR-1:0] : rd_addr[ADDR-1:0];

    end else if(RD_PIPELINE==1) begin:GEN_RD_PIPELINE1

        assign bram_rd_addr = rd_addr[ADDR-1:0];

    end

    dlsc_ram_dp #(
        .DATA           ( DATA ),
        .ADDR           ( ADDR ),
        .PIPELINE_WR    ( 0 ),
        .PIPELINE_RD    ( 1 ),
        .WARNINGS       ( 0 )
    ) dlsc_ram_dp_inst (
        .write_clk      ( wr_clk ),
        .write_en       ( wr_push_r ),
        .write_addr     ( wr_addr_r[ADDR-1:0] ),
        .write_data     ( wr_data_r ),
        .read_clk       ( rd_clk ),
        .read_en        ( 1'b1 ),
        .read_addr      ( bram_rd_addr ),
        .read_data      ( rd_data )
    );

end
endgenerate


// ** input / write **

// rd_addr synced to wr domain
`DLSC_PIPE_REG  reg  [ADDR  :0] wr_rd_addr;

// write address
`DLSC_PIPE_REG  reg  [ADDR  :0] wr_addr_p1;
`DLSC_PIPE_REG  reg  [ADDR  :0] wr_addr;

always @(posedge wr_clk) begin
    if(wr_rst) begin
        wr_addr     <= 0;
        wr_addr_p1  <= 1;
    end else if(wr_push) begin
        if(WR_NEED_P1) begin
            wr_addr     <= wr_addr_p1;
            wr_addr_p1  <= wr_addr_p1 + 1;
        end else begin
            wr_addr     <= wr_addr + 1;
        end
    end
end

// re-register write signals for fanout control
always @(posedge wr_clk) begin
    wr_push_r   <= wr_push;
    wr_addr_r   <= wr_addr;
end

generate
if(WR_PIPELINE==0) begin:GEN_WR_PIPELINE0

    always @(posedge wr_clk) begin
        wr_data_r <= wr_data;
    end

end else if(WR_PIPELINE==1) begin:GEN_WR_PIPELINE1

    always @* begin
        wr_data_r = wr_data;
    end

end
endgenerate

// full

`DLSC_PIPE_REG reg wr_full_r;

always @(posedge wr_clk) begin
    if(wr_rst) begin
        // full in reset
        wr_full_r <= 1'b1;
    end else begin
        if(!WR_SLOW) begin
            wr_full_r <= wr_rd_addr == (wr_push ? wr_addr_p1 : wr_addr);
        end else begin
            wr_full_r <= wr_push ? 1'b1 : (wr_rd_addr == wr_addr);
        end
    end
end

assign wr_full = wr_full_r;

// free

generate
if(!FREE) begin:GEN_NO_FREE

    assign wr_free = {(ADDR+1){1'bx}};

end else begin:GEN_FREE
    
    `DLSC_PIPE_REG reg [ADDR:0] wr_free_r;

    always @(posedge wr_clk) begin
        if(wr_rst) begin
            // full in reset
            wr_free_r <= 0;
        end else begin
            wr_free_r <= wr_rd_addr - wr_addr - { {ADDR{1'b0}}, wr_push };
        end
    end
    
    assign wr_free = wr_free_r;

end
endgenerate

// almost full

generate
if(ALMOST_FULL==0) begin:GEN_ALMOST_FULL_0

    assign wr_almost_full = wr_full;

end else begin:GEN_ALMOST_FULL

    `DLSC_PIPE_REG reg [ADDR:0] wr_adaf;

    always @(posedge wr_clk) begin
        if(wr_rst) begin
            /* verilator lint_off WIDTH */
            wr_adaf <= ALMOST_FULL+1;
            /* verilator lint_on WIDTH */
        end else if(wr_push) begin
            wr_adaf <= wr_adaf + 1;
        end
    end

    wire [ADDR  :0] wr_adaf_free        = wr_rd_addr - wr_adaf - { {ADDR{1'b0}}, wr_push };
    wire            wr_almost_full_next = wr_adaf_free[ADDR]; // almost full if result is negative

    `DLSC_PIPE_REG reg wr_almost_full_r;

    always @(posedge wr_clk) begin
        if(wr_rst) begin
            wr_almost_full_r <= 1'b1; // full in reset
        end else begin
            wr_almost_full_r <= wr_almost_full_next;
        end
    end
    
    assign wr_almost_full = wr_almost_full_r;

end
endgenerate

// to gray

`DLSC_PIPE_REG  reg  [ADDR  :0] wr_addr_gray;
                wire [ADDR  :0] wr_addr_gray_next;

dlsc_bin2gray #(ADDR+1) dlsc_bin2gray_wr (wr_addr,wr_addr_gray_next);

always @(posedge wr_clk) begin
    if(wr_rst) begin
        wr_addr_gray    <= 0;
    end else begin
        wr_addr_gray    <= wr_addr_gray_next;
    end
end

// from gray

wire [ADDR  :0] wr_rd_addr_gray;
wire [ADDR  :0] wr_rd_addr_next;

dlsc_gray2bin #(ADDR+1) dlsc_gray2bin_wr (wr_rd_addr_gray,wr_rd_addr_next);

always @(posedge wr_clk) begin
    if(wr_rst) begin
        wr_rd_addr      <= MSB;
    end else begin
        wr_rd_addr      <= wr_rd_addr_next^MSB;
    end
end


// ** output / read **

// wr_addr synced to rd domain
`DLSC_PIPE_REG  reg  [ADDR  :0] rd_wr_addr;

// read address

always @(posedge rd_clk) begin
    if(rd_rst) begin
        rd_addr     <= 0;
        rd_addr_p1  <= 1;
    end else if(rd_pop) begin
        if(RD_NEED_P1) begin
            rd_addr     <= rd_addr_p1;
            rd_addr_p1  <= rd_addr_p1 + 1;
        end else begin
            rd_addr     <= rd_addr + 1;
        end
    end
end

// empty

`DLSC_PIPE_REG reg rd_empty_r;

always @(posedge rd_clk) begin
    if(rd_rst) begin
        // empty in reset
        rd_empty_r <= 1'b1;
    end else begin
        if(!RD_SLOW) begin
            rd_empty_r <= rd_wr_addr == (rd_pop ? rd_addr_p1 : rd_addr);
        end else begin
            rd_empty_r <= rd_pop ? 1'b1 : (rd_wr_addr == rd_addr);
        end
    end
end

assign rd_empty = rd_empty_r;

// count

generate
if(!COUNT) begin:GEN_NO_COUNT

    assign rd_count = {(ADDR+1){1'bx}};

end else begin:GEN_COUNT

    `DLSC_PIPE_REG reg [ADDR:0] rd_count_r;

    always @(posedge rd_clk) begin
        if(rd_rst) begin
            // empty in reset
            rd_count_r <= 0;
        end else begin
            rd_count_r <= rd_wr_addr - rd_addr - { {ADDR{1'b0}}, rd_pop };
        end
    end

    assign rd_count = rd_count_r;

end
endgenerate

// almost empty

generate
if(ALMOST_EMPTY==0) begin:GEN_ALMOST_EMPTY_0

    assign rd_almost_empty = rd_empty;

end else begin:GEN_ALMOST_EMPTY

    `DLSC_PIPE_REG reg [ADDR:0] rd_adae;

    always @(posedge rd_clk) begin
        if(rd_rst) begin
            /* verilator lint_off WIDTH */
            rd_adae <= ALMOST_EMPTY+1;
            /* verilator lint_on WIDTH */
        end else if(rd_pop) begin
            rd_adae <= rd_adae + 1;
        end
    end

    wire [ADDR  :0] rd_adae_free        = rd_wr_addr - rd_adae - { {ADDR{1'b0}}, rd_pop };
    wire            rd_almost_empty_next= rd_adae_free[ADDR]; // almost empty if result is negative

    `DLSC_PIPE_REG reg rd_almost_empty_r;

    always @(posedge rd_clk) begin
        if(rd_rst) begin
            rd_almost_empty_r <= 1'b1; // empty in reset
        end else begin
            rd_almost_empty_r <= rd_almost_empty_next;
        end
    end
    
    assign rd_almost_empty = rd_almost_empty_r;

end
endgenerate

// to gray

`DLSC_PIPE_REG  reg  [ADDR  :0] rd_addr_gray;
                wire [ADDR  :0] rd_addr_gray_next;

dlsc_bin2gray #(ADDR+1) dlsc_bin2gray_rd (rd_addr,rd_addr_gray_next);

always @(posedge rd_clk) begin
    if(rd_rst) begin
        rd_addr_gray <= 0;
    end else begin
        rd_addr_gray <= rd_addr_gray_next;
    end
end

// from gray

wire [ADDR  :0] rd_wr_addr_gray;
wire [ADDR  :0] rd_wr_addr_next;

dlsc_gray2bin #(ADDR+1) dlsc_gray2bin_rd (rd_wr_addr_gray,rd_wr_addr_next);

always @(posedge rd_clk) begin
    if(rd_rst) begin
        rd_wr_addr <= 0;
    end else begin
        rd_wr_addr <= rd_wr_addr_next;
    end
end


// ** sync **

dlsc_syncflop #(
    .DATA       ( ADDR+1 ),
    .RESET      ( {(ADDR+1){1'b0}} )
) dlsc_syncflop_wr (
    .in         ( rd_addr_gray ),
    .clk        ( wr_clk ),
    .rst        ( wr_rst ),
    .out        ( wr_rd_addr_gray )
);

dlsc_syncflop #(
    .DATA       ( ADDR+1 ),
    .RESET      ( {(ADDR+1){1'b0}} )
) dlsc_syncflop_rd (
    .in         ( wr_addr_gray ),
    .clk        ( rd_clk ),
    .rst        ( rd_rst ),
    .out        ( rd_wr_addr_gray )
);

endmodule


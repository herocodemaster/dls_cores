module dlsc_stereobm_frontend #(
    parameter DATA          = 24,
    parameter IMG_WIDTH     = 384,
    parameter IMG_HEIGHT    = 32,
    parameter DISP_BITS     = 6,
    parameter DISPARITIES   = (2**DISP_BITS),
    parameter SAD           = 17,
    parameter TEXTURE       = 1,                // texture filtering
    parameter TEXTURE_CONST = ((2**DATA)-2)/2,  // ftzero for texture filtering
    parameter MULT_D        = 4,                // DISPARITIES must be integer multiple of MULT_D
    parameter MULT_R        = 4,
    parameter PIPELINE_WR   = 0,    // enable pipeline register on BRAM write path (needed by Virtex-6 and sometimes Spartan-6)
    // derived parameters; don't touch
    parameter SAD_R         = (SAD+MULT_R-1),
    parameter DATA_R        = (DATA*MULT_R)
) (
    input   wire                        clk,
    input   wire                        rst,

    // input image data
    output  wire                        in_ready,
    input   wire                        in_valid,
    input   wire    [DATA_R-1:0]        in_left,
    input   wire    [DATA_R-1:0]        in_right,

    // pipeline output
    output  wire                        out_right_valid,    // asserts one cycle before out_right is valid
    output  wire                        out_valid,          // asserts one cycle before out_left is valid
    output  wire                        out_first,
    output  wire    [(DATA*SAD_R)-1:0]  out_left,
    output  wire    [(DATA*SAD_R)-1:0]  out_right,

    // backend control
    input   wire                        back_busy,
    output  wire                        back_valid,         // asserts one cycle before back_left/right are valid
    output  wire    [DATA_R-1:0]        back_left,
    output  wire    [DATA_R-1:0]        back_right
);
    
genvar j;

`include "dlsc_clog2.vh"
localparam ADDR = `dlsc_clog2(IMG_WIDTH);


// ** pipeline control **
wire    [ADDR-1:0]      c0_addr_left;
wire    [ADDR-1:0]      c0_addr_right;
wire                    c0_read_en;
wire                    c0_write_en;
wire    [DATA_R-1:0]    c0_in_left;
wire    [DATA_R-1:0]    c0_in_right;
wire                    c0_pipe_right_valid;
wire                    c0_pipe_valid;
wire                    c0_pipe_first;
wire                    c0_pipe_text;
wire                    c0_back_valid;

dlsc_stereobm_frontend_control #(
    .IMG_WIDTH      ( IMG_WIDTH ),
    .IMG_HEIGHT     ( IMG_HEIGHT ),
    .DISP_BITS      ( DISP_BITS ),
    .DISPARITIES    ( DISPARITIES ),
    .TEXTURE        ( TEXTURE ),
    .MULT_D         ( MULT_D ),
    .MULT_R         ( MULT_R ),
    .SAD            ( SAD ),
    .DATA           ( DATA ),
    .ADDR           ( ADDR )
) dlsc_stereobm_frontend_control_inst (
    .clk                ( clk ),
    .rst                ( rst ),
    .in_ready           ( in_ready ),
    .in_valid           ( in_valid ),
    .in_left            ( in_left ),
    .in_right           ( in_right ),
    .addr_left          ( c0_addr_left ),
    .addr_right         ( c0_addr_right ),
    .buf_read           ( c0_read_en ),
    .buf_write          ( c0_write_en ),
    .buf_left           ( c0_in_left ),
    .buf_right          ( c0_in_right ),
    .pipe_right_valid   ( c0_pipe_right_valid ),
    .pipe_valid         ( c0_pipe_valid ),
    .pipe_first         ( c0_pipe_first ),
    .pipe_text          ( c0_pipe_text ),
    .back_busy          ( back_busy ),
    .back_valid         ( c0_back_valid )
);


// ** register pipeline outputs **

// _valid signals are delayed by 1 less, so they assert one cycle
// before their associated data; this allows for re-registering in
// consumer modules and improves timing (by reducing fanout)
dlsc_pipedelay_rst #(
    .DATA       ( 3 ),
    .DELAY      ( 3 ),
    .RESET      ( 3'b000 )
) dlsc_pipedelay_rst_inst_pipe_valid (
    .clk        ( clk ),
    .rst        ( rst ),
    .in_data    ( { c0_back_valid, c0_pipe_right_valid, c0_pipe_valid } ),
    .out_data   ( {    back_valid,     out_right_valid,     out_valid } )
);

// pipe_first is qualified by pipe_valid, and thus requires no reset
dlsc_pipedelay #(
    .DATA       ( 1 ),
    .DELAY      ( 4 )
) dlsc_pipedelay_inst_pipe_first (
    .clk        ( clk ),
    .in_data    ( c0_pipe_first ),
    .out_data   (     out_first )
);


// ** RAM signals **

// outputs of read port (after 3 cycles of pipelining)
wire [(DATA*SAD_R)-1:0] c3_data_left;
wire [(DATA*SAD_R)-1:0] c3_data_right;

// delay inputs to write port of RAM
wire [DATA_R-1:0] c3_in_left;
wire [DATA_R-1:0] c3_in_right;

dlsc_pipedelay #(
    .DATA       ( DATA_R ),
    .DELAY      ( 3  )
) dlsc_pipedelay_inst_inleft (
    .clk        ( clk ),
    .in_data    ( c0_in_left ),
    .out_data   ( c3_in_left )
);

dlsc_pipedelay #(
    .DATA       ( DATA_R ),
    .DELAY      ( 3  )
) dlsc_pipedelay_inst_inright (
    .clk        ( clk ),
    .in_data    ( c0_in_right ),
    .out_data   ( c3_in_right )
);

wire [(DATA*SAD_R)-1:0] c3_write_left  = { c3_in_left,  c3_data_left [ DATA_R +: (DATA*SAD_R)-DATA_R ] };
wire [(DATA*SAD_R)-1:0] c3_write_right = { c3_in_right, c3_data_right[ DATA_R +: (DATA*SAD_R)-DATA_R ] };


// register pipeline data outputs
dlsc_pipereg #(
    .DATA       ( DATA*SAD_R ),
    .PIPELINE   ( 1 )
) dlsc_pipereg_inst_out_left (
    .clk        ( clk ),
    .in_data    ( c3_data_left ),
    .out_data   (     out_left )
);

generate
    if(TEXTURE == 0) begin:GEN_NOTEXTURE

        dlsc_pipereg #(
            .DATA       ( DATA*SAD_R ),
            .PIPELINE   ( 1 )
        ) dlsc_pipereg_inst_out_right (
            .clk        ( clk ),
            .in_data    ( c3_data_right ),
            .out_data   (     out_right )
        );

    end else begin:GEN_TEXTURE

        // texture filtering is a lot like normal SAD, except that the right pixels
        // are fixed at TEXTURE_CONST. this logic handles that.

        wire c3_pipe_text;
        dlsc_pipedelay #(
            .DATA       ( 1 ),
            .DELAY      ( 3 )
        ) dlsc_pipedelay_inst_pipe_text (
            .clk        ( clk ),
            .in_data    ( c0_pipe_text ),
            .out_data   ( c3_pipe_text )
        );

        reg [(DATA*SAD_R)-1:0] c4_data_right;

        /* verilator lint_off WIDTH */
        wire [DATA-1:0] texture_const = TEXTURE_CONST;
        /* verilator lint_on WIDTH */

        always @(posedge clk) begin
            if(c3_pipe_text) begin
                c4_data_right   <= {SAD_R{texture_const}};
            end else begin
                c4_data_right   <= c3_data_right;
            end
        end

        assign out_right = c4_data_right;

    end // GEN_TEXTURE
endgenerate


// send pixels from middle of SAD window to backend
dlsc_pipereg #(
    .DATA       ( DATA_R ),
    .PIPELINE   ( 1 )
) dlsc_pipereg_inst_back_left (
    .clk        ( clk ),
    .in_data    ( c3_data_left [ ((SAD/2)*DATA) +: DATA_R ] ),
    .out_data   (    back_left )
);

dlsc_pipereg #(
    .DATA       ( DATA_R ),
    .PIPELINE   ( 1 )
) dlsc_pipereg_inst_back_right (
    .clk        ( clk ),
    .in_data    ( c3_data_right[ ((SAD/2)*DATA) +: DATA_R ] ),
    .out_data   (    back_right )
);


// ** row buffer memories **

dlsc_ram_dp #(
    .DATA               ( DATA*SAD_R ),
    .ADDR               ( ADDR ),
    .DEPTH              ( IMG_WIDTH ),
    .PIPELINE_WR        ( PIPELINE_WR ? 4 : 3 ),    // delay write_en/addr to match write_data
    .PIPELINE_WR_DATA   ( PIPELINE_WR ? 1 : 0 ),
    .PIPELINE_RD        ( 3 )
) dlsc_ram_dp_left_inst (
    .write_clk      ( clk ),
    .write_en       ( c0_write_en ),
    .write_addr     ( c0_addr_left ),
    .write_data     ( c3_write_left ),
    .read_clk       ( clk ),
    .read_en        ( c0_read_en ),
    .read_addr      ( c0_addr_left),
    .read_data      ( c3_data_left )
);

dlsc_ram_dp #(
    .DATA               ( DATA*SAD_R ),
    .ADDR               ( ADDR ),
    .DEPTH              ( IMG_WIDTH ),
    .PIPELINE_WR        ( PIPELINE_WR ? 4 : 3 ),    // delay write_en/addr to match write_data
    .PIPELINE_WR_DATA   ( PIPELINE_WR ? 1 : 0 ),
    .PIPELINE_RD        ( 3 )
) dlsc_ram_dp_right_inst (
    .write_clk      ( clk ),
    .write_en       ( c0_write_en ),
    .write_addr     ( c0_addr_right ),
    .write_data     ( c3_write_right ),
    .read_clk       ( clk ),
    .read_en        ( c0_read_en ),
    .read_addr      ( c0_addr_right),
    .read_data      ( c3_data_right )
);


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"
integer in_valid_cnt;
integer in_ready_cnt;
always @(posedge clk) begin
    if(rst) begin
        in_valid_cnt    <= 0;
        in_ready_cnt    <= 0;
    end else if(in_ready) begin // (ready/valid swapped so we can evaluate amount of time frontend is waiting for valid data)
        in_valid_cnt    <= in_valid_cnt + 1;
        if(in_valid) begin
            in_ready_cnt    <= in_ready_cnt + 1;
        end
    end
end

task report;
begin
    `dlsc_info("input efficiency: %0d%% (%0d/%0d)",((in_ready_cnt*100)/in_valid_cnt),in_ready_cnt,in_valid_cnt);
end
endtask
`include "dlsc_sim_bot.vh"
`endif


`ifdef DLSC_SIMULATION
wire [DATA-1:0] dbg_in_left    [MULT_R-1:0];
wire [DATA-1:0] dbg_in_right   [MULT_R-1:0];
wire [DATA-1:0] dbg_back_left  [MULT_R-1:0];
wire [DATA-1:0] dbg_back_right [MULT_R-1:0];
wire [DATA-1:0] dbg_out_left   [SAD_R-1:0];
wire [DATA-1:0] dbg_out_right  [SAD_R-1:0];

generate
    genvar dbg;
    for(dbg=0;dbg<MULT_R;dbg=dbg+1) begin:GEN_DBG_INBACK
        assign dbg_in_left[dbg]     = in_left[(dbg*DATA)+:DATA];
        assign dbg_in_right[dbg]    = in_right[(dbg*DATA)+:DATA];
        assign dbg_back_left[dbg]   = back_left[(dbg*DATA)+:DATA];
        assign dbg_back_right[dbg]  = back_right[(dbg*DATA)+:DATA];
    end
    for(dbg=0;dbg<SAD_R;dbg=dbg+1) begin:GEN_DBG_OUT
        assign dbg_out_left[dbg]    = out_left[(dbg*DATA)+:DATA];
        assign dbg_out_right[dbg]   = out_right[(dbg*DATA)+:DATA];
    end
endgenerate
`endif


endmodule


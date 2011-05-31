module dlsc_stereobm_disparity_slice #(
    parameter DISP_BITS     = 6,
    parameter TEXTURE       = 0,
    parameter SUB_BITS      = 0,
    parameter UNIQUE_MUL    = 0,
    parameter MULT_D        = 1,
    parameter SAD_BITS      = 16,
    parameter PIPELINE_RD   = 0,
    parameter PIPELINE_LUT4 = 0,
    // derived; don't touch
    parameter LOHI_EN       = (SUB_BITS>0||UNIQUE_MUL>0),
    parameter SAD_BITS_D    = MULT_D*SAD_BITS,
    parameter BUF_BITS      = DISP_BITS + (1 + (LOHI_EN>0?3:0) + (UNIQUE_MUL>0?1:0)) * SAD_BITS
) (
    // system
    input   wire                        clk,
    input   wire                        rst,

    // inputs from controller
    input   wire    [DISP_BITS  -1:0]   cm_ctrl_disp,           // cycle cm-1 (one cycle before cm0)
    input   wire    [DISP_BITS  -1:0]   c3_ctrl_disp_prev,      // previous pass's base disparity
    input   wire                        c3_ctrl_first,
    input   wire                        c3_ctrl_last,

    // inputs from pipeline
    input   wire    [ SAD_BITS_D-1:0]   c0_pipe_sad,

    // input from buffer
    input   wire    [ BUF_BITS  -1:0]   c3_buf_data,

    // output to buffer
    output  wire    [ BUF_BITS  -1:0]   cw_buf_data,

    // outputs to post-processing
    output  wire    [DISP_BITS  -1:0]   cw_out_disp,
    output  wire    [ SAD_BITS  -1:0]   cw_out_sad,
    // outputs to post-processing in sub-pixel mode
    output  wire    [ SAD_BITS  -1:0]   cw_out_lo,
    output  wire    [ SAD_BITS  -1:0]   cw_out_hi,
    // outputs to post-processing in uniqueness mode
    output  wire    [ SAD_BITS  -1:0]   cw_out_thresh,
    // outputs for texture filtering
    output  wire                        cw_out_filtered
);

`include "dlsc_synthesis.vh"
`include "dlsc_clog2.vh"

localparam MULT_D_BITS  = `dlsc_clog2(MULT_D);
localparam MULT_D1_BITS = `dlsc_clog2(MULT_D+1);
localparam MULT_D3_BITS = `dlsc_clog2(MULT_D+3);

localparam CYCLE_C4 = (PIPELINE_RD>0?4:3);
localparam CYCLE_C5 = CYCLE_C4 + 1;

// cycle at output of main sorter
localparam CYCLE_CM0 = CYCLE_C5 + 2 + (MULT_D1_BITS-1) * (PIPELINE_LUT4>0?2:1);
localparam CYCLE_CM1 = CYCLE_CM0 + 1;
localparam CYCLE_CM2 = CYCLE_CM1 + (PIPELINE_LUT4>0?1:0);

// cycle at output of threshold sorter
localparam CYCLE_CT0 = CYCLE_CM2 + 2 + (MULT_D3_BITS-1) * (PIPELINE_LUT4>0?2:1);

// cycle at output of this block
localparam CYCLE_CW = UNIQUE_MUL>0 ? CYCLE_CT0 : CYCLE_CM1;

genvar j;
genvar k;


// ** re-register control signals **
`DLSC_PIPE_REG reg [DISP_BITS-1:0] cm0_ctrl_disp;
`DLSC_PIPE_REG reg [DISP_BITS-1:0] c4_ctrl_disp_prev;
`DLSC_PIPE_REG reg                 c4_ctrl_first;
`DLSC_PIPE_REG reg                 c4_ctrl_last;
always @(posedge clk) begin
    cm0_ctrl_disp       <= cm_ctrl_disp;
    c4_ctrl_disp_prev   <= c3_ctrl_disp_prev;
    c4_ctrl_first       <= c3_ctrl_first;
    c4_ctrl_last        <= c3_ctrl_last;
end


// ** connections to buffer **

// inputs from buffer
wire [DISP_BITS-1:0] c3_buf_disp;
wire [ SAD_BITS-1:0] c3_buf_sad;
// sub-pixel mode
wire [ SAD_BITS-1:0] c3_buf_lo;
wire [ SAD_BITS-1:0] c3_buf_hi;
wire [ SAD_BITS-1:0] c3_buf_next_hi;
// uniqueness mode
wire [ SAD_BITS-1:0] c3_buf_thresh;

// outputs to buffer (most come from cw_out_* ports above)
wire [ SAD_BITS-1:0] cw_out_next_hi;

generate
    if( LOHI_EN == 0 && UNIQUE_MUL == 0 ) begin:GEN_BUF_NOSUB_NOUNIQUE

        assign {
            c3_buf_disp,
            c3_buf_sad }        = c3_buf_data;
        assign c3_buf_lo        = {SAD_BITS{1'b1}};
        assign c3_buf_hi        = {SAD_BITS{1'b1}};
        assign c3_buf_next_hi   = {SAD_BITS{1'b1}};
        assign c3_buf_thresh    = {SAD_BITS{1'b1}};

        assign cw_buf_data = {
            cw_out_disp,
            cw_out_sad };

    end else if( LOHI_EN > 0 && UNIQUE_MUL == 0 ) begin:GEN_BUF_SUB_NOUNIQUE
        
        assign {
            c3_buf_disp,
            c3_buf_sad,
            c3_buf_lo,
            c3_buf_hi,
            c3_buf_next_hi }    = c3_buf_data;
        assign c3_buf_thresh    = {SAD_BITS{1'b1}};
        
        assign cw_buf_data = {
            cw_out_disp,
            cw_out_sad,
            cw_out_lo,
            cw_out_hi,
            cw_out_next_hi };

    end else begin:GEN_BUF_SUB_UNIQUE
        
        assign {
            c3_buf_disp,
            c3_buf_sad,
            c3_buf_lo,
            c3_buf_hi,
            c3_buf_next_hi,
            c3_buf_thresh }     = c3_buf_data;
        
        assign cw_buf_data = {
            cw_out_disp,
            cw_out_sad,
            cw_out_lo,
            cw_out_hi,
            cw_out_next_hi,
            cw_out_thresh };

    end
endgenerate


// ** pipeline buffer inputs **

// inputs from buffer
wire [DISP_BITS-1:0] c4_buf_disp;
wire [ SAD_BITS-1:0] c4_buf_sad;
// sub-pixel mode
wire [ SAD_BITS-1:0] c4_buf_lo;
wire [ SAD_BITS-1:0] c4_buf_hi;
wire [ SAD_BITS-1:0] c4_buf_next_hi;
// uniqueness mode
wire [ SAD_BITS-1:0] c4_buf_thresh;

dlsc_pipereg #(
    .DATA       ( DISP_BITS ),
    .PIPELINE   ( PIPELINE_RD )
) dlsc_pipereg_inst_c4_buf_disp (
    .clk        ( clk ),
    .in_data    ( c3_buf_disp ),
    .out_data   ( c4_buf_disp )
);

dlsc_pipereg #(
    .DATA       ( SAD_BITS ),
    .PIPELINE   ( PIPELINE_RD )
) dlsc_pipereg_inst_c4_buf_sad (
    .clk        ( clk ),
    .in_data    ( c3_buf_sad ),
    .out_data   ( c4_buf_sad )
);

dlsc_pipereg #(
    .DATA       ( SAD_BITS ),
    .PIPELINE   ( PIPELINE_RD )
) dlsc_pipereg_inst_c4_buf_lo (
    .clk        ( clk ),
    .in_data    ( c3_buf_lo ),
    .out_data   ( c4_buf_lo )
);

dlsc_pipereg #(
    .DATA       ( SAD_BITS ),
    .PIPELINE   ( PIPELINE_RD )
) dlsc_pipereg_inst_c4_buf_hi (
    .clk        ( clk ),
    .in_data    ( c3_buf_hi ),
    .out_data   ( c4_buf_hi )
);

dlsc_pipereg #(
    .DATA       ( SAD_BITS ),
    .PIPELINE   ( PIPELINE_RD )
) dlsc_pipereg_inst_c4_buf_next_hi (
    .clk        ( clk ),
    .in_data    ( c3_buf_next_hi ),
    .out_data   ( c4_buf_next_hi )
);

dlsc_pipereg #(
    .DATA       ( SAD_BITS ),
    .PIPELINE   ( PIPELINE_RD )
) dlsc_pipereg_inst_c4_buf_thres (
    .clk        ( clk ),
    .in_data    ( c3_buf_thresh ),
    .out_data   ( c4_buf_thresh )
);


// ** input delay **

// c0_pipe_sad to c4_pipe_sad
wire [ SAD_BITS_D-1:0] c4_pipe_sad;
wire [ SAD_BITS  -1:0] c4_pipe_prev_lo = c4_pipe_sad[ ((MULT_D-1)*SAD_BITS) +: SAD_BITS ];
dlsc_pipedelay #(
    .DATA       ( SAD_BITS_D ),
    .DELAY      ( CYCLE_C4 )
) dlsc_pipedelay_inst_c4_pipe_sad (
    .clk        ( clk ),
    .in_data    ( c0_pipe_sad ),
    .out_data   ( c4_pipe_sad )
);

// c4_pipe_sad to c5_pipe_sad
reg  [ SAD_BITS_D-1:0] c5_pipe_sad;


// ** texture filtering **

generate
    if(TEXTURE == 0) begin:GEN_NOTEXTURE

        always @(posedge clk) begin
            c5_pipe_sad <= c4_pipe_sad;
        end

        assign cw_out_filtered = 1'b0;

    end else begin:GEN_TEXTURE
        
        always @(posedge clk) begin
            if(c4_ctrl_last) begin
                // mask pipe data on texture filtering pass
                // (to force comparators to favor buffer data)
                c5_pipe_sad <= {SAD_BITS_D{1'b1}};
            end else begin
                c5_pipe_sad <= c4_pipe_sad;
            end
        end

        // read texture from lowest (0) disparity
        wire [SAD_BITS-1:0] c4_pipe_text = c4_pipe_sad[ 0 +: SAD_BITS ];

        // compare against TEXTURE threshold
        reg c5_filtered;
        always @(posedge clk) begin
            if(c4_ctrl_last) begin
                c5_filtered <= (c4_pipe_text < TEXTURE);
            end
        end

        // delay to output
        dlsc_pipedelay #(
            .DATA       ( 1 ),
            .DELAY      ( CYCLE_CW - CYCLE_C5  )
        ) dlsc_pipedelay_inst_cw_out_filtered (
            .clk        ( clk ),
            .in_data    ( c5_filtered ),
            .out_data   ( cw_out_filtered )
        );

    end
endgenerate


// ** mask buffer on first pass **

// inputs from buffer
`DLSC_NO_SHREG reg  [DISP_BITS-1:0] c5_buf_disp    = {DISP_BITS{1'b0}};
`DLSC_NO_SHREG reg  [ SAD_BITS-1:0] c5_buf_sad     = { SAD_BITS{1'b1}};
// sub-pixel mode
`DLSC_NO_SHREG reg  [ SAD_BITS-1:0] c5_buf_lo      = { SAD_BITS{1'b1}};
`DLSC_NO_SHREG reg  [ SAD_BITS-1:0] c5_buf_hi      = { SAD_BITS{1'b1}};
`DLSC_NO_SHREG reg  [ SAD_BITS-1:0] c5_buf_next_hi = { SAD_BITS{1'b1}};
// uniqueness mode
`DLSC_NO_SHREG reg  [ SAD_BITS-1:0] c5_buf_thresh  = { SAD_BITS{1'b1}};
`DLSC_NO_SHREG reg                  c5_buf_adj     = 1'b0;

always @(posedge clk) begin
    if(c4_ctrl_first) begin
        c5_buf_disp     <= {DISP_BITS{1'b0}};
        c5_buf_sad      <= { SAD_BITS{1'b1}};
    end else begin
        c5_buf_disp     <= c4_buf_disp;
        c5_buf_sad      <= c4_buf_sad;
    end
end

generate
    if(LOHI_EN>0) begin:GEN_C5_SUB
        always @(posedge clk) begin
            if(c4_ctrl_first) begin
                c5_buf_lo       <= { SAD_BITS{1'b1}};
                c5_buf_hi       <= { SAD_BITS{1'b1}};
                c5_buf_next_hi  <= { SAD_BITS{1'b1}};
            end else begin
                c5_buf_lo       <= (c4_buf_disp == c4_ctrl_disp_prev) ? c4_pipe_prev_lo : c4_buf_lo;
                c5_buf_hi       <= c4_buf_hi;
                c5_buf_next_hi  <= c4_buf_next_hi;
            end
        end
    end
    if(UNIQUE_MUL>0) begin:GEN_C5_UNIQUE
        always @(posedge clk) begin
            if(c4_ctrl_first) begin
                c5_buf_adj      <= 1'b0;
                c5_buf_thresh   <= { SAD_BITS{1'b1}};
            end else begin
                c5_buf_adj      <= (c4_buf_disp == c4_ctrl_disp_prev);
                c5_buf_thresh   <= c4_buf_thresh;
            end
        end
    end
endgenerate


// ** delay through main sorter **

// c5_buf_disp to cm0_buf_disp
wire [DISP_BITS  -1:0] cm0_buf_disp;
dlsc_pipedelay #(
    .DATA       ( DISP_BITS ),
    .DELAY      ( CYCLE_CM0 - CYCLE_C5 )
) dlsc_pipedelay_inst_cm0_buf_disp (
    .clk        ( clk ),
    .in_data    ( c5_buf_disp ),
    .out_data   ( cm0_buf_disp )
);

// c5_ to cm0_
// (sub-pixel or uniqueness modes only)
wire [ SAD_BITS_D-1:0] cm0_pipe_sad;
wire [ SAD_BITS  -1:0] cm0_buf_lo;
wire [ SAD_BITS  -1:0] cm0_buf_hi;
wire [ SAD_BITS  -1:0] cm0_buf_next_hi;
wire [ SAD_BITS  -1:0] cm0_buf_thresh;
wire                   cm0_buf_adj;
wire [ SAD_BITS  -1:0] cm0_buf_sad;
generate
    if(LOHI_EN>0) begin:GEN_DELAY_CM0_SUB
        dlsc_pipedelay #(
            .DATA       ( SAD_BITS_D + 3*SAD_BITS ),
            .DELAY      ( CYCLE_CM0 - CYCLE_C5 )
        ) dlsc_pipedelay_inst_cm0_sub (
            .clk        ( clk ),
            .in_data    ( {
                c5_pipe_sad,
                c5_buf_lo,
                c5_buf_hi,
                c5_buf_next_hi } ),
            .out_data   ( {
                cm0_pipe_sad,
                cm0_buf_lo,
                cm0_buf_hi,
                cm0_buf_next_hi } )
        );
    end else begin:GEN_DELAY_CM0_NOSUB
        assign cm0_pipe_sad     = {SAD_BITS_D{1'b1}};
        assign cm0_buf_lo       = {SAD_BITS  {1'b1}};
        assign cm0_buf_hi       = {SAD_BITS  {1'b1}};
        assign cm0_buf_next_hi  = {SAD_BITS  {1'b1}};
    end
    if(UNIQUE_MUL>0) begin:GEN_DELAY_CM0_UNIQUE
        dlsc_pipedelay #(
            .DATA       ( 2*SAD_BITS + 1 ),
            .DELAY      ( CYCLE_CM0 - CYCLE_C5 )
        ) dlsc_pipedelay_inst_cm0_unique (
            .clk        ( clk ),
            .in_data    ( {  c5_buf_thresh,  c5_buf_adj,  c5_buf_sad } ),
            .out_data   ( { cm0_buf_thresh, cm0_buf_adj, cm0_buf_sad } )
        );
    end else begin:GEN_DELYA_CM0_NOUNIQUE
        assign cm0_buf_thresh   = {SAD_BITS  {1'b1}};
        assign cm0_buf_adj      = 1'b0;
        assign cm0_buf_sad      = {SAD_BITS  {1'b1}};
    end
endgenerate


// ** find best SAD **

wire [(MULT_D+1)*(MULT_D_BITS+1)-1:0] c5_id;
wire [(MULT_D+1)*(   SAD_BITS  )-1:0] c5_sad;

// input from buffer is lowest (highest priority; favors older/higher disparities)
assign c5_id [ 0 +: (MULT_D_BITS+1) ] = { 1'b1, {MULT_D_BITS{1'b0}}};
assign c5_sad[ 0 +: (   SAD_BITS  ) ] = c5_buf_sad;

generate
    for(j=0;j<MULT_D;j=j+1) begin:GEN_C5_IDS
        // need to reverse order, so higher disparities are at lower indices (min_tree favors lower)
/* verilator lint_off WIDTH */
        assign c5_id [ ((j+1)*(MULT_D_BITS+1)) +: (MULT_D_BITS+1) ] = MULT_D-1-j;
/* verilator lint_on WIDTH */
        assign c5_sad[ ((j+1)*(   SAD_BITS  )) +: (   SAD_BITS  ) ] = c5_pipe_sad[ ((MULT_D-1-j)*SAD_BITS) +: SAD_BITS ];
    end
endgenerate

wire [ (MULT_D_BITS+1)-1:0] cm0_id;
wire [ (   SAD_BITS  )-1:0] cm0_sad;

dlsc_min_tree #(
    .DATA       ( SAD_BITS ),
    .ID         ( MULT_D_BITS + 1 ),
    .META       ( 1 ),
    .INPUTS     ( MULT_D + 1 ),
    .PIPELINE   ( PIPELINE_LUT4 )
) dlsc_min_tree_inst_main (
    .clk        ( clk ),
    .rst        ( 1'b0 ),
    .in_valid   ( 1'b1 ),
    .in_meta    ( 1'b0 ),
    .in_id      ( c5_id ),
    .in_data    ( c5_sad ),
    .out_valid  (  ),
    .out_meta   (  ),
    .out_id     ( cm0_id ),
    .out_data   ( cm0_sad )
);

// extract winning MULT_D_BITS and pad
wire [DISP_BITS-1:0] cm0_disp;
wire                 cm0_buf_won = cm0_id[MULT_D_BITS];
generate
    if(MULT_D_BITS>0) begin:GEN_CM0_DISP_ID
        assign cm0_disp = { {(DISP_BITS-MULT_D_BITS){1'b0}},cm0_id[ 0 +: MULT_D_BITS ] };
    end else begin:GEN_CM0_DISP_NOID
        assign cm0_disp = {DISP_BITS{1'b0}};
    end
endgenerate


// ** get disparity for best SAD ** 
`DLSC_NO_SHREG reg  [DISP_BITS-1:0] cm1_disp;
reg  [ SAD_BITS-1:0] cm1_sad;
reg                  cm1_buf_won;
always @(posedge clk) begin
    if(cm0_buf_won) begin
        cm1_disp    <= cm0_buf_disp;
    end else begin
        // offset by this pass's base disparity
        cm1_disp    <= cm0_disp + cm0_ctrl_disp;
    end
    cm1_sad     <= cm0_sad;
    cm1_buf_won <= cm0_buf_won;
end


// ** delay main outputs **
dlsc_pipedelay #(
    .DATA       ( DISP_BITS ),
    .DELAY      ( CYCLE_CW - CYCLE_CM1 )
) dlsc_pipedelay_inst_cw_out_disp (
    .clk        ( clk ),
    .in_data    ( cm1_disp ),
    .out_data   ( cw_out_disp )
);
dlsc_pipedelay #(
    .DATA       ( SAD_BITS ),
    .DELAY      ( CYCLE_CW - CYCLE_CM1 )
) dlsc_pipedelay_inst_cw_out_sad (
    .clk        ( clk ),
    .in_data    ( cm1_sad ),
    .out_data   ( cw_out_sad )
);


// ** sub-pixel **

generate
    if(LOHI_EN) begin:GEN_SUB

        wire [ SAD_BITS-1:0] cm0_pipe_lo[MULT_D-1:0];
        wire [ SAD_BITS-1:0] cm0_pipe_hi[MULT_D-1:0];

        assign cm0_pipe_lo[0]        = {SAD_BITS{1'b1}};
        assign cm0_pipe_hi[MULT_D-1] = cm0_buf_next_hi;

        for(j=1;j<MULT_D;j=j+1) begin:GEN_CM1_LO
            assign cm0_pipe_lo[j] = cm0_pipe_sad[ ((j-1)*SAD_BITS) +: SAD_BITS ];
        end
        for(j=0;j<(MULT_D-1);j=j+1) begin:GEN_CM1_HI
            assign cm0_pipe_hi[j] = cm0_pipe_sad[ ((j+1)*SAD_BITS) +: SAD_BITS ];
        end

        `DLSC_NO_SHREG reg  [ SAD_BITS-1:0] cm1_lo;
        `DLSC_NO_SHREG reg  [ SAD_BITS-1:0] cm1_hi;
        reg  [ SAD_BITS-1:0] cm1_next_hi;

        always @(posedge clk) begin
            if(cm0_buf_won) begin
                cm1_lo      <= cm0_buf_lo;
                cm1_hi      <= cm0_buf_hi;
            end else begin
/* verilator lint_off WIDTH */
                cm1_lo      <= cm0_pipe_lo[cm0_disp];
                cm1_hi      <= cm0_pipe_hi[cm0_disp];
/* verilator lint_on WIDTH */
            end
        end

        always @(posedge clk) begin
            cm1_next_hi <= cm0_pipe_sad[ 0 +: SAD_BITS ];
        end
        
        // delay sub-pixel outputs
        dlsc_pipedelay #(
            .DATA       ( 3*SAD_BITS ),
            .DELAY      ( CYCLE_CW - CYCLE_CM1  )
        ) dlsc_pipedelay_inst_cw_out_lohi (
            .clk        ( clk ),
            .in_data    ( {
                cm1_lo,
                cm1_hi,
                cm1_next_hi } ),
            .out_data   ( {
                cw_out_lo,
                cw_out_hi,
                cw_out_next_hi } )
        );

    end else begin:GEN_NOSUB

        assign cw_out_lo        = {SAD_BITS{1'b1}};
        assign cw_out_hi        = {SAD_BITS{1'b1}};
        assign cw_out_next_hi   = {SAD_BITS{1'b1}};

    end
endgenerate


// ** uniqueness **
generate
    if(UNIQUE_MUL>0) begin:GEN_UNIQUE
        
        // extra inputs to uniqueness sorter
        reg [SAD_BITS  -1:0] cm1_buf_sad;       // input 0
        reg [SAD_BITS  -1:0] cm1_buf_hi;        // input 1
        reg [SAD_BITS  -1:0] cm1_buf_thresh;    // input 2
        reg [SAD_BITS_D-1:0] cm1_pipe_sad;      // pipe are inputs 3 through (MULT_D-1+3)

        always @(posedge clk) begin
            cm1_buf_sad     <= cm0_buf_sad;
            cm1_buf_hi      <= cm0_buf_hi;
            cm1_buf_thresh  <= cm0_buf_thresh;
            cm1_pipe_sad    <= cm0_pipe_sad;
        end

        // enable current thresh value, and all pipe inputs (except top one, if buf is adjacent to it)
        // don't enable buf_hi or buf_sad, since those fall within the exclusion window
        wire [(MULT_D+3)-1:0] cm0_buf_mask = { cm0_buf_adj, {(MULT_D-1){1'b0}}, 1'b0, 2'b11 };

        wire [(MULT_D+3)-1:0] cm0_pipe_mask[MULT_D-1:0];

        for(j=0;j<MULT_D;j=j+1) begin:GEN_CM0_PIPE_MASK
            assign cm0_pipe_mask[j][0] = (j == (MULT_D-1)) && cm0_buf_adj; // buf_sad only allowed when not adjacent
            assign cm0_pipe_mask[j][1] = 1'b0; // buf_hi is always allowed
            assign cm0_pipe_mask[j][2] = 1'b0; // buf_thresh is always allowed
            for(k=0;k<MULT_D;k=k+1) begin:GEN_CM0_PIPE_MASK_INNER
                // disable exclusion zone of +-1 around us
                assign cm0_pipe_mask[j][k+3] = !( (k+1) < j || k > (j+1) );
            end
        end

        // select mask for winner
        reg [(MULT_D+3)-1:0] cm1_mask;
        always @(posedge clk) begin
            if(cm0_buf_won) begin
                cm1_mask    <= cm0_buf_mask;
            end else begin
/* verilator lint_off WIDTH */
                cm1_mask    <= cm0_pipe_mask[cm0_disp];
/* verilator lint_on WIDTH */
            end
        end

        // create masked inputs
        wire [(MULT_D+3)*SAD_BITS-1:0] cm1_masked_sad;
        assign cm1_masked_sad[ (0*SAD_BITS) +: SAD_BITS ] = cm1_buf_sad    | {SAD_BITS{cm1_mask[0]}};
        assign cm1_masked_sad[ (1*SAD_BITS) +: SAD_BITS ] = cm1_buf_hi     | {SAD_BITS{cm1_mask[1]}};
        assign cm1_masked_sad[ (2*SAD_BITS) +: SAD_BITS ] = cm1_buf_thresh | {SAD_BITS{cm1_mask[2]}};
        for(j=0;j<MULT_D;j=j+1) begin:GEN_CM1_MASKED_SAD
            assign cm1_masked_sad[ ((j+3)*SAD_BITS) +: SAD_BITS ] = cm1_pipe_sad[ (j*SAD_BITS) +: SAD_BITS ] | {SAD_BITS{cm1_mask[j+3]}};
        end

        // optional pipeline stage
        wire [(MULT_D+3)*SAD_BITS-1:0] cm2_masked_sad;
        dlsc_pipereg #(
            .DATA       ( (MULT_D+3)*SAD_BITS ),
            .PIPELINE   ( PIPELINE_LUT4 )
        ) dlsc_pipereg_inst_cm2_masked_sad (
            .clk        ( clk ),
            .in_data    ( cm1_masked_sad ),
            .out_data   ( cm2_masked_sad )
        );

        // threshold sorter
        dlsc_min_tree #(
            .DATA       ( SAD_BITS ),
            .ID         ( 1 ),
            .META       ( 1 ),
            .INPUTS     ( MULT_D + 3 ),
            .PIPELINE   ( PIPELINE_LUT4 )
        ) dlsc_min_tree_inst_thresh (
            .clk        ( clk ),
            .rst        ( 1'b0 ),
            .in_valid   ( 1'b1 ),
            .in_meta    ( 1'b0 ),
            .in_id      ( {(MULT_D+3){1'b0}} ),
            .in_data    ( cm2_masked_sad ),
            .out_valid  (  ),
            .out_meta   (  ),
            .out_id     (  ),
            .out_data   ( cw_out_thresh )
        );

    end else begin:GEN_NOUNIQUE

        assign cw_out_thresh    = {SAD_BITS{1'b1}};

    end
endgenerate

endmodule


module dlsc_stereobm_frontend_control #(
    parameter IMG_WIDTH     = 320,
    parameter IMG_HEIGHT    = 16,
    parameter DISP_BITS     = 6,
    parameter DISPARITIES   = (2**DISP_BITS),
    parameter TEXTURE       = 0,        // texture filtering
    parameter MULT_D        = 4,        // DISPARITIES must be integer multiple of MULT_D
    parameter MULT_R        = 2,        // IMG_HEIGHT must be integer multiple of MULT_R
    parameter SAD           = 9,
    parameter DATA          = 8,
    parameter ADDR          = 10,       // enough for IMG_WIDTH
    // derived parameters; don't touch
    parameter SAD_R         = (SAD+MULT_R-1),
    parameter DATA_R        = (DATA*MULT_R)
) (
    input   wire                    clk,
    input   wire                    rst,

    // image input
    output  reg                     in_ready,
    input   wire                    in_valid,
    input   wire    [DATA_R-1:0]    in_left,
    input   wire    [DATA_R-1:0]    in_right,

    // buffer addresses
    output  reg     [ADDR-1:0]      addr_left,
    output  reg     [ADDR-1:0]      addr_right,

    // row buffer control
    output  reg                     buf_read,
    output  reg                     buf_write,
    output  reg     [DATA_R-1:0]    buf_left,
    output  reg     [DATA_R-1:0]    buf_right,

    // pipeline control
    output  reg                     pipe_right_valid,
    output  reg                     pipe_valid,
    output  reg                     pipe_first,
    output  reg                     pipe_text,

    // backend control
    input   wire                    back_busy,
    output  reg                     back_valid
);

`include "dlsc_clog2.vh"

localparam IMG_HEIGHT_R = (IMG_HEIGHT/MULT_R);
localparam ROW_BITS     = `dlsc_clog2(IMG_HEIGHT_R);

// padding to cope with unaligned MULT_R; control logic for this condition
// is currently non-functional (TODO)
localparam SAD_R_REM    = ((SAD/2)%MULT_R);
localparam PAD_R        = (SAD_R_REM == 0) ? 0 : (MULT_R - SAD_R_REM); // (SAD/2)+PAD_R must fall on MULT_R boundary
localparam SAD_RP       = (SAD_R + PAD_R);


// column counter
reg [ADDR-1:0]      x;
reg [ADDR-1:0]      x_next;
reg                 x_last;     // x == (IMG_WIDTH-1)

// row counter
reg [ROW_BITS-1:0]  y;
reg [ROW_BITS-1:0]  y_next;

// disparity counter
reg [DISP_BITS-1:0] pass;
reg [DISP_BITS-1:0] pass_next;

// state flags; multiple may be active simultaneously
reg                 st_load;    // loading enabled
reg                 st_xfer;    // row-to-row transfer enabled
reg                 st_sad;     // SAD pipeline enabled
reg                 st_text;    // texture filtering

// next-state
reg                 st_load_next;
reg                 st_xfer_next;
reg                 st_sad_next;
reg                 st_text_next;

// if in_ready is asserted, the only way to advance is for in_valid to assert
// otherwise, we can only advance if we're not loading and: we're not transferring,
// or if we're transferring and the backend isn't busy
wire st_en = ( in_ready && in_valid ) || ( !in_ready && !st_load && ( !st_xfer || !back_busy ) );

/* verilator lint_off WIDTH */

// column counter
always @(posedge clk) begin
    if(rst) begin

        // reset state includes st_load/st_xfer; must start from address 0
        x           <= 0;
        x_last      <= 1'b0;

    end else if(st_en) begin

        // pre-decode last state
        // x_last must be asserted coincident with x == (IMG_WIDTH-1)
        x_last      <= (x == (IMG_WIDTH-2));
    
        if(x_last) begin
            // state-transition
            // x_next provided by next-state generation logic below
            x           <= x_next;
        end else begin
            x           <= x + 1;
        end

    end
end

// ** generate in_ready **
always @(posedge clk) begin
    if(rst) begin
        in_ready    <= 1'b0;
    end else if(!in_ready || in_valid) begin
        // once asserted, in_ready can't be deasserted until in_valid also asserts
        if(st_en && x_last) begin
            // state-change in progress; need to base in_ready on
            // about-to-be-loaded next-state
            in_ready    <= st_load_next && !back_busy;
        end else begin
            // stall frontend if the backend is busy
            in_ready    <= st_load && !back_busy;
        end
    end
end

// ** track valid buffer rows **
reg [SAD_RP-1:0] rows_valid;
reg             rows_valid_center;
wire [SAD_RP-1:0] rows_valid_next = { rows_valid[SAD_RP-1-MULT_R:0], {MULT_R{st_load}} };
always @(posedge clk) begin
    if(rst) begin
        rows_valid      <= 0;
        rows_valid_center <= 1'b0;
    end else if(st_en && x_last && st_xfer) begin
        // on last access to row, shift
        // if last access was a write, indicate that the row is valid
        rows_valid      <= rows_valid_next;
        // center rows are fed to backend; determine if any of them are valid
        rows_valid_center <= |rows_valid_next[ ((SAD/2)+PAD_R) +: MULT_R ];
    end
end

// ** load next-state **
always @(posedge clk) begin
    if(rst) begin
        // reset state has us preloading the first row for the first frame
        st_load     <= 1'b1;
        st_xfer     <= 1'b1;
        st_sad      <= 1'b0;
        st_text     <= 1'b0;
        pass        <= 0;
        y           <= (IMG_HEIGHT_R-1);
    end else if(st_en && x_last) begin
        st_load     <= st_load_next;
        st_xfer     <= st_xfer_next;
        st_sad      <= st_sad_next;
        st_text     <= st_text_next;
        pass        <= pass_next;
        y           <= y_next;
    end
end

// ** generate next-state **
// we have an entire pass (~IMG_WIDTH cycles) to generate next-state; so multiple
// levels of registering are used to mitigate timing issues
reg                 y_last;             // y == (IMG_HEIGHT_R-1)
reg                 y_next_sad;         // y_next == ( (SAD-1)/MULT_R )
reg                 pass_last;          // pass == 0
reg                 pass_next_last;     // pass_next == 0
always @(posedge clk) begin

    // decode relevant pass states into single-bit registers
    // lowest disparity is last
    pass_last       <= (pass      == 0) && (st_text      || !st_sad      || TEXTURE == 0);
    pass_next_last  <= (pass_next == 0) && (st_text_next || !st_sad_next || TEXTURE == 0);

    // enable texture filtering pass after final disparity pass
    st_text_next    <= (pass == 0) && !st_text && st_sad && (TEXTURE > 0);

    if(pass_last || st_text_next) begin
        if(!st_sad_next || st_text_next) begin
            // if not running SAD, can skip to last pass
            pass_next       <= 0;
        end else begin
            // start at highest disparity
            pass_next       <= (DISPARITIES-MULT_D);
        end
    end else begin
        // MULT_D disparities are computed in parallel, so
        // advance by that much per pass
        pass_next       <= pass - MULT_D;
    end

    // decode relevant Y states into single-bit registers
    y_next          <= y;
    y_last          <= ( y == (IMG_HEIGHT_R-1) );
    y_next_sad      <= ( y_next == ((SAD-1)/MULT_R) );  // SAD can start once we've accumulated SAD rows.. [0,SAD-1]

    if( pass_last ) begin
        if( y_last ) begin
            if( st_load ) begin
                // if we're on the last, and we preloaded row 0,
                // then we can begin the next frame
                y_next      <= 0;
            end // else, hold at (IMG_HEIGHT_R-1)
        end else begin
            y_next          <= y + 1;
        end
    end

    // normally, if we were SADing, we will continue to do so..
    st_sad_next     <= st_sad;

    if( pass_last ) begin
        // SAD state can only change at row transitions
        if( y_next_sad ) begin
            // accumulated SAD rows; start SAD
            st_sad_next     <= 1'b1;
        end
        if( y_last ) begin
            // done with frame; stop SAD
            st_sad_next     <= 1'b0;
        end
    end

    // always transfer on the last pass
    st_xfer_next    <= pass_next_last;

    // load if we're transferring AND:
    // - we're not on the last row
    // - OR data for the next frame is already available
    // - OR we already started loading data for the next frame
    // - OR we've run out of valid rows to transfer
    st_load_next    <= pass_next_last && ( !y_last || in_valid || st_load || !rows_valid_center );

    if(st_xfer_next) begin
        // if transferring, must start at address 0
        x_next          <= 0;
    end else begin
        // if not transferring, can skip unused data
        x_next          <= (DISPARITIES-MULT_D);
    end

end

// ** generate control outputs **
always @(posedge clk) begin
    addr_left       <= x;
    addr_right      <= x - {{(ADDR-DISP_BITS){1'b0}},pass}; // (x - disparity)
    buf_left        <= in_left;
    buf_right       <= in_right;
    pipe_first      <= st_sad && (x == (DISPARITIES-1));    // first pixel is always when left == (disparities-1)
    pipe_text       <= st_text;
end

// ** generate valid flags **
reg fl_pipe_right_valid;
reg fl_pipe_valid;
always @(posedge clk) begin
    if(rst) begin
        // valid flags must be reset; since these qualify all data
        fl_pipe_right_valid <= 1'b0;
        fl_pipe_valid       <= 1'b0;
        pipe_right_valid    <= 1'b0;
        pipe_valid          <= 1'b0;
        back_valid          <= 1'b0;
        buf_read            <= 1'b0;
        buf_write           <= 1'b0;
    end else begin
        if(st_en) begin
            pipe_right_valid    <= fl_pipe_right_valid;
            pipe_valid          <= fl_pipe_valid;

            // backend pixels are only valid when we're transffering and the row
            // buffers contain valid data
            back_valid          <= st_xfer && rows_valid_center;

            if(x == (DISPARITIES-MULT_D)) begin
                // when running parallel disparities (MULT_D > 1), right pixels
                // become valid before left pixels (in order to prime pipeline)
                fl_pipe_right_valid <= st_sad;
                pipe_right_valid    <= st_sad;
            end
            if(x == (DISPARITIES-1)) begin
                // left and right are both valid once disparities-1 is reached
                fl_pipe_valid       <= st_sad;
                pipe_valid          <= st_sad;
            end
            if(x_last) begin
                fl_pipe_right_valid <= 1'b0;
                fl_pipe_valid       <= 1'b0;
            end
            buf_read        <= st_sad  || st_xfer;
            buf_write       <= st_load || st_xfer;
        end else begin
            // control logic was stalled; send inactive bubble down pipeline
            pipe_right_valid    <= 1'b0;
            pipe_valid          <= 1'b0;
            back_valid          <= 1'b0;
            buf_read            <= 1'b0;
            buf_write           <= 1'b0;
        end
    end
end

/* verilator lint_on WIDTH */


//`ifdef DLSC_SIMULATION
//`include "dlsc_sim_top.vh"
//always @(posedge clk) begin
//
//    if(st_load && !st_xfer) begin
//        `dlsc_error("st_xfer must be asserted when st_load is asserted");
//    end
//
//    if(st_xfer && pass != 0) begin
//        `dlsc_error("st_xfer only allowed when pass == 0");
//    end
//
//end
//`include "dlsc_sim_bot.vh"
//`endif


endmodule


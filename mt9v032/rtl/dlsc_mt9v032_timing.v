
module dlsc_mt9v032_timing (
    // system
    input   wire                clk,            // px_clk*2
    input   wire                clk_en,         // half-speed enable (turn clk*2 into px_clk)
    input   wire                rst,

    // timing config
    input   wire    [9:0]       hdisp,
    input   wire    [9:0]       vdisp,

    // timing observed
    output  reg     [9:0]       obs_hdisp,
    output  reg     [9:0]       obs_vdisp,

    // status
    output  reg                 res_okay,
    output  reg                 res_error,
    output  reg                 sync_error,
    output  reg                 frame_start,
    output  reg                 frame_end,

    // raw data input (qualified by clk_en)
    input   wire    [9:0]       in_data,

    // processed output (qualified by clk_en)
    output  reg     [9:0]       out_data,
    output  reg                 out_px_valid,
    output  reg                 out_line_valid,
    output  reg                 out_frame_valid
);

// start detector
// detects sequence {1023,0,1023}

reg  [1:0]      start_st;
wire            start_detected      = (start_st == 2 && in_data == 10'd1023);

always @(posedge clk) begin
    if(rst) begin
        start_st    <= 0;
    end else if(clk_en) begin
        if(start_st == 0 && in_data == 10'd1023) begin
            start_st <= 1;
        end else if(start_st == 1 && in_data == 10'd0) begin
            start_st <= 2;
        end else begin
            start_st <= 0;
        end
    end
end

// decode frame/line valid

reg             frame_valid_r;
wire            frame_valid_set     = start_detected;
wire            frame_valid_clear   = (in_data == 10'd3);

wire            frame_valid         = (frame_valid_r && !frame_valid_clear) || frame_valid_set;

reg             line_valid_r;
reg             line_valid_set;
wire            line_valid_clear    = (in_data == 10'd2) || frame_valid_clear;

wire            line_valid          = (line_valid_r && !line_valid_clear) || line_valid_set;

wire            px_valid            = frame_valid_r && line_valid;

always @(posedge clk) begin
    if(rst) begin
        line_valid_set  <= 1'b0;
        line_valid_r    <= 1'b0;
        frame_valid_r   <= 1'b0;
    end else if(clk_en) begin
        line_valid_set  <= (in_data == 10'd1);
        line_valid_r    <= line_valid;
        frame_valid_r   <= frame_valid;
    end
end

// register output

always @(posedge clk) begin
    if(rst) begin
        out_px_valid    <= 1'b0;
        out_line_valid  <= 1'b0;
        out_frame_valid <= 1'b0;
    end else if(clk_en) begin
        out_px_valid    <= px_valid;
        out_line_valid  <= line_valid;
        out_frame_valid <= frame_valid;
    end
end

always @(posedge clk) begin
    if(clk_en) begin
        out_data        <= px_valid ? in_data : 10'd0;
    end
end

// track timing

reg  [9:0]      obs_hdisp_cnt;
reg  [9:0]      obs_vdisp_cnt;

reg             hdisp_okay;
reg             vdisp_okay;

always @(posedge clk) begin
    if(rst) begin
        obs_hdisp       <= 0;
        obs_vdisp       <= 0;
        obs_hdisp_cnt   <= 0;
        obs_vdisp_cnt   <= 0;
        hdisp_okay      <= 1'b0;
        vdisp_okay      <= 1'b0;
        res_okay        <= 1'b0;
        res_error       <= 1'b0;
        sync_error      <= 1'b0;
        frame_start     <= 1'b0;
        frame_end       <= 1'b0;
    end else begin

        res_error       <= 1'b0;
        sync_error      <= 1'b0;
        frame_start     <= clk_en && !frame_valid_r && frame_valid_set;
        frame_end       <= clk_en &&  frame_valid_r && frame_valid_clear;

        if(clk_en) begin
            if(frame_valid_r) begin // inexact registered version is good enough

                // ** horizontal **
                if(line_valid) begin
                    // count horizontal pixels
                    obs_hdisp_cnt   <= obs_hdisp_cnt + 1;
                    // check hdisp
                    if(obs_hdisp_cnt == hdisp && !line_valid_clear) begin
                        // hdisp overflow
                        hdisp_okay      <= 1'b0;
                        res_okay        <= 1'b0;
                        res_error       <= 1'b1;
                    end
                end
                if(line_valid_clear) begin
                    // end of line
                    // transfer and reset hdisp
                    obs_hdisp       <= obs_hdisp_cnt;
                    obs_hdisp_cnt   <= 0;
                    // check hdisp
                    if(obs_hdisp_cnt != hdisp) begin
                        hdisp_okay      <= 1'b0;
                        res_okay        <= 1'b0;
                        res_error       <= 1'b1;
                    end
                end

                // ** vertical **
                if(line_valid_set) begin
                    // beginning of line
                    // count vertical pixels
                    obs_vdisp_cnt   <= obs_vdisp_cnt + 1;
                    // check vdisp
                    if(obs_vdisp_cnt == vdisp) begin
                        // vdisp overflow
                        vdisp_okay      <= 1'b0;
                        res_okay        <= 1'b0;
                        res_error       <= 1'b1;
                    end
                end
                if(frame_valid_clear) begin
                    // end of frame
                    // transfer and reset vdisp
                    obs_vdisp       <= obs_vdisp_cnt;
                    obs_vdisp_cnt   <= 0;
                    // check resolution
                    res_okay        <= (obs_vdisp_cnt == vdisp) && vdisp_okay && hdisp_okay;
                end

            end

            if(frame_valid_set) begin
                // beginning of frame; reset everything
                obs_hdisp_cnt   <= 0;
                obs_vdisp_cnt   <= 0;
                vdisp_okay      <= 1'b1;
                hdisp_okay      <= 1'b1;
            end

            // check command sequencing
            if( ( frame_valid_r && frame_valid_set) ||
                (!frame_valid_r && frame_valid_clear) ||
                ( line_valid_r  && line_valid_set) ||
                (!line_valid_r  && line_valid_clear) )
            begin
                sync_error      <= 1'b1;
                vdisp_okay      <= 1'b0;
                hdisp_okay      <= 1'b0;
                res_okay        <= 1'b0;
            end
        end

    end
end

endmodule


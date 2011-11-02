
module mt9v032_post (
    // clocks and resets
    input   wire                    rst,            // synchronous to clk
    input   wire                    clk,            // pixel clock
    
    // raw data in
    input   wire    [9:0]           data_in,

    // post-processed data out
    output  reg     [9:0]           px,
    output  reg                     line_valid,
    output  reg                     frame_valid
);

reg             line_valid_pre;
reg     [1:0]   frame_valid_pre;

always @(posedge clk) begin
    if(rst) begin
        
        px              <= 0;
        line_valid      <= 1'b0;
        frame_valid     <= 1'b0;
        line_valid_pre  <= 1'b0;
        frame_valid_pre <= 0;

    end else begin

        px              <= 0;
       
        line_valid_pre  <= 1'b0;
        frame_valid_pre <= 0;

        if(line_valid_pre)
            line_valid      <= 1'b1;
        if(frame_valid_pre == 2'd3)
            frame_valid     <= 1'b1;

        // 1023, 0, 1023 sequence precedes frame valid assertion
        if(frame_valid_pre == 2'd0 && data_in == 10'd1023) begin
            frame_valid_pre <= 2'd1;
        end else if(frame_valid_pre == 2'd1 && data_in == 10'd0) begin
            frame_valid_pre <= 2'd2;
        end else if(frame_valid_pre == 2'd2 && data_in == 10'd1023) begin
            frame_valid_pre <= 2'd3;
        end

        // 0 precedes frame valid assertion
        if(data_in == 10'd0) begin
            // (handled above)
        // 1 precedes line valid assertion
        end else if(data_in == 10'd1) begin
            line_valid_pre  <= 1'b1;
        // 2 succeeds line valid de-assertion
        end else if(data_in == 10'd2) begin
            line_valid      <= 1'b0;
        // 3 succeeds frame valid de-assertion
        end else if(data_in == 10'd3) begin
            line_valid      <= 1'b0;
            frame_valid     <= 1'b0;
        end else begin
            // only output pixels if they're visible (within a line and frame)
            if( (frame_valid_pre == 2'd3 || frame_valid) && (line_valid_pre || line_valid) ) begin
                // convert 4 to 0 (all pixels 0-4 mapped to 4, but want to retain 0's in output..)
                px              <= ( data_in == 10'd4 ) ? 10'd0 : data_in; 
            end
        end
                
    end
end

endmodule



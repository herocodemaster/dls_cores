
`timescale 1ps/1ps

module mt9v032_model #(
    parameter CLK_PERIOD = 40000,
    parameter CLK_DELAY = 0.0,

    parameter HPX = 64,     // horizontal pixels (visible)
    parameter VPX = 48,     // vertical lines (visible)
    parameter HBLANK = 16,  // horizontal blanking pixels
    parameter VBLANK = 16   // vertical blanking lines
) (
    input   wire                    clk,

    input   wire                    train,

    output  reg                     out_p,
    output  reg                     out_n
);

wire clk_px;

assign #CLK_DELAY clk_px = clk;

// measure clock period
time period;
time prev_time;
real lvds_time = ( CLK_PERIOD / 24.0 );

always @(posedge clk_px) begin
    period          = $time - prev_time;
    prev_time       = $time;

    // lvds period is running average
    lvds_time       = lvds_time*0.75 + (period/24.0)*0.25;
end

// create LVDS clock
reg clk_lvds = 0;
always @(clk_px) begin
    clk_lvds = !clk_lvds;
    repeat(11) begin
        #lvds_time clk_lvds = !clk_lvds;
    end
end


reg [9:0] data = 0;
wire [11:0] data_framed = { 1'b0, data[9:0], 1'b1 };
integer data_i = 0;

reg frame_valid = 0;
reg line_valid  = 0;

integer x = 0;
integer y = 0;


always @(posedge clk_lvds) begin
    out_p <=  data_framed[data_i];
    out_n <= !data_framed[data_i];

    if(data_i == 11) begin
        data_i      <= 0;

        if(train) begin
            x <= 0;
            y <= 0;
            frame_valid <= 0;
            line_valid <= 0;
            data <= 0;
        end else begin

            x <= x + 1;
            if(x == (HPX+HBLANK-1)) begin
                x <= 0;
                y <= y + 1;
                if(y == (VPX+VBLANK-1)) begin
                    y <= 0;
                end
            end

            if(frame_valid && line_valid) begin
                data <= x+y+4; // visible pixels
            end else begin
                data <= 10'd4;
            end                

            if(x == (HPX+HBLANK-1)) begin // last blanking pixel
                if(frame_valid) begin
                    data <= 10'd1;
                    line_valid <= 1'b1;
                end
            end

            if(x == HPX) begin // first blanking pixel
                line_valid <= 1'b0;
                if(frame_valid) begin
                    data <= 10'd2;
                end
            end

            if(y == (VPX+VBLANK-1)) begin // last blanking line
                case(x)
                    (HPX+HBLANK-4): begin data <= 10'd1023; end
                    (HPX+HBLANK-3): begin data <= 10'd0; end
                    (HPX+HBLANK-2): begin data <= 10'd1023; frame_valid <= 1'b1; end
                endcase
            end

            if(y == (VPX-1)) begin // last visible line
                if(x == HPX) begin // first blanking pixel
                    data <= 10'd3;
                    frame_valid <= 1'b0;
                end
            end

        end // train
    end else begin
        data_i <= data_i + 1;
    end
end
    


endmodule



module dlsc_vga_timing #(
    parameter XBITS     = 12,
    parameter YBITS     = 12
) (
    // system
    input   wire                    clk,        // pclk
    input   wire                    rst,

    // timing outputs
    output  reg                     vsync,
    output  reg                     hsync,
    output  reg                     frame_valid,
    output  reg                     line_valid,
    output  reg                     px_valid,
    output  reg     [XBITS-1:0]     x,
    output  reg     [YBITS-1:0]     y,

    // horizontal timing configuration (modeline values minus one)
    input   wire    [XBITS-1:0]     hdisp,
    input   wire    [XBITS-1:0]     hsyncstart,
    input   wire    [XBITS-1:0]     hsyncend,
    input   wire    [XBITS-1:0]     htotal,

    // vertical timing configuration (modeline values minus one)
    input   wire    [YBITS-1:0]     vdisp,
    input   wire    [YBITS-1:0]     vsyncstart,
    input   wire    [YBITS-1:0]     vsyncend,
    input   wire    [YBITS-1:0]     vtotal
);

wire [XBITS-1:0] x_p1 = (x + 1);
wire [YBITS-1:0] y_p1 = (y + 1);

reg             x_last;
reg             y_last;

always @(posedge clk) begin
    if(rst) begin
        x_last      <= 1'b0;
        x           <= 0;
        y_last      <= 1'b0;
        y           <= 0;
    end else begin
        if(!x_last) begin
            x_last      <= x_p1 == htotal;
            x           <= x_p1;
        end else begin
            x_last      <= 1'b0;
            x           <= 0;
            if(!y_last) begin
                y_last      <= y_p1 == vtotal;
                y           <= y_p1;
            end else begin
                y_last      <= 1'b0;
                y           <= 0;
            end
        end
    end
end

reg             next_frame_valid;
reg             next_line_valid;
reg             next_px_valid;
reg             next_vsync;
reg             next_hsync;

always @* begin

    next_frame_valid    = frame_valid;
    next_line_valid     = line_valid;
    next_px_valid       = px_valid;
    next_vsync          = vsync;
    next_hsync          = hsync;

    if(x_last) begin // x == htotal
        next_line_valid     = 1'b1;
    end
    if(x == hdisp) begin
        next_line_valid     = 1'b0;
    end

    if(x == hsyncstart) begin
        next_hsync          = 1'b1;
    end
    if(x == hsyncend) begin
        next_hsync          = 1'b0;
    end

    if(x_last) begin
        if(y_last) begin // y == vtotal
            next_frame_valid    = 1'b1;
        end
        if(y == vdisp) begin
            next_frame_valid    = 1'b0;
        end
        if(y == vsyncstart) begin
            next_vsync          = 1'b1;
        end
        if(y == vsyncend) begin
            next_vsync          = 1'b0;
        end
    end

    next_px_valid       = next_line_valid && next_frame_valid;

end

always @(posedge clk) begin
    if(rst) begin
        vsync       <= 1'b0;
        hsync       <= 1'b0;
        frame_valid <= 1'b0;
        line_valid  <= 1'b0;
        px_valid    <= 1'b0;
    end else begin
        vsync       <= next_vsync;
        hsync       <= next_hsync;
        frame_valid <= next_frame_valid;
        line_valid  <= next_line_valid;
        px_valid    <= next_px_valid;
    end
end

endmodule


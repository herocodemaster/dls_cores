
module dlsc_vga_output #(
    parameter XBITS     = 12,
    parameter YBITS     = 12
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // Status
    output  reg                     frame_start,
    output  reg                     frame_done,
    output  reg                     underrun,

    // Modeline config
    input   wire    [XBITS-1:0]     hdisp,
    input   wire    [XBITS-1:0]     hsyncstart,
    input   wire    [XBITS-1:0]     hsyncend,
    input   wire    [XBITS-1:0]     htotal,
    input   wire    [YBITS-1:0]     vdisp,
    input   wire    [YBITS-1:0]     vsyncstart,
    input   wire    [YBITS-1:0]     vsyncend,
    input   wire    [YBITS-1:0]     vtotal,

    // Pixel config
    input   wire    [1:0]           pos_r,
    input   wire    [1:0]           pos_g,
    input   wire    [1:0]           pos_b,
    input   wire    [1:0]           pos_a,

    // Pixel input
    output  wire                    in_ready,
    input   wire                    in_valid,
    input   wire    [31:0]          in_data,

    // Video output
    output  reg                     px_en,
    output  reg                     px_vsync,
    output  reg                     px_hsync,
    output  reg                     px_frame_valid,
    output  reg                     px_line_valid,
    output  reg                     px_valid,
    output  reg     [7:0]           px_r,
    output  reg     [7:0]           px_g,
    output  reg     [7:0]           px_b,
    output  reg     [7:0]           px_a
);

// timing

wire            vsync;
wire            hsync;
wire            frame_valid;
wire            line_valid;
wire            xfer;

dlsc_vga_timing #(
    .XBITS          ( XBITS ),
    .YBITS          ( YBITS )
) dlsc_vga_timing_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .vsync          ( vsync ),
    .hsync          ( hsync ),
    .frame_valid    ( frame_valid ),
    .line_valid     ( line_valid ),
    .px_valid       ( xfer ),
    .x              (  ),
    .y              (  ),
    .hdisp          ( hdisp ),
    .hsyncstart     ( hsyncstart ),
    .hsyncend       ( hsyncend ),
    .htotal         ( htotal ),
    .vdisp          ( vdisp ),
    .vsyncstart     ( vsyncstart ),
    .vsyncend       ( vsyncend ),
    .vtotal         ( vtotal )
);

// drive output

assign          in_ready        = xfer && !underrun;

always @(posedge clk) begin
    px_en           <= !rst;
    px_vsync        <= vsync;
    px_hsync        <= hsync;
    px_frame_valid  <= frame_valid;
    px_line_valid   <= line_valid;
    px_valid        <= xfer;
    px_r            <= 0;
    px_g            <= 0;
    px_b            <= 0;
    px_a            <= 0;
    if(xfer && in_valid && !underrun) begin
        px_r            <= in_data[ (pos_r*8) +: 8 ];
        px_g            <= in_data[ (pos_g*8) +: 8 ];
        px_b            <= in_data[ (pos_b*8) +: 8 ];
        px_a            <= in_data[ (pos_a*8) +: 8 ];
    end
end

always @(posedge clk) begin
    if(rst) begin
        frame_start <= 1'b0;
        frame_done  <= 1'b0;
        underrun    <= 1'b0;
    end else begin
        frame_start <= 1'b0;
        frame_done  <= 1'b0;
        if(frame_valid && !px_frame_valid) begin
            // first visible pixel is about to be driven
            frame_start <= 1'b1;
        end
        if(!frame_valid && px_frame_valid) begin
            // last visible pixel was just driven
            frame_done  <= 1'b1;
            underrun    <= 1'b0;
        end
        if(xfer && !in_valid) begin
            // needed pixel, but none was available
            underrun    <= 1'b1;
        end
    end
end


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

reg  [XBITS-1:0]     prev_hdisp;
reg  [XBITS-1:0]     prev_hsyncstart;
reg  [XBITS-1:0]     prev_hsyncend;
reg  [XBITS-1:0]     prev_htotal;
reg  [YBITS-1:0]     prev_vdisp;
reg  [YBITS-1:0]     prev_vsyncstart;
reg  [YBITS-1:0]     prev_vsyncend;
reg  [YBITS-1:0]     prev_vtotal;
reg  [1:0]           prev_pos_r;
reg  [1:0]           prev_pos_g;
reg  [1:0]           prev_pos_b;
reg  [1:0]           prev_pos_a;

always @(posedge clk) begin

    prev_hdisp <= hdisp;
    prev_hsyncstart <= hsyncstart;
    prev_hsyncend <= hsyncend;
    prev_htotal <= htotal;
    prev_vdisp <= vdisp;
    prev_vsyncstart <= vsyncstart;
    prev_vsyncend <= vsyncend;
    prev_vtotal <= vtotal;
    prev_pos_r <= pos_r;
    prev_pos_g <= pos_g;
    prev_pos_b <= pos_b;
    prev_pos_a <= pos_a;
    
    if( !rst &&
       ((prev_hdisp != hdisp) ||
        (prev_hsyncstart != hsyncstart) ||
        (prev_hsyncend != hsyncend) ||
        (prev_htotal != htotal) ||
        (prev_vdisp != vdisp) ||
        (prev_vsyncstart != vsyncstart) ||
        (prev_vsyncend != vsyncend) ||
        (prev_vtotal != vtotal) ||
        (prev_pos_r != pos_r) ||
        (prev_pos_g != pos_g) ||
        (prev_pos_b != pos_b) ||
        (prev_pos_a != pos_a)) )
    begin
        `dlsc_error("configuration changed while not in reset");
    end

end

`include "dlsc_sim_bot.vh"
`endif


endmodule



`timescale 1ns/1ns

module dlsc_stereobm_tbv;

`include "dlsc_tb_top.vh"


localparam DATA             = `PARAM_DATA;
localparam DATAF            = `PARAM_DATAF;
localparam DATAF_MAX        = `PARAM_DATAF_MAX;
localparam IMG_WIDTH        = `PARAM_IMG_WIDTH;
localparam IMG_HEIGHT       = `PARAM_IMG_HEIGHT;
localparam DISP_BITS        = `PARAM_DISP_BITS;
localparam DISPARITIES      = `PARAM_DISPARITIES;
localparam SAD_WINDOW       = `PARAM_SAD_WINDOW;
localparam TEXTURE          = `PARAM_TEXTURE;
localparam SUB_BITS         = `PARAM_SUB_BITS;
localparam SUB_BITS_EXTRA   = `PARAM_SUB_BITS_EXTRA;
localparam UNIQUE_MUL       = `PARAM_UNIQUE_MUL;
localparam UNIQUE_DIV       = `PARAM_UNIQUE_DIV;
localparam OUT_LEFT         = `PARAM_OUT_LEFT;
localparam OUT_RIGHT        = `PARAM_OUT_RIGHT;
localparam MULT_D           = `PARAM_MULT_D;
localparam MULT_R           = `PARAM_MULT_R;
localparam PIPELINE_BRAM_RD = `PARAM_PIPELINE_BRAM_RD;
localparam PIPELINE_BRAM_WR = `PARAM_PIPELINE_BRAM_WR;
localparam PIPELINE_FANOUT  = `PARAM_PIPELINE_FANOUT;
localparam PIPELINE_LUT4    = `PARAM_PIPELINE_LUT4;

localparam DISP_BITS_S      = (DISP_BITS + SUB_BITS);

localparam PX               = (IMG_WIDTH*IMG_HEIGHT);

reg                     core_clk    = 0;
reg                     clk    = 0;
reg                     rst         = 1;
wire                    in_ready;
reg                     in_valid    = 0;
reg  [DATA-1:0]         in_left     = 0;
reg  [DATA-1:0]         in_right    = 0;
reg                     out_ready   = 0;
wire                    out_valid;
wire [DISP_BITS_S-1:0]  out_disp;
wire                    out_masked;
wire                    out_filtered;
wire [DATAF-1:0]        out_left;
wire [DATAF-1:0]        out_right;


`DLSC_DUT #(
    .DATA               ( DATA ),
    .DATAF              ( DATAF ),
    .DATAF_MAX          ( DATAF_MAX ),
    .IMG_WIDTH          ( IMG_WIDTH ),
    .IMG_HEIGHT         ( IMG_HEIGHT ),
    .DISP_BITS          ( DISP_BITS ),
    .DISPARITIES        ( DISPARITIES ),
    .SAD_WINDOW         ( SAD_WINDOW ),
    .TEXTURE            ( TEXTURE ),
    .SUB_BITS           ( SUB_BITS ),
    .SUB_BITS_EXTRA     ( SUB_BITS_EXTRA ),
    .UNIQUE_MUL         ( UNIQUE_MUL ),
    .UNIQUE_DIV         ( UNIQUE_DIV ),
    .OUT_LEFT           ( OUT_LEFT ),
    .OUT_RIGHT          ( OUT_RIGHT ),
    .MULT_D             ( MULT_D ),
    .MULT_R             ( MULT_R ),
    .PIPELINE_BRAM_RD   ( PIPELINE_BRAM_RD ),
    .PIPELINE_BRAM_WR   ( PIPELINE_BRAM_WR ),
    .PIPELINE_FANOUT    ( PIPELINE_FANOUT ),
    .PIPELINE_LUT4      ( PIPELINE_LUT4 )
) dut (
    .core_clk           ( core_clk ),
    .clk                ( clk ),
    .rst                ( rst ),
    .in_ready           ( in_ready ),
    .in_valid           ( in_valid ),
    .in_left            ( in_left ),
    .in_right           ( in_right ),
    .out_ready          ( out_ready ),
    .out_valid          ( out_valid ),
    .out_disp           ( out_disp ),
    .out_masked         ( out_masked ),
    .out_filtered       ( out_filtered ),
    .out_left           ( out_left ),
    .out_right          ( out_right )
);


initial forever #10 clk = !clk;

initial forever #3 core_clk = !core_clk;


// inputs
reg [7:0]   img_left    [0:PX-1];
reg [7:0]   img_right   [0:PX-1];
// outputs (to check against)
reg [15:0]  img_disp    [0:PX-1];
reg [7:0]   img_valid   [0:PX-1];
reg [7:0]   img_filtered[0:PX-1];
reg [7:0]   img_oleft   [0:PX-1];
reg [7:0]   img_oright  [0:PX-1];


// stimulus
integer in_x    = 0;
integer in_y    = 0;
integer in_px;
reg stim_done   = 0;

always @(posedge clk) begin
    if(rst) begin
        stim_done   <= 0;
        in_x        <= 0;
        in_y        <= 0;
        in_valid    <= 0;
        in_left     <= 0;
        in_right    <= 0;
    end else if(!in_valid || in_ready) begin

        if(!stim_done && `dlsc_rand(0,9) > 0) begin
            in_px       = in_x + (in_y * IMG_WIDTH);

            in_valid    <= 1;
            in_left     <= img_left [in_px];
            in_right    <= img_right[in_px];
            
            if(in_x == (IMG_WIDTH-1)) begin
                `dlsc_info("sent row %0d", in_y);
                in_x        <= 0;
                if(in_y == (IMG_HEIGHT-1)) begin
                    in_y        <= 0;
                    stim_done   <= 1;
                end else begin
                    in_y        <= in_y + 1;
                end                    
            end else begin
                in_x        <= in_x + 1;
            end
        end else begin
            in_valid    <= 0;
            in_left     <= 0;
            in_right    <= 0;
        end
    end
end


// checking
integer out_x   = 0;
integer out_y   = 0;
integer out_px;
reg check_done  = 0;

reg [DISP_BITS_S-1:0]   chk_disp;
reg                     chk_masked;
reg                     chk_filtered;
reg [DATAF-1:0]         chk_left;
reg [DATAF-1:0]         chk_right;

always @(posedge clk) begin
    if(rst) begin
        check_done  <= 0;
        out_x       <= 0;
        out_y       <= 0;
        out_ready   <= 0;
    end else begin

        if(out_valid && out_ready) begin
            out_px      = out_x + (out_y * IMG_WIDTH);

            chk_disp    = img_disp[out_px];
            chk_masked  = !img_valid[out_px];
            chk_filtered= img_filtered[out_px];
            chk_left    = OUT_LEFT  ? img_oleft [out_px] : 0;
            chk_right   = OUT_RIGHT ? img_oright[out_px] : 0;
            
            `dlsc_assert(out_disp       == chk_disp,        "out_disp");
            `dlsc_assert(out_masked     == chk_masked,      "out_masked");
            `dlsc_assert(out_filtered   == chk_filtered,    "out_filtered");
            `dlsc_assert(out_left       == chk_left,        "out_left");
            `dlsc_assert(out_right      == chk_right,       "out_right");
            
            if(out_x == (IMG_WIDTH-1)) begin
                `dlsc_info("finished row %0d", out_y);
                out_x       <= 0;
                if(out_y == (IMG_HEIGHT-1)) begin
                    out_y       <= 0;
                    check_done  <= 1;
                end else begin
                    out_y       <= out_y + 1;
                end                    
            end else begin
                out_x       <= out_x + 1;
            end
        end else begin
            out_ready   <= 0;
        end

        if(!check_done && `dlsc_rand(0,9) > 0) begin
            out_ready   <= 1;
        end else begin
            out_ready   <= 0;
        end
    end
end


// setup
initial begin
    rst = 1;

    `dlsc_info("reading data files..");

    $readmemh(`FILE_IN_LEFT,    img_left);
    $readmemh(`FILE_IN_RIGHT,   img_right);
    $readmemh(`FILE_DISP,       img_disp);
    $readmemh(`FILE_VALID,      img_valid);
    $readmemh(`FILE_FILTERED,   img_filtered);
    $readmemh(`FILE_LEFT,       img_oleft);
    $readmemh(`FILE_RIGHT,      img_oright);

    #100;
    @(posedge clk);
    rst = 0;

    `dlsc_info("reset removed");

    @(posedge check_done);

    `dlsc_info("done");

    #1000;
    `dlsc_finish;
end

endmodule


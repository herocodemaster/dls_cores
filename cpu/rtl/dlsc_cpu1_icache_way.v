module dlsc_cpu1_icache_way #(
    parameter SIZE      = 9,        // cache size is 2**SIZE words
    parameter LINE      = 4,        // line size is 2**LINE (have 2**(SIZE-LINE) tags)
    parameter DATA      = 32,       // width of word
    parameter TAG       = 32,       // width of tag
    parameter PREFETCH  = 0         // enable prefetcher
) (
    input   wire                    clk,
    
    // read
    input   wire    [SIZE-1:0]      rd_addr,
    output  wire    [DATA-1:0]      rd_data,
    output  reg     [TAG -1:0]      rd_tag,

    // prefetch
    input   wire    [SIZE-1:0]      pf_addr,
    output  reg     [TAG -1:0]      pf_tag,

    // write
    input   wire    [SIZE-1:0]      wr_addr,
    input   wire                    wr_en,
    input   wire    [DATA-1:0]      wr_data,
    input   wire                    wr_en_tag,
    input   wire    [TAG -1:0]      wr_tag
);

// cache
dlsc_ram_dp_slice #(
    .DATA       ( DATA ),
    .ADDR       ( SIZE ),
    .PIPELINE   ( 0 ),
    .WARNINGS   ( 0 )
) dlsc_ram_dp_slice_inst_cache (
    .write_clk  ( clk ),
    .write_en   ( wr_en ),
    .write_addr ( wr_addr ),
    .write_data ( wr_data ),
    .read_clk   ( clk ),
    .read_en    ( 1'b1 ),
    .read_addr  ( rd_addr ),
    .read_data  ( rd_data )
);

// tag
(* ram_style = "distributed" *) reg [TAG-1:0] tag_mem[(2**(SIZE-LINE))-1:0];

generate
    if(PREFETCH>0) begin:GEN_PF

        always @(posedge clk) begin
            if(wr_en_tag) begin
                tag_mem[wr_addr[SIZE-1:LINE]] <= wr_tag;
            end
            rd_tag  <= tag_mem[rd_addr[SIZE-1:LINE]];
            pf_tag  <= tag_mem[pf_addr[SIZE-1:LINE]];
        end

    end else begin:GEN_NOPF

        always @(posedge clk) begin
            if(wr_en_tag) begin
                tag_mem[wr_addr[SIZE-1:LINE]] <= wr_tag;
            end
            rd_tag  <= tag_mem[rd_addr[SIZE-1:LINE]];
        end

    end
endgenerate


endmodule


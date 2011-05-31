module dlsc_cpu1_icache_ways #(
    parameter ADDR      = 30,       // width of address bus
    parameter DATA      = 32,       // width of data bus
    parameter LINE      = 4,        // cache line size is 2**LINE
    parameter SIZE      = 9,        // way size is 2**WAY_SIZE
    parameter WAYS      = 1,        // number of ways
    parameter PREFETCH  = 0         // enable prefetcher
) (

    input   wire                    clk,

    // read
    input   wire    [ADDR-1:0]      rd_addr,
    output  wire    [DATA-1:0]      rd_data,
    output  wire                    rd_miss,
    output  wire    [WAYS-1:0]      rd_waylru,

    // prefetch
    input   wire    [ADDR-1:0]      pf_addr,
    output  wire                    pf_miss,
    output  wire    [WAYS-1:0]      pf_waylru,

    // write
    input   wire                    wr_init,        // initialize cache
    input   wire    [ADDR-1:0]      wr_addr,        // write address
    input   wire    [WAYS-1:0]      wr_way,         // way select
    // write data
    input   wire                    wr_en,          // cache write en
    input   wire    [DATA-1:0]      wr_data,        // cache data
    // write tag
    input   wire                    wr_en_tag,      // tag write en
    input   wire                    wr_last         // last write (validates tag)
);

`include "dlsc_clog2.vh"

localparam TAG = 2+ADDR-SIZE;

genvar j;

// ways
wire [DATA-1:0]         way_data[WAYS-1:0];
wire [WAYS-1:0]         way_tag_complete;
wire [WAYS-1:0]         way_tag_valid;
wire [(ADDR-SIZE-1):0]  way_tag_addr[WAYS-1:0];
wire [WAYS-1:0]         way_pf_complete;
wire [WAYS-1:0]         way_pf_valid;
wire [(ADDR-SIZE-1):0]  way_pf_addr[WAYS-1:0];

generate
    for(j=0;j<WAYS;j=j+1) begin:GEN_WAYS
        dlsc_cpu1_icache_way #(
            .SIZE       ( SIZE ),
            .LINE       ( LINE ),
            .DATA       ( DATA ),
            .TAG        ( TAG ),
            .PREFETCH   ( PREFETCH )
        ) dlsc_cpu1_icache_way_inst (
            .clk        ( clk ),
            .rd_addr    ( rd_addr[0+:SIZE] ),
            .rd_data    ( way_data[j] ),
            .rd_tag     ( { way_tag_complete[j], way_tag_valid[j], way_tag_addr[j] } ),
            .pf_addr    ( pf_addr[0+:SIZE] ),
            .pf_tag     ( { way_pf_complete[j], way_pf_valid[j], way_pf_addr[j] } ),
            .wr_addr    ( wr_addr[0+:SIZE] ),
            .wr_en      ( wr_en && wr_way[j] ),
            .wr_data    ( wr_data ),
            .wr_en_tag  ( (wr_en_tag && wr_way[j]) || wr_init ),    // write tags on init
            .wr_tag     ( { (wr_last||wr_init), wr_en, wr_addr[ADDR-1:SIZE] } ) // complete, valid, address
        );
    end
endgenerate

// cache line fill status
reg fill_flag;
reg fill_status;
(* ram_style = "distributed" *) reg fill_mem[(2**LINE)-1:0];

always @(posedge clk) begin
    if(wr_en || wr_init) begin
        // fill with 1's on init (flag will be initialized to 0)
        fill_mem[wr_addr[0+:LINE]] <= fill_flag || wr_init;
    end
    fill_status <= fill_mem[rd_addr[0+:LINE]];
end

always @(posedge clk) begin
    if(wr_init) begin
        fill_flag       <= 1'b0;
    end else if(wr_en_tag && wr_last) begin
        // toggle flag on last, to reset status for next fill
        fill_flag       <= !fill_flag;
    end
end

// save for hit checking
reg [ADDR-1:0] c1_rd_addr;
reg            c1_fill_flag;
always @(posedge clk) begin
    c1_rd_addr      <= rd_addr;
    c1_fill_flag    <= fill_flag;
end

reg [ADDR-1:0] c1_pf_addr = 0;
generate if(PREFETCH>0) begin:GEN_PREFETCH
    always @(posedge clk) begin
        c1_pf_addr  <= pf_addr;
    end
end endgenerate

wire [WAYS-1:0] way_hit;
wire [WAYS-1:0] way_pf_hit;

generate
    for(j=0;j<WAYS;j=j+1) begin:GEN_HITS
        assign way_hit[j]       = c1_rd_addr[ADDR-1:SIZE] == way_tag_addr[j] && way_tag_valid[j];
        assign way_pf_hit[j]    = c1_pf_addr[ADDR-1:SIZE] == way_pf_addr[j]  && way_pf_valid[j];
    end

    if(WAYS == 1) begin:GEN1

        assign rd_data      = way_data[0];
        assign rd_miss      = !( way_hit[0] && (way_tag_complete[0] || fill_status == c1_fill_flag) );
        assign rd_waylru    = 1'b1;

        assign pf_miss      = !( way_pf_hit[0] );
        assign pf_waylru    = 1'b1;

    end else if(WAYS == 2) begin:GEN2

        // at initialization, all ways are marked 'complete'
        // ..so, we can require completeness across all ways for a hit

        assign rd_data      = way_hit[0] ? way_data[0] : way_data[1];
        assign rd_miss      = !( |way_hit && ( |(way_hit&way_tag_complete) || fill_status == c1_fill_flag) );

        assign pf_miss      = !( |way_pf_hit );
        
        // LRU tracking
        (* ram_style = "distributed" *) reg lru_mem[(2**(SIZE-LINE))-1:0];

        assign rd_waylru    = (lru_mem[c1_rd_addr[SIZE-1:LINE]] == 0) ? 2'b01 : 2'b10;

        always @(posedge clk) begin
            if(!rd_miss) begin
                lru_mem[c1_rd_addr[SIZE-1:LINE]] <= (way_hit[0] ? 1 : 0);
            end
        end

        if(PREFETCH>0) begin:GEN2_PF
            assign pf_waylru = (lru_mem[c1_pf_addr[SIZE-1:LINE]] == 0) ? 2'b01 : 2'b10;
        end else begin:GEN2_NOPF
            assign pf_waylru = 2'b00;
        end

    end
endgenerate


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

reg wr_last_prev;
integer i;
integer cnt;
always @(posedge clk) if(!wr_init) begin

    wr_last_prev <= wr_en_tag && wr_last;
    if(wr_last_prev) begin
        for(i=0;i<LINE;i=i+1) begin
            if(fill_mem[i] == fill_flag) begin
                `dlsc_error("fill_mem[%0d] not consistent", i);
            end
        end
    end

    cnt = 0;
    for(i=0;i<WAYS;i=i+1) begin
        if(way_hit[i]) begin
            cnt = cnt + 1;
        end
    end
    if(cnt > 1) begin
        `dlsc_error("multiple ways hit simultaneously (shouldn't happen)");
    end

    cnt = 0;
    for(i=0;i<WAYS;i=i+1) begin
        if(!way_tag_complete[i]) begin
            cnt = cnt + 1;
        end
    end
    if(cnt > 1) begin
        `dlsc_error("multiple ways incomplete simultaneously (shouldn't happen)");
    end

end

if(WAYS==2) begin
    always @(posedge clk) if(!wr_init) begin

        if( ( (way_hit[0] && way_tag_complete[0] && !way_tag_complete[1]) ||
              (way_hit[1] && way_tag_complete[1] && !way_tag_complete[0]) ) && rd_miss )
        begin
            `dlsc_verb("prefetcher caused miss");
        end

    end
end

`include "dlsc_sim_bot.vh"
`endif


endmodule


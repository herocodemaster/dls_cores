
// modified dlsc_sortnet_8

// merges two pre-sorted 4-entry lists into one sorted 8-entry list

// algorithm:   batcher
// inputs:      8
// levels:      3
// comparators: 9

module dlsc_sortnet_merge_2x4 #(
    parameter META      = 8,        // width of bypassed metadata
    parameter DATA      = 16,       // width of data for each element
    parameter ID        = 8,        // width of IDs for each element
    parameter PIPELINE  = 0,
    // derived; don't touch
    parameter ID_I      = (8*ID),
    parameter DATA_I    = (8*DATA)
) (
    input   wire                    clk,
    input   wire                    rst,

    input   wire                    in_valid,       // qualifier
    input   wire    [META-1:0]      in_meta,        // metadata to be delay-matched to sorting operation
    input   wire    [DATA_I-1:0]    in_data,        // unsorted data
    input   wire    [ID_I-1:0]      in_id,          // identifiers for unsorted data

    output  wire                    out_valid,      // delayed qualifier
    output  wire    [META-1:0]      out_meta,       // delayed in_meta
    output  wire    [DATA_I-1:0]    out_data,       // sorted data
    output  wire    [ID_I-1:0]      out_id          // identifiers for sorted data
);


// ** inputs **
wire    [ID-1:0]    lvl0_id [7:0];
wire    [DATA-1:0]  lvl0_data [7:0];
assign lvl0_id[0]   = in_id  [ (0*  ID) +:   ID ];
assign lvl0_data[0] = in_data[ (0*DATA) +: DATA ];
assign lvl0_id[1]   = in_id  [ (1*  ID) +:   ID ];
assign lvl0_data[1] = in_data[ (1*DATA) +: DATA ];
assign lvl0_id[2]   = in_id  [ (2*  ID) +:   ID ];
assign lvl0_data[2] = in_data[ (2*DATA) +: DATA ];
assign lvl0_id[3]   = in_id  [ (3*  ID) +:   ID ];
assign lvl0_data[3] = in_data[ (3*DATA) +: DATA ];
assign lvl0_id[4]   = in_id  [ (4*  ID) +:   ID ];
assign lvl0_data[4] = in_data[ (4*DATA) +: DATA ];
assign lvl0_id[5]   = in_id  [ (5*  ID) +:   ID ];
assign lvl0_data[5] = in_data[ (5*DATA) +: DATA ];
assign lvl0_id[6]   = in_id  [ (6*  ID) +:   ID ];
assign lvl0_data[6] = in_data[ (6*DATA) +: DATA ];
assign lvl0_id[7]   = in_id  [ (7*  ID) +:   ID ];
assign lvl0_data[7] = in_data[ (7*DATA) +: DATA ];


// ** level 1 **
// [[0,4],[1,5],[2,6],[3,7]]

wire    [ID-1:0]    lvl1_id [7:0];
wire    [DATA-1:0]  lvl1_data [7:0];

// level 1: compex(0,4)
dlsc_sortnet_compex #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( PIPELINE )
) dlsc_sortnet_compex_inst_1_0_4 (
    .clk        ( clk ),
    .in_id0     ( lvl0_id[0] ),
    .in_data0   ( lvl0_data[0] ),
    .in_id1     ( lvl0_id[4] ),
    .in_data1   ( lvl0_data[4] ),
    .out_id0    ( lvl1_id[0] ),
    .out_data0  ( lvl1_data[0] ),
    .out_id1    ( lvl1_id[4] ),
    .out_data1  ( lvl1_data[4] )
);

// level 1: compex(1,5)
dlsc_sortnet_compex #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( PIPELINE )
) dlsc_sortnet_compex_inst_1_1_5 (
    .clk        ( clk ),
    .in_id0     ( lvl0_id[1] ),
    .in_data0   ( lvl0_data[1] ),
    .in_id1     ( lvl0_id[5] ),
    .in_data1   ( lvl0_data[5] ),
    .out_id0    ( lvl1_id[1] ),
    .out_data0  ( lvl1_data[1] ),
    .out_id1    ( lvl1_id[5] ),
    .out_data1  ( lvl1_data[5] )
);

// level 1: compex(2,6)
dlsc_sortnet_compex #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( PIPELINE )
) dlsc_sortnet_compex_inst_1_2_6 (
    .clk        ( clk ),
    .in_id0     ( lvl0_id[2] ),
    .in_data0   ( lvl0_data[2] ),
    .in_id1     ( lvl0_id[6] ),
    .in_data1   ( lvl0_data[6] ),
    .out_id0    ( lvl1_id[2] ),
    .out_data0  ( lvl1_data[2] ),
    .out_id1    ( lvl1_id[6] ),
    .out_data1  ( lvl1_data[6] )
);

// level 1: compex(3,7)
dlsc_sortnet_compex #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( PIPELINE )
) dlsc_sortnet_compex_inst_1_3_7 (
    .clk        ( clk ),
    .in_id0     ( lvl0_id[3] ),
    .in_data0   ( lvl0_data[3] ),
    .in_id1     ( lvl0_id[7] ),
    .in_data1   ( lvl0_data[7] ),
    .out_id0    ( lvl1_id[3] ),
    .out_data0  ( lvl1_data[3] ),
    .out_id1    ( lvl1_id[7] ),
    .out_data1  ( lvl1_data[7] )
);


// ** level 2 **
// [[2,4],[3,5]]

wire    [ID-1:0]    lvl2_id [7:0];
wire    [DATA-1:0]  lvl2_data [7:0];

// level 2: compex(2,4)
dlsc_sortnet_compex #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( PIPELINE )
) dlsc_sortnet_compex_inst_2_2_4 (
    .clk        ( clk ),
    .in_id0     ( lvl1_id[2] ),
    .in_data0   ( lvl1_data[2] ),
    .in_id1     ( lvl1_id[4] ),
    .in_data1   ( lvl1_data[4] ),
    .out_id0    ( lvl2_id[2] ),
    .out_data0  ( lvl2_data[2] ),
    .out_id1    ( lvl2_id[4] ),
    .out_data1  ( lvl2_data[4] )
);

// level 2: compex(3,5)
dlsc_sortnet_compex #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( PIPELINE )
) dlsc_sortnet_compex_inst_2_3_5 (
    .clk        ( clk ),
    .in_id0     ( lvl1_id[3] ),
    .in_data0   ( lvl1_data[3] ),
    .in_id1     ( lvl1_id[5] ),
    .in_data1   ( lvl1_data[5] ),
    .out_id0    ( lvl2_id[3] ),
    .out_data0  ( lvl2_data[3] ),
    .out_id1    ( lvl2_id[5] ),
    .out_data1  ( lvl2_data[5] )
);

// level 2: pass-through 0
dlsc_sortnet_passthrough #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( PIPELINE )
) dlsc_sortnet_passthrough_inst_2_0 (
    .clk        ( clk ),
    .in_id      ( lvl1_id[0] ),
    .in_data    ( lvl1_data[0] ),
    .out_id     ( lvl2_id[0] ),
    .out_data   ( lvl2_data[0] )
);

// level 2: pass-through 1
dlsc_sortnet_passthrough #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( PIPELINE )
) dlsc_sortnet_passthrough_inst_2_1 (
    .clk        ( clk ),
    .in_id      ( lvl1_id[1] ),
    .in_data    ( lvl1_data[1] ),
    .out_id     ( lvl2_id[1] ),
    .out_data   ( lvl2_data[1] )
);

// level 2: pass-through 6
dlsc_sortnet_passthrough #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( PIPELINE )
) dlsc_sortnet_passthrough_inst_2_6 (
    .clk        ( clk ),
    .in_id      ( lvl1_id[6] ),
    .in_data    ( lvl1_data[6] ),
    .out_id     ( lvl2_id[6] ),
    .out_data   ( lvl2_data[6] )
);

// level 2: pass-through 7
dlsc_sortnet_passthrough #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( PIPELINE )
) dlsc_sortnet_passthrough_inst_2_7 (
    .clk        ( clk ),
    .in_id      ( lvl1_id[7] ),
    .in_data    ( lvl1_data[7] ),
    .out_id     ( lvl2_id[7] ),
    .out_data   ( lvl2_data[7] )
);


// ** level 3 **
// [[1,2],[3,4],[5,6]]

wire    [ID-1:0]    lvl3_id [7:0];
wire    [DATA-1:0]  lvl3_data [7:0];

// level 3: compex(1,2)
dlsc_sortnet_compex #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( 1 )
) dlsc_sortnet_compex_inst_3_1_2 (
    .clk        ( clk ),
    .in_id0     ( lvl2_id[1] ),
    .in_data0   ( lvl2_data[1] ),
    .in_id1     ( lvl2_id[2] ),
    .in_data1   ( lvl2_data[2] ),
    .out_id0    ( lvl3_id[1] ),
    .out_data0  ( lvl3_data[1] ),
    .out_id1    ( lvl3_id[2] ),
    .out_data1  ( lvl3_data[2] )
);

// level 3: compex(3,4)
dlsc_sortnet_compex #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( 1 )
) dlsc_sortnet_compex_inst_3_3_4 (
    .clk        ( clk ),
    .in_id0     ( lvl2_id[3] ),
    .in_data0   ( lvl2_data[3] ),
    .in_id1     ( lvl2_id[4] ),
    .in_data1   ( lvl2_data[4] ),
    .out_id0    ( lvl3_id[3] ),
    .out_data0  ( lvl3_data[3] ),
    .out_id1    ( lvl3_id[4] ),
    .out_data1  ( lvl3_data[4] )
);

// level 3: compex(5,6)
dlsc_sortnet_compex #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( 1 )
) dlsc_sortnet_compex_inst_3_5_6 (
    .clk        ( clk ),
    .in_id0     ( lvl2_id[5] ),
    .in_data0   ( lvl2_data[5] ),
    .in_id1     ( lvl2_id[6] ),
    .in_data1   ( lvl2_data[6] ),
    .out_id0    ( lvl3_id[5] ),
    .out_data0  ( lvl3_data[5] ),
    .out_id1    ( lvl3_id[6] ),
    .out_data1  ( lvl3_data[6] )
);

// level 3: pass-through 0
dlsc_sortnet_passthrough #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( 1 )
) dlsc_sortnet_passthrough_inst_3_0 (
    .clk        ( clk ),
    .in_id      ( lvl2_id[0] ),
    .in_data    ( lvl2_data[0] ),
    .out_id     ( lvl3_id[0] ),
    .out_data   ( lvl3_data[0] )
);

// level 3: pass-through 7
dlsc_sortnet_passthrough #(
    .DATA       ( DATA ),
    .ID         ( ID ),
    .PIPELINE   ( 1 )
) dlsc_sortnet_passthrough_inst_3_7 (
    .clk        ( clk ),
    .in_id      ( lvl2_id[7] ),
    .in_data    ( lvl2_data[7] ),
    .out_id     ( lvl3_id[7] ),
    .out_data   ( lvl3_data[7] )
);


// ** outputs **
assign out_id  [ (0*  ID) +:   ID ] = lvl3_id[0];
assign out_data[ (0*DATA) +: DATA ] = lvl3_data[0];
assign out_id  [ (1*  ID) +:   ID ] = lvl3_id[1];
assign out_data[ (1*DATA) +: DATA ] = lvl3_data[1];
assign out_id  [ (2*  ID) +:   ID ] = lvl3_id[2];
assign out_data[ (2*DATA) +: DATA ] = lvl3_data[2];
assign out_id  [ (3*  ID) +:   ID ] = lvl3_id[3];
assign out_data[ (3*DATA) +: DATA ] = lvl3_data[3];
assign out_id  [ (4*  ID) +:   ID ] = lvl3_id[4];
assign out_data[ (4*DATA) +: DATA ] = lvl3_data[4];
assign out_id  [ (5*  ID) +:   ID ] = lvl3_id[5];
assign out_data[ (5*DATA) +: DATA ] = lvl3_data[5];
assign out_id  [ (6*  ID) +:   ID ] = lvl3_id[6];
assign out_data[ (6*DATA) +: DATA ] = lvl3_data[6];
assign out_id  [ (7*  ID) +:   ID ] = lvl3_id[7];
assign out_data[ (7*DATA) +: DATA ] = lvl3_data[7];


// ** delay valid/meta **
dlsc_pipedelay_valid #(
    .DATA       ( META ),
    .DELAY      ( 2 * (PIPELINE?2:1) + 2 ) // 1 or 2 cycles per intermediate stage; last stage always takes 2
) dlsc_pipedelay_valid_inst (
    .clk        ( clk ),
    .clk_en     ( 1'b1 ),
    .rst        ( rst ),
    .in_valid   ( in_valid ),
    .in_data    ( in_meta ),
    .out_valid  ( out_valid ),
    .out_data   ( out_meta )
);

endmodule


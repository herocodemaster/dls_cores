
module dlsc_axi_router_tb #(
    parameter ADDR              = 32,           // address bits
    parameter DATA              = 32,           // data bits
    parameter STRB              = (DATA/8),     // strobe bits (derived; don't touch)
    parameter LEN               = 4,            // length bits
    parameter BUFFER            = 1,            // enable extra buffering
    parameter FAST_COMMAND      = 0,            // enable back-to-back commands
    parameter MOT               = 16,           // maximum outstanding transactions (not a hard limit)
    parameter LANES             = 1,            // number of internal data lanes
    parameter INPUTS            = 1,            // number of inputs (from masters; <= 5)
    parameter OUTPUTS           = 1             // number of outputs (to slaves; <= 3)
) (

/* verilator lint_off UNDRIVEN */
/* verilator coverage_off */

    // System
    input   wire                            clk,
    input   wire                            rst,

    // ** Input 0 **
    
    // Read command
    output  wire                in0_ar_ready,
    input   wire                in0_ar_valid,
    input   wire    [ADDR-1:0]  in0_ar_addr,
    input   wire    [LEN-1:0]   in0_ar_len,

    // Read data
    input   wire                in0_r_ready,
    output  wire                in0_r_valid,
    output  wire                in0_r_last,
    output  wire    [DATA-1:0]  in0_r_data,
    output  wire    [1:0]       in0_r_resp,
    
    // Write command
    output  wire                in0_aw_ready,
    input   wire                in0_aw_valid,
    input   wire    [ADDR-1:0]  in0_aw_addr,
    input   wire    [LEN-1:0]   in0_aw_len,

    // Write data
    output  wire                in0_w_ready,
    input   wire                in0_w_valid,
    input   wire                in0_w_last,
    input   wire    [DATA-1:0]  in0_w_data,
    input   wire    [STRB-1:0]  in0_w_strb,

    // Write response
    input   wire                in0_b_ready,
    output  wire                in0_b_valid,
    output  wire    [1:0]       in0_b_resp,

    // ** Input 1 **
    
    // Read command
    output  wire                in1_ar_ready,
    input   wire                in1_ar_valid,
    input   wire    [ADDR-1:0]  in1_ar_addr,
    input   wire    [LEN-1:0]   in1_ar_len,

    // Read data
    input   wire                in1_r_ready,
    output  wire                in1_r_valid,
    output  wire                in1_r_last,
    output  wire    [DATA-1:0]  in1_r_data,
    output  wire    [1:0]       in1_r_resp,
    
    // Write command
    output  wire                in1_aw_ready,
    input   wire                in1_aw_valid,
    input   wire    [ADDR-1:0]  in1_aw_addr,
    input   wire    [LEN-1:0]   in1_aw_len,

    // Write data
    output  wire                in1_w_ready,
    input   wire                in1_w_valid,
    input   wire                in1_w_last,
    input   wire    [DATA-1:0]  in1_w_data,
    input   wire    [STRB-1:0]  in1_w_strb,

    // Write response
    input   wire                in1_b_ready,
    output  wire                in1_b_valid,
    output  wire    [1:0]       in1_b_resp,

    // ** Input 2 **
    
    // Read command
    output  wire                in2_ar_ready,
    input   wire                in2_ar_valid,
    input   wire    [ADDR-1:0]  in2_ar_addr,
    input   wire    [LEN-1:0]   in2_ar_len,

    // Read data
    input   wire                in2_r_ready,
    output  wire                in2_r_valid,
    output  wire                in2_r_last,
    output  wire    [DATA-1:0]  in2_r_data,
    output  wire    [1:0]       in2_r_resp,
    
    // Write command
    output  wire                in2_aw_ready,
    input   wire                in2_aw_valid,
    input   wire    [ADDR-1:0]  in2_aw_addr,
    input   wire    [LEN-1:0]   in2_aw_len,

    // Write data
    output  wire                in2_w_ready,
    input   wire                in2_w_valid,
    input   wire                in2_w_last,
    input   wire    [DATA-1:0]  in2_w_data,
    input   wire    [STRB-1:0]  in2_w_strb,

    // Write response
    input   wire                in2_b_ready,
    output  wire                in2_b_valid,
    output  wire    [1:0]       in2_b_resp,

    // ** Input 3 **
    
    // Read command
    output  wire                in3_ar_ready,
    input   wire                in3_ar_valid,
    input   wire    [ADDR-1:0]  in3_ar_addr,
    input   wire    [LEN-1:0]   in3_ar_len,

    // Read data
    input   wire                in3_r_ready,
    output  wire                in3_r_valid,
    output  wire                in3_r_last,
    output  wire    [DATA-1:0]  in3_r_data,
    output  wire    [1:0]       in3_r_resp,
    
    // Write command
    output  wire                in3_aw_ready,
    input   wire                in3_aw_valid,
    input   wire    [ADDR-1:0]  in3_aw_addr,
    input   wire    [LEN-1:0]   in3_aw_len,

    // Write data
    output  wire                in3_w_ready,
    input   wire                in3_w_valid,
    input   wire                in3_w_last,
    input   wire    [DATA-1:0]  in3_w_data,
    input   wire    [STRB-1:0]  in3_w_strb,

    // Write response
    input   wire                in3_b_ready,
    output  wire                in3_b_valid,
    output  wire    [1:0]       in3_b_resp,

    // ** Input 4 **
    
    // Read command
    output  wire                in4_ar_ready,
    input   wire                in4_ar_valid,
    input   wire    [ADDR-1:0]  in4_ar_addr,
    input   wire    [LEN-1:0]   in4_ar_len,

    // Read data
    input   wire                in4_r_ready,
    output  wire                in4_r_valid,
    output  wire                in4_r_last,
    output  wire    [DATA-1:0]  in4_r_data,
    output  wire    [1:0]       in4_r_resp,
    
    // Write command
    output  wire                in4_aw_ready,
    input   wire                in4_aw_valid,
    input   wire    [ADDR-1:0]  in4_aw_addr,
    input   wire    [LEN-1:0]   in4_aw_len,

    // Write data
    output  wire                in4_w_ready,
    input   wire                in4_w_valid,
    input   wire                in4_w_last,
    input   wire    [DATA-1:0]  in4_w_data,
    input   wire    [STRB-1:0]  in4_w_strb,

    // Write response
    input   wire                in4_b_ready,
    output  wire                in4_b_valid,
    output  wire    [1:0]       in4_b_resp,

    // ** Output 0 **
    
    // Read command
    input   wire                out0_ar_ready,
    output  wire                out0_ar_valid,
    output  wire    [ADDR-1:0]  out0_ar_addr,
    output  wire    [LEN-1:0]   out0_ar_len,

    // Read data
    output  wire                out0_r_ready,
    input   wire                out0_r_valid,
    input   wire                out0_r_last,
    input   wire    [DATA-1:0]  out0_r_data,
    input   wire    [1:0]       out0_r_resp,
    
    // Write command
    input   wire                out0_aw_ready,
    output  wire                out0_aw_valid,
    output  wire    [ADDR-1:0]  out0_aw_addr,
    output  wire    [LEN-1:0]   out0_aw_len,

    // Write data
    input   wire                out0_w_ready,
    output  wire                out0_w_valid,
    output  wire                out0_w_last,
    output  wire    [DATA-1:0]  out0_w_data,
    output  wire    [STRB-1:0]  out0_w_strb,

    // Write response
    output  wire                out0_b_ready,
    input   wire                out0_b_valid,
    input   wire    [1:0]       out0_b_resp,

    // ** Output 1 **
    
    // Read command
    input   wire                out1_ar_ready,
    output  wire                out1_ar_valid,
    output  wire    [ADDR-1:0]  out1_ar_addr,
    output  wire    [LEN-1:0]   out1_ar_len,

    // Read data
    output  wire                out1_r_ready,
    input   wire                out1_r_valid,
    input   wire                out1_r_last,
    input   wire    [DATA-1:0]  out1_r_data,
    input   wire    [1:0]       out1_r_resp,
    
    // Write command
    input   wire                out1_aw_ready,
    output  wire                out1_aw_valid,
    output  wire    [ADDR-1:0]  out1_aw_addr,
    output  wire    [LEN-1:0]   out1_aw_len,

    // Write data
    input   wire                out1_w_ready,
    output  wire                out1_w_valid,
    output  wire                out1_w_last,
    output  wire    [DATA-1:0]  out1_w_data,
    output  wire    [STRB-1:0]  out1_w_strb,

    // Write response
    output  wire                out1_b_ready,
    input   wire                out1_b_valid,
    input   wire    [1:0]       out1_b_resp,

    // ** Output 2 **
    
    // Read command
    input   wire                out2_ar_ready,
    output  wire                out2_ar_valid,
    output  wire    [ADDR-1:0]  out2_ar_addr,
    output  wire    [LEN-1:0]   out2_ar_len,

    // Read data
    output  wire                out2_r_ready,
    input   wire                out2_r_valid,
    input   wire                out2_r_last,
    input   wire    [DATA-1:0]  out2_r_data,
    input   wire    [1:0]       out2_r_resp,
    
    // Write command
    input   wire                out2_aw_ready,
    output  wire                out2_aw_valid,
    output  wire    [ADDR-1:0]  out2_aw_addr,
    output  wire    [LEN-1:0]   out2_aw_len,

    // Write data
    input   wire                out2_w_ready,
    output  wire                out2_w_valid,
    output  wire                out2_w_last,
    output  wire    [DATA-1:0]  out2_w_data,
    output  wire    [STRB-1:0]  out2_w_strb,

    // Write response
    output  wire                out2_b_ready,
    input   wire                out2_b_valid,
    input   wire    [1:0]       out2_b_resp
);

// ** AXI inputs ** (from masters)
    
// Read command
wire    [  INPUTS      -1:0]    in_ar_ready;
wire    [  INPUTS      -1:0]    in_ar_valid;
wire    [( INPUTS*ADDR)-1:0]    in_ar_addr;
wire    [( INPUTS*LEN )-1:0]    in_ar_len;

// Read data
wire    [  INPUTS      -1:0]    in_r_ready;
wire    [  INPUTS      -1:0]    in_r_valid;
wire    [  INPUTS      -1:0]    in_r_last;
wire    [( INPUTS*DATA)-1:0]    in_r_data;
wire    [( INPUTS*2   )-1:0]    in_r_resp;
    
// Write command
wire    [  INPUTS      -1:0]    in_aw_ready;
wire    [  INPUTS      -1:0]    in_aw_valid;
wire    [( INPUTS*ADDR)-1:0]    in_aw_addr;
wire    [( INPUTS*LEN )-1:0]    in_aw_len;

// Write data
wire    [  INPUTS      -1:0]    in_w_ready;
wire    [  INPUTS      -1:0]    in_w_valid;
wire    [  INPUTS      -1:0]    in_w_last;
wire    [( INPUTS*DATA)-1:0]    in_w_data;
wire    [( INPUTS*STRB)-1:0]    in_w_strb;

// Write response
wire    [  INPUTS      -1:0]    in_b_ready;
wire    [  INPUTS      -1:0]    in_b_valid;
wire    [( INPUTS*2   )-1:0]    in_b_resp;

// ** AXI outputs ** (to slaves)
    
// Read command
wire    [ OUTPUTS      -1:0]    out_ar_ready;
wire    [ OUTPUTS      -1:0]    out_ar_valid;
wire    [(OUTPUTS*ADDR)-1:0]    out_ar_addr;
wire    [(OUTPUTS*LEN )-1:0]    out_ar_len;

// Read data
wire    [ OUTPUTS      -1:0]    out_r_ready;
wire    [ OUTPUTS      -1:0]    out_r_valid;
wire    [ OUTPUTS      -1:0]    out_r_last;
wire    [(OUTPUTS*DATA)-1:0]    out_r_data;
wire    [(OUTPUTS*2   )-1:0]    out_r_resp;
    
// Write command
wire    [ OUTPUTS      -1:0]    out_aw_ready;
wire    [ OUTPUTS      -1:0]    out_aw_valid;
wire    [(OUTPUTS*ADDR)-1:0]    out_aw_addr;
wire    [(OUTPUTS*LEN )-1:0]    out_aw_len;

// Write data
wire    [ OUTPUTS      -1:0]    out_w_ready;
wire    [ OUTPUTS      -1:0]    out_w_valid;
wire    [ OUTPUTS      -1:0]    out_w_last;
wire    [(OUTPUTS*DATA)-1:0]    out_w_data;
wire    [(OUTPUTS*STRB)-1:0]    out_w_strb;

// Write response
wire    [ OUTPUTS      -1:0]    out_b_ready;
wire    [ OUTPUTS      -1:0]    out_b_valid;
wire    [(OUTPUTS*2   )-1:0]    out_b_resp;

generate
if(INPUTS>0) begin:GEN_INPUT_0
    assign in0_ar_ready                     = in_ar_ready[0];
    assign in_ar_valid[0]                   = in0_ar_valid;
    assign in_ar_addr[ (0*ADDR) +: ADDR ]   = in0_ar_addr;
    assign in_ar_len [ (0*LEN ) +: LEN  ]   = in0_ar_len;

    assign in_r_ready[0]                    = in0_r_ready;
    assign in0_r_valid                      = in_r_valid[0];
    assign in0_r_last                       = in_r_last[0];
    assign in0_r_data                       = in_r_data[ (0*DATA) +: DATA ];
    assign in0_r_resp                       = in_r_resp[ (0*2   ) +: 2    ];

    assign in0_aw_ready                     = in_aw_ready[0];
    assign in_aw_valid[0]                   = in0_aw_valid;
    assign in_aw_addr[ (0*ADDR) +: ADDR ]   = in0_aw_addr;
    assign in_aw_len [ (0*LEN ) +: LEN  ]   = in0_aw_len;

    assign in0_w_ready                      = in_w_ready[0];
    assign in_w_valid[0]                    = in0_w_valid;
    assign in_w_last[0]                     = in0_w_last;
    assign in_w_data[ (0*DATA) +: DATA ]    = in0_w_data;
    assign in_w_strb[ (0*STRB) +: STRB ]    = in0_w_strb;

    assign in_b_ready[0]                    = in0_b_ready;
    assign in0_b_valid                      = in_b_valid[0];
    assign in0_b_resp                       = in_b_resp[ (0*2   ) +: 2    ];
end
if(INPUTS>1) begin:GEN_INPUT_1
    assign in1_ar_ready                     = in_ar_ready[1];
    assign in_ar_valid[1]                   = in1_ar_valid;
    assign in_ar_addr[ (1*ADDR) +: ADDR ]   = in1_ar_addr;
    assign in_ar_len [ (1*LEN ) +: LEN  ]   = in1_ar_len;

    assign in_r_ready[1]                    = in1_r_ready;
    assign in1_r_valid                      = in_r_valid[1];
    assign in1_r_last                       = in_r_last[1];
    assign in1_r_data                       = in_r_data[ (1*DATA) +: DATA ];
    assign in1_r_resp                       = in_r_resp[ (1*2   ) +: 2    ];

    assign in1_aw_ready                     = in_aw_ready[1];
    assign in_aw_valid[1]                   = in1_aw_valid;
    assign in_aw_addr[ (1*ADDR) +: ADDR ]   = in1_aw_addr;
    assign in_aw_len [ (1*LEN ) +: LEN  ]   = in1_aw_len;

    assign in1_w_ready                      = in_w_ready[1];
    assign in_w_valid[1]                    = in1_w_valid;
    assign in_w_last[1]                     = in1_w_last;
    assign in_w_data[ (1*DATA) +: DATA ]    = in1_w_data;
    assign in_w_strb[ (1*STRB) +: STRB ]    = in1_w_strb;

    assign in_b_ready[1]                    = in1_b_ready;
    assign in1_b_valid                      = in_b_valid[1];
    assign in1_b_resp                       = in_b_resp[ (1*2   ) +: 2    ];
end
if(INPUTS>2) begin:GEN_INPUT_2
    assign in2_ar_ready                     = in_ar_ready[2];
    assign in_ar_valid[2]                   = in2_ar_valid;
    assign in_ar_addr[ (2*ADDR) +: ADDR ]   = in2_ar_addr;
    assign in_ar_len [ (2*LEN ) +: LEN  ]   = in2_ar_len;

    assign in_r_ready[2]                    = in2_r_ready;
    assign in2_r_valid                      = in_r_valid[2];
    assign in2_r_last                       = in_r_last[2];
    assign in2_r_data                       = in_r_data[ (2*DATA) +: DATA ];
    assign in2_r_resp                       = in_r_resp[ (2*2   ) +: 2    ];

    assign in2_aw_ready                     = in_aw_ready[2];
    assign in_aw_valid[2]                   = in2_aw_valid;
    assign in_aw_addr[ (2*ADDR) +: ADDR ]   = in2_aw_addr;
    assign in_aw_len [ (2*LEN ) +: LEN  ]   = in2_aw_len;

    assign in2_w_ready                      = in_w_ready[2];
    assign in_w_valid[2]                    = in2_w_valid;
    assign in_w_last[2]                     = in2_w_last;
    assign in_w_data[ (2*DATA) +: DATA ]    = in2_w_data;
    assign in_w_strb[ (2*STRB) +: STRB ]    = in2_w_strb;

    assign in_b_ready[2]                    = in2_b_ready;
    assign in2_b_valid                      = in_b_valid[2];
    assign in2_b_resp                       = in_b_resp[ (2*2   ) +: 2    ];
end
if(INPUTS>3) begin:GEN_INPUT_3
    assign in3_ar_ready                     = in_ar_ready[3];
    assign in_ar_valid[3]                   = in3_ar_valid;
    assign in_ar_addr[ (3*ADDR) +: ADDR ]   = in3_ar_addr;
    assign in_ar_len [ (3*LEN ) +: LEN  ]   = in3_ar_len;

    assign in_r_ready[3]                    = in3_r_ready;
    assign in3_r_valid                      = in_r_valid[3];
    assign in3_r_last                       = in_r_last[3];
    assign in3_r_data                       = in_r_data[ (3*DATA) +: DATA ];
    assign in3_r_resp                       = in_r_resp[ (3*2   ) +: 2    ];

    assign in3_aw_ready                     = in_aw_ready[3];
    assign in_aw_valid[3]                   = in3_aw_valid;
    assign in_aw_addr[ (3*ADDR) +: ADDR ]   = in3_aw_addr;
    assign in_aw_len [ (3*LEN ) +: LEN  ]   = in3_aw_len;

    assign in3_w_ready                      = in_w_ready[3];
    assign in_w_valid[3]                    = in3_w_valid;
    assign in_w_last[3]                     = in3_w_last;
    assign in_w_data[ (3*DATA) +: DATA ]    = in3_w_data;
    assign in_w_strb[ (3*STRB) +: STRB ]    = in3_w_strb;

    assign in_b_ready[3]                    = in3_b_ready;
    assign in3_b_valid                      = in_b_valid[3];
    assign in3_b_resp                       = in_b_resp[ (3*2   ) +: 2    ];
end
if(INPUTS>4) begin:GEN_INPUT_4
    assign in4_ar_ready                     = in_ar_ready[4];
    assign in_ar_valid[4]                   = in4_ar_valid;
    assign in_ar_addr[ (4*ADDR) +: ADDR ]   = in4_ar_addr;
    assign in_ar_len [ (4*LEN ) +: LEN  ]   = in4_ar_len;

    assign in_r_ready[4]                    = in4_r_ready;
    assign in4_r_valid                      = in_r_valid[4];
    assign in4_r_last                       = in_r_last[4];
    assign in4_r_data                       = in_r_data[ (4*DATA) +: DATA ];
    assign in4_r_resp                       = in_r_resp[ (4*2   ) +: 2    ];

    assign in4_aw_ready                     = in_aw_ready[4];
    assign in_aw_valid[4]                   = in4_aw_valid;
    assign in_aw_addr[ (4*ADDR) +: ADDR ]   = in4_aw_addr;
    assign in_aw_len [ (4*LEN ) +: LEN  ]   = in4_aw_len;

    assign in4_w_ready                      = in_w_ready[4];
    assign in_w_valid[4]                    = in4_w_valid;
    assign in_w_last[4]                     = in4_w_last;
    assign in_w_data[ (4*DATA) +: DATA ]    = in4_w_data;
    assign in_w_strb[ (4*STRB) +: STRB ]    = in4_w_strb;

    assign in_b_ready[4]                    = in4_b_ready;
    assign in4_b_valid                      = in_b_valid[4];
    assign in4_b_resp                       = in_b_resp[ (4*2   ) +: 2    ];
end
if(OUTPUTS>0) begin:GEN_OUTPUT_0
    assign out_ar_ready[0]                  = out0_ar_ready;
    assign out0_ar_valid                    = out_ar_valid[0];
    assign out0_ar_addr                     = out_ar_addr[ (0*ADDR) +: ADDR ];
    assign out0_ar_len                      = out_ar_len [ (0*LEN ) +: LEN  ];

    assign out0_r_ready                     = out_r_ready[0];
    assign out_r_valid[0]                   = out0_r_valid;
    assign out_r_last[0]                    = out0_r_last;
    assign out_r_data[ (0*DATA) +: DATA ]   = out0_r_data;
    assign out_r_resp[ (0*2   ) +: 2    ]   = out0_r_resp;

    assign out_aw_ready[0]                  = out0_aw_ready;
    assign out0_aw_valid                    = out_aw_valid[0];
    assign out0_aw_addr                     = out_aw_addr[ (0*ADDR) +: ADDR ];
    assign out0_aw_len                      = out_aw_len [ (0*LEN ) +: LEN  ];

    assign out_w_ready[0]                   = out0_w_ready;
    assign out0_w_valid                     = out_w_valid[0];
    assign out0_w_last                      = out_w_last[0];
    assign out0_w_data                      = out_w_data[ (0*DATA) +: DATA ];
    assign out0_w_strb                      = out_w_strb[ (0*STRB) +: STRB ];

    assign out0_b_ready                     = out_b_ready[0];
    assign out_b_valid[0]                   = out0_b_valid;
    assign out_b_resp[ (0*2   ) +: 2    ]   = out0_b_resp;
end
if(OUTPUTS>1) begin:GEN_OUTPUT_1
    assign out_ar_ready[1]                  = out1_ar_ready;
    assign out1_ar_valid                    = out_ar_valid[1];
    assign out1_ar_addr                     = out_ar_addr[ (1*ADDR) +: ADDR ];
    assign out1_ar_len                      = out_ar_len [ (1*LEN ) +: LEN  ];

    assign out1_r_ready                     = out_r_ready[1];
    assign out_r_valid[1]                   = out1_r_valid;
    assign out_r_last[1]                    = out1_r_last;
    assign out_r_data[ (1*DATA) +: DATA ]   = out1_r_data;
    assign out_r_resp[ (1*2   ) +: 2    ]   = out1_r_resp;

    assign out_aw_ready[1]                  = out1_aw_ready;
    assign out1_aw_valid                    = out_aw_valid[1];
    assign out1_aw_addr                     = out_aw_addr[ (1*ADDR) +: ADDR ];
    assign out1_aw_len                      = out_aw_len [ (1*LEN ) +: LEN  ];

    assign out_w_ready[1]                   = out1_w_ready;
    assign out1_w_valid                     = out_w_valid[1];
    assign out1_w_last                      = out_w_last[1];
    assign out1_w_data                      = out_w_data[ (1*DATA) +: DATA ];
    assign out1_w_strb                      = out_w_strb[ (1*STRB) +: STRB ];

    assign out1_b_ready                     = out_b_ready[1];
    assign out_b_valid[1]                   = out1_b_valid;
    assign out_b_resp[ (1*2   ) +: 2    ]   = out1_b_resp;
end
if(OUTPUTS>2) begin:GEN_OUTPUT_2
    assign out_ar_ready[2]                  = out2_ar_ready;
    assign out2_ar_valid                    = out_ar_valid[2];
    assign out2_ar_addr                     = out_ar_addr[ (2*ADDR) +: ADDR ];
    assign out2_ar_len                      = out_ar_len [ (2*LEN ) +: LEN  ];

    assign out2_r_ready                     = out_r_ready[2];
    assign out_r_valid[2]                   = out2_r_valid;
    assign out_r_last[2]                    = out2_r_last;
    assign out_r_data[ (2*DATA) +: DATA ]   = out2_r_data;
    assign out_r_resp[ (2*2   ) +: 2    ]   = out2_r_resp;

    assign out_aw_ready[2]                  = out2_aw_ready;
    assign out2_aw_valid                    = out_aw_valid[2];
    assign out2_aw_addr                     = out_aw_addr[ (2*ADDR) +: ADDR ];
    assign out2_aw_len                      = out_aw_len [ (2*LEN ) +: LEN  ];

    assign out_w_ready[2]                   = out2_w_ready;
    assign out2_w_valid                     = out_w_valid[2];
    assign out2_w_last                      = out_w_last[2];
    assign out2_w_data                      = out_w_data[ (2*DATA) +: DATA ];
    assign out2_w_strb                      = out_w_strb[ (2*STRB) +: STRB ];

    assign out2_b_ready                     = out_b_ready[2];
    assign out_b_valid[2]                   = out2_b_valid;
    assign out_b_resp[ (2*2   ) +: 2    ]   = out2_b_resp;
end
endgenerate

/* verilator lint_off WIDTH */
localparam [(OUTPUTS*ADDR)-1:0] MASKS = (OUTPUTS>2) ? { 32'hFFFFFFFF, 32'hFFFFCFFF, 32'hFFFFCFFF } :
                                        (OUTPUTS>1) ? {               32'hFFFFFFFF, 32'hFFFFEFFF } :    // interleave on 4K boundaries
                                                      {                             32'hFFFFFFFF };
localparam [(OUTPUTS*ADDR)-1:0] BASES = (OUTPUTS>2) ? { 32'h00000000, 32'h00001000, 32'h00002000 } :
                                        (OUTPUTS>1) ? {               32'h00000000, 32'h00001000 } :
                                                      {                             32'h00000000 };
/* verilator lint_on WIDTH */

dlsc_axi_router_rd #(
    .ADDR       ( ADDR ),
    .DATA       ( DATA ),
    .LEN        ( LEN ),
    .BUFFER     ( BUFFER ),
    .FAST_COMMAND ( FAST_COMMAND ),
    .MOT        ( MOT ),
    .LANES      ( LANES ),
    .INPUTS     ( INPUTS ),
    .OUTPUTS    ( OUTPUTS ),
    .MASKS      ( MASKS ),
    .BASES      ( BASES )
) dlsc_axi_router_rd_inst (
    .clk ( clk ),
    .rst ( rst ),
    .in_ar_ready ( in_ar_ready ),
    .in_ar_valid ( in_ar_valid ),
    .in_ar_addr ( in_ar_addr ),
    .in_ar_len ( in_ar_len ),
    .in_r_ready ( in_r_ready ),
    .in_r_valid ( in_r_valid ),
    .in_r_last ( in_r_last ),
    .in_r_data ( in_r_data ),
    .in_r_resp ( in_r_resp ),
    .out_ar_ready ( out_ar_ready ),
    .out_ar_valid ( out_ar_valid ),
    .out_ar_addr ( out_ar_addr ),
    .out_ar_len ( out_ar_len ),
    .out_r_ready ( out_r_ready ),
    .out_r_valid ( out_r_valid ),
    .out_r_last ( out_r_last ),
    .out_r_data ( out_r_data ),
    .out_r_resp ( out_r_resp )
);

dlsc_axi_router_wr #(
    .ADDR       ( ADDR ),
    .DATA       ( DATA ),
    .LEN        ( LEN ),
    .BUFFER     ( BUFFER ),
    .FAST_COMMAND ( FAST_COMMAND ),
    .MOT        ( MOT ),
    .LANES      ( LANES ),
    .INPUTS     ( INPUTS ),
    .OUTPUTS    ( OUTPUTS ),
    .MASKS      ( MASKS ),
    .BASES      ( BASES )
) dlsc_axi_router_wr_inst (
    .clk ( clk ),
    .rst ( rst ),
    .in_aw_ready ( in_aw_ready ),
    .in_aw_valid ( in_aw_valid ),
    .in_aw_addr ( in_aw_addr ),
    .in_aw_len ( in_aw_len ),
    .in_w_ready ( in_w_ready ),
    .in_w_valid ( in_w_valid ),
    .in_w_last ( in_w_last ),
    .in_w_data ( in_w_data ),
    .in_w_strb ( in_w_strb ),
    .in_b_ready ( in_b_ready ),
    .in_b_valid ( in_b_valid ),
    .in_b_resp ( in_b_resp ),
    .out_aw_ready ( out_aw_ready ),
    .out_aw_valid ( out_aw_valid ),
    .out_aw_addr ( out_aw_addr ),
    .out_aw_len ( out_aw_len ),
    .out_w_ready ( out_w_ready ),
    .out_w_valid ( out_w_valid ),
    .out_w_last ( out_w_last ),
    .out_w_data ( out_w_data ),
    .out_w_strb ( out_w_strb ),
    .out_b_ready ( out_b_ready ),
    .out_b_valid ( out_b_valid ),
    .out_b_resp ( out_b_resp )
);

/* verilator coverage_on */
/* verilator lint_on UNDRIVEN */


endmodule


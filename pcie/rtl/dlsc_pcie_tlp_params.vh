
localparam
    FMT_3DW             = 2'b00,
    FMT_4DW             = 2'b01,
    FMT_3DW_DATA        = 2'b10,
    FMT_4DW_DATA        = 2'b11;

localparam
    TYPE_MEM            = 5'b0_0000,
    TYPE_MEM_LOCKED     = 5'b0_0001,
    TYPE_IO             = 5'b0_0010,
    TYPE_CONFIG_0       = 5'b0_0100,
    TYPE_CONFIG_1       = 5'b0_0101,
    TYPE_MSG_TO_RC      = 5'b1_0000,
    TYPE_MSG_BY_ADDR    = 5'b1_0001,
    TYPE_MSG_BY_ID      = 5'b1_0010,
    TYPE_MSG_FROM_RC    = 5'b1_0011,
    TYPE_MSG_LOCAL      = 5'b1_0100,
    TYPE_MSG_PME_RC     = 5'b1_0101,
    TYPE_CPL            = 5'b0_1010,
    TYPE_CPL_LOCKED     = 5'b0_1011;

localparam
    CPL_SC              = 3'b000,
    CPL_UR              = 3'b001,
    CPL_CRS             = 3'b010,
    CPL_CA              = 3'b100;


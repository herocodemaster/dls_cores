
`timescale 1ns/1ps

module tests;

`include "dlsc_sim.vh"
`include "dlsc_sp605_top_registers.vh"

// required by pci_exp_userapp_com:
reg [7:0]   expect_cpld_payload     [4095:0];
reg [7:0]   expect_memwr_payload    [4095:0];
reg [7:0]   expect_memwr64_payload  [4095:0];
reg         expect_finish_check;

task reg_read;
    input   [7:0]   device;
    input   [9:0]   index;
    output  [31:0]  data;
    reg     [63:0]  addr;
begin

    addr        = { board.RP.tx_usrapp.BAR_INIT_P_BAR[1][31:0],
                    board.RP.tx_usrapp.BAR_INIT_P_BAR[0][31:0] };
    addr[19:12] = device;
    addr[11: 2] = index;
    addr[ 1: 0] = 2'b00;

    board.RP.tx_usrapp.P_READ_DATA = 32'hFFFFFFFF;

    fork
        board.RP.tx_usrapp.TSK_TX_MEMORY_READ_64(
            board.RP.tx_usrapp.DEFAULT_TAG, // tag
            board.RP.tx_usrapp.DEFAULT_TC,  // traffic class
            10'd1,                          // length
            addr,                           // address
            4'h0,                           // last_be
            4'hF);                          // first_be

        board.RP.tx_usrapp.TSK_WAIT_FOR_READ_DATA;
    join

    data        = board.RP.tx_usrapp.P_READ_DATA;

    board.RP.tx_usrapp.TSK_TX_CLK_EAT(10);
    board.RP.tx_usrapp.DEFAULT_TAG = board.RP.tx_usrapp.DEFAULT_TAG + 1;

    `dlsc_info("read 0x%0x from 0x%0x", data, addr);

end
endtask

task reg_write;
    input   [7:0]   device;
    input   [9:0]   index;
    input   [31:0]  data;
    reg     [63:0]  addr;
begin

    addr        = { board.RP.tx_usrapp.BAR_INIT_P_BAR[1][31:0],
                    board.RP.tx_usrapp.BAR_INIT_P_BAR[0][31:0] };
    addr[19:12] = device;
    addr[11: 2] = index;
    addr[ 1: 0] = 2'b00;

    board.RP.tx_usrapp.DATA_STORE[0] = data[ 7: 0];
    board.RP.tx_usrapp.DATA_STORE[1] = data[15: 8];
    board.RP.tx_usrapp.DATA_STORE[2] = data[23:16];
    board.RP.tx_usrapp.DATA_STORE[3] = data[31:24];

    board.RP.tx_usrapp.TSK_TX_MEMORY_WRITE_64(
        board.RP.tx_usrapp.DEFAULT_TAG, // tag
        board.RP.tx_usrapp.DEFAULT_TC,  // traffic class
        10'd1,                          // length
        addr,                           // address
        4'h0,                           // last_be
        4'hF,                           // first_be
        1'b0);                          // poison

    board.RP.tx_usrapp.TSK_TX_CLK_EAT(10);
    board.RP.tx_usrapp.DEFAULT_TAG = board.RP.tx_usrapp.DEFAULT_TAG + 1;

    `dlsc_info("wrote 0x%0x to 0x%0x", data, addr);

end
endtask

reg [31:0] d;

initial begin

    expect_finish_check = 0;

    `dlsc_info("TSK_SIMULATION_TIMEOUT");
    board.RP.tx_usrapp.TSK_SIMULATION_TIMEOUT(10050);
    `dlsc_info("TSK_SYSTEM_INITIALIZATION");
    board.RP.tx_usrapp.TSK_SYSTEM_INITIALIZATION;
    `dlsc_info("TSK_BAR_INIT");
    board.RP.tx_usrapp.TSK_BAR_INIT;
    `dlsc_info("init done");

    if(board.RP.tx_usrapp.BAR_INIT_P_BAR_ENABLED[0] == 2'b11) begin
        `dlsc_info("bar 0 is MEM64");
    end else begin
        `dlsc_error("bar 0 is not MEM64");
    end

    `dlsc_info("enabling dcm_clkgen");

    reg_write(REG_CLKGEN,REG_CLKGEN_CONTROL,32'h0);
    reg_write(REG_CLKGEN,REG_CLKGEN_MULTIPLY,57-1);
    reg_write(REG_CLKGEN,REG_CLKGEN_DIVIDE,43-1);
    reg_write(REG_CLKGEN,REG_CLKGEN_CONTROL,32'h1);

    d = 0;
    while( !d[0] ) begin
        reg_read(REG_CLKGEN,REG_CLKGEN_STATUS,d);
    end

    `dlsc_okay("dcm_clkgen enabled");

    #5000;

    `dlsc_finish;

end


endmodule


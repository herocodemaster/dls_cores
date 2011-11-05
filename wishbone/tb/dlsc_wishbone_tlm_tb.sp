//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"

/*AUTOSUBCELL_CLASS*/

#define WB_PIPELINE     PARAM_WB_PIPELINE


SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();
    
    dlsc_tlm_memtest<uint32_t> *memtest;

    dlsc_tlm_memory<uint32_t> *memory;

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/

public:

    /*AUTOMETHODS*/

};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

#include <algorithm>
#include <numeric>

#include <boost/shared_array.hpp>

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/

    SP_CELL(wb_master,dlsc_wishbone_tlm_master_32b);
        /*AUTOINST*/

    memtest = new dlsc_tlm_memtest<uint32_t>("memtest");
    memtest->socket.bind(wb_master->socket);

    SP_CELL(wb_slave,dlsc_wishbone_tlm_slave_32b);
        SP_PIN(wb_slave,wb_cyc_i,wb_cyc_o);
        SP_PIN(wb_slave,wb_stb_i,wb_stb_o);
        SP_PIN(wb_slave,wb_we_i,wb_we_o);
        SP_PIN(wb_slave,wb_adr_i,wb_adr_o);
        SP_PIN(wb_slave,wb_cti_i,wb_cti_o);
        SP_PIN(wb_slave,wb_dat_i,wb_dat_o);
        SP_PIN(wb_slave,wb_sel_i,wb_sel_o);
        SP_PIN(wb_slave,wb_stall_o,wb_stall_i);
        SP_PIN(wb_slave,wb_ack_o,wb_ack_i);
        SP_PIN(wb_slave,wb_err_o,wb_err_i);
        SP_PIN(wb_slave,wb_dat_o,wb_dat_i);
        /*AUTOINST*/

    memory = new dlsc_tlm_memory<uint32_t>("memory",4*1024*1024,0,sc_core::sc_time(2.5,SC_NS),sc_core::sc_time(20,SC_NS));

    wb_slave->socket.bind(memory->socket);

    wb_master->set_pipelined(WB_PIPELINE!=0);
    wb_slave->set_pipelined(WB_PIPELINE!=0);

    // allow a few errors
    memory->set_error_rate(1);
    memtest->set_ignore_error(true);

    rst         = 1;

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::stim_thread() {
    rst         = 1;
    wait(1,SC_US);
    wait(clk.posedge_event());
    rst         = 0;
    wait(clk.posedge_event());

    memtest->test(0,4*4096,1*1000*100);

    wait(1,SC_US);
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(100,SC_MS);

    dlsc_error("watchdog timeout");

    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/




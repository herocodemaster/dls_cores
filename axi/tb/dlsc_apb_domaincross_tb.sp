//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock in_clk;
    sc_clock out_clk;

    void rst_thread();
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

SP_CTOR_IMP(__MODULE__) : in_clk("in_clk",PARAM_M_CLK,SC_NS), out_clk("out_clk",PARAM_S_CLK,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    SP_CELL(apb_master,dlsc_apb_tlm_master_32b);
        SP_PIN(apb_master,clk,in_clk);
        SP_PIN(apb_master,rst,in_rst);
        SP_TEMPLATE(apb_master,"apb_(.*)","in_$1");
        /*AUTOINST*/

    memtest = new dlsc_tlm_memtest<uint32_t>("memtest");
    memtest->socket.bind(apb_master->socket);

    SP_CELL(apb_slave,dlsc_apb_tlm_slave_32b);
        SP_PIN(apb_slave,clk,out_clk);
        SP_PIN(apb_slave,rst,out_rst);
        SP_TEMPLATE(apb_slave,"apb_(.*)","out_$1");
        /*AUTOINST*/

    memory = new dlsc_tlm_memory<uint32_t>("memory",4*1024*1024,0,sc_core::sc_time(2.5,SC_NS),sc_core::sc_time(20,SC_NS));

    apb_slave->socket.bind(memory->socket);

    // allow a few errors
    memory->set_error_rate(1);
    memtest->set_ignore_error(true);

    SC_THREAD(rst_thread);
    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::rst_thread() {
    in_rst      = 1;
    out_rst     = 1;
    wait(1,SC_US);
    wait(in_clk.posedge_event());
    in_rst      = 0;
    wait(out_clk.posedge_event());
    out_rst     = 0;
    wait(in_clk.posedge_event());
    wait(out_clk.posedge_event());

    while(1) {
        wait(dlsc_rand_u32(1000,10000),SC_NS);
        if(dlsc_rand_bool(5.0)) {
            wait(out_clk.posedge_event());
            out_rst     = 1;
            wait(dlsc_rand_u32(PARAM_M_CLK*3,PARAM_M_CLK*15),SC_NS);
            wait(out_clk.posedge_event());
            out_rst     = 0;
        }
    }
}

void __MODULE__::stim_thread() {
    wait(2,SC_US);

    memtest->test(0,1024,1*1000*(100/std::max(PARAM_M_CLK,PARAM_S_CLK)));

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(100,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/




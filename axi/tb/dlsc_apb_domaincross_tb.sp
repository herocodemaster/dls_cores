//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"

/*AUTOSUBCELL_CLASS*/


SC_MODULE (__MODULE__) {
private:
    sc_clock m_clk;
    sc_clock s_clk;

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

SP_CTOR_IMP(__MODULE__) : m_clk("m_clk",PARAM_M_CLK,SC_NS), s_clk("s_clk",PARAM_S_CLK,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    SP_CELL(apb_master,dlsc_apb_tlm_master_32b);
        SP_PIN(apb_master,clk,m_clk);
        SP_PIN(apb_master,rst,m_rst);
        SP_TEMPLATE(apb_master,"apb_(.*)","m_apb_$1");
        /*AUTOINST*/

    memtest = new dlsc_tlm_memtest<uint32_t>("memtest");
    memtest->socket.bind(apb_master->socket);

    SP_CELL(apb_slave,dlsc_apb_tlm_slave_32b);
        SP_PIN(apb_slave,clk,s_clk);
        SP_PIN(apb_slave,rst,s_rst);
        SP_TEMPLATE(apb_slave,"apb_(.*)","s_apb_$1");
        /*AUTOINST*/

    memory = new dlsc_tlm_memory<uint32_t>("memory",4*1024*1024,0,sc_core::sc_time(2.5,SC_NS),sc_core::sc_time(20,SC_NS));

    apb_slave->socket.bind(memory->socket);

    // allow a few errors
    memory->set_error_rate(1);
    memtest->set_ignore_error(true);

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::stim_thread() {
    m_rst       = 1;
    s_rst       = 1;
    wait(1,SC_US);
    wait(m_clk.posedge_event());
    m_rst       = 0;
    wait(s_clk.posedge_event());
    s_rst       = 0;
    wait(m_clk.posedge_event());
    wait(s_clk.posedge_event());

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




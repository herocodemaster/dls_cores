//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"
#include "dlsc_tlm_channel.h"

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();
    
    dlsc_tlm_memtest<uint32_t> *memtest;

    dlsc_tlm_memory<uint32_t> *memory;

    dlsc_tlm_channel<uint32_t> *channel;

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
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    SP_CELL(axi_master,dlsc_axi4lb_tlm_master_32b);
        /*AUTOINST*/

    memtest = new dlsc_tlm_memtest<uint32_t>("memtest");

    SP_CELL(axi_slave,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/

    memory = new dlsc_tlm_memory<uint32_t>("memory",4*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(10,SC_NS));
        
    channel = new dlsc_tlm_channel<uint32_t>("channel");

    for(int i=0;i<4;++i) {
        memtest->socket.bind(channel->in_socket);
        channel->out_socket.bind(axi_master->socket);
        axi_slave->socket.bind(memory->socket);
    }

    // allow a few errors
    memory->set_error_rate(1);
    memtest->set_ignore_error(true);

    memtest->set_max_outstanding(16);
    channel->set_delay(sc_core::sc_time(0,SC_NS),sc_core::sc_time(2000,SC_NS));

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




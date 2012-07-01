//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"

// for syntax highlighter: SC_MODULE

/*AUTOSUBCELL_CLASS*/

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

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    SP_CELL(axi_master,dlsc_axi4lb_tlm_master_32b);
        /*AUTOINST*/

    memtest = new dlsc_tlm_memtest<uint32_t>("memtest",1);  // max burst-length of 1 (AXI-Lite doesn't support bursts)
    memtest->socket.bind(axi_master->socket);

    SP_CELL(csr_slave,dlsc_csr_tlm_slave_32b);
        /*AUTOINST*/

    memory = new dlsc_tlm_memory<uint32_t>("memory",4*1024*1024,0,sc_core::sc_time(2.5,SC_NS),sc_core::sc_time(20,SC_NS));

    csr_slave->socket.bind(memory->socket);

    // allow a few errors
    memory->set_error_rate(1);
    memtest->set_ignore_error(true);

    // only allow bus-wide all-or-nothing type strobes
    memtest->set_strobe_all(true);

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
    for(int i=0;i<100;i++) {
        wait(1,SC_MS);
        dlsc_info(".");
    }

    dlsc_error("watchdog timeout");

    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/


//######################################################################
#sp interface

#include <systemperl.h>

#include "dlsc_tlm_memtest.h"

/*AUTOSUBCELL_CLASS*/

#define SIZE PARAM_SIZE
#define DATA PARAM_DATA
#define ADDR PARAM_ADDR
#define LEN PARAM_LEN

#define STRB (DATA/8)

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();
    
    dlsc_tlm_memtest<uint32_t> *memtest;

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

    memtest = new dlsc_tlm_memtest<uint32_t>("memtest",(1<<LEN));
    memtest->socket.bind(axi_master->socket);

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

    memtest->test(0,SIZE/STRB,1*1000*100);

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




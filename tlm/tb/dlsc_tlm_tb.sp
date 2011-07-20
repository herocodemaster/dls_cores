//######################################################################
#sp interface

#include <systemperl.h>

#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
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

#define DLSC_NOT_VERILATED
#define DLSC_NOT_TRACED
#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) /*AUTOINIT*/ {
    SP_AUTO_CTOR;
    
    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    memtest = new dlsc_tlm_memtest<uint32_t>("memtest");
    
    memory = new dlsc_tlm_memory<uint32_t>("memory",128*1024*1024,0,sc_core::sc_time(10,SC_NS),sc_core::sc_time(10,SC_NS));
    
    memtest->socket.bind(memory->socket);
    memtest->socket.bind(memory->socket);
    memtest->socket.bind(memory->socket);
    memtest->socket.bind(memory->socket);

    SC_THREAD(stim_thread);
//    SC_THREAD(watchdog_thread);
}


void __MODULE__::stim_thread() {
    tlm::tlm_global_quantum::instance().set(sc_core::sc_time(1,SC_US));

    memtest->test(0,4*1024*256,1*1000*1000);

    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(1,SC_MS);

    dlsc_error("watchdog timeout");

    sc_stop();
}


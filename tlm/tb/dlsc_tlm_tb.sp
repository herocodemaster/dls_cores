//######################################################################
#sp interface

#include <systemperl.h>

#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"
#include "dlsc_tlm_channel.h"
#include "dlsc_tlm_fabric.h"

/*AUTOSUBCELL_CLASS*/

#if PARAM_REMOVE_ANNOTATION > 0
#define REMOVE_ANNOTATION true
#else
#define REMOVE_ANNOTATION false
#endif

SC_MODULE (__MODULE__) {
private:
    void stim_thread();
    void watchdog_thread();

    dlsc_tlm_memtest<uint32_t> *memtest;
    dlsc_tlm_memory<uint32_t> *memory;

    dlsc_tlm_channel<uint32_t> *channel;

    dlsc_tlm_fabric<uint32_t> *fabric;

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
    
    memory  = new dlsc_tlm_memory<uint32_t>("memory",128*1024*1024,0,sc_core::sc_time(10,SC_NS),sc_core::sc_time(10,SC_NS));

    channel = new dlsc_tlm_channel<uint32_t>("channel",REMOVE_ANNOTATION);

    fabric  = new dlsc_tlm_fabric<uint32_t>("fabric");
    
    memtest->socket.bind(channel->in_socket);
    channel->out_socket.bind(fabric->in_socket);

    memtest->socket.bind(fabric->in_socket);
    
    fabric->out_socket.bind(memory->socket);

    fabric->out_socket.bind(channel->in_socket);
    channel->out_socket.bind(memory->socket);
    
    memtest->socket.bind(memory->socket);
    memtest->socket.bind(memory->socket);

    fabric->set_map(0,0xFFFFF,0,0xFFFFF,0,true,false);

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}


void __MODULE__::stim_thread() {
    tlm::tlm_global_quantum::instance().set(sc_core::sc_time(1,SC_US));

    memtest->test(0,4*1024*256,1*1000*1000);

    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(1000,SC_MS);

    dlsc_error("watchdog timeout");

    sc_stop();
}


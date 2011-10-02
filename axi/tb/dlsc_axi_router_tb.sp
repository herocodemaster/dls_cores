//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"

/*AUTOSUBCELL_CLASS*/

#define ADDR    PARAM_ADDR
#define DATA    PARAM_DATA
#define LEN     PARAM_LEN
#define MOT     PARAM_MOT
#define INPUTS  PARAM_INPUTS
#define OUTPUTS PARAM_OUTPUTS

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();
    
    dlsc_tlm_initiator_nb<uint32_t> *initiator;
    typedef dlsc_tlm_initiator_nb<uint32_t>::transaction transaction;
    
    dlsc_tlm_memtest<uint32_t> *memtest;

    dlsc_tlm_memory<uint32_t> *memory0;
    dlsc_tlm_memory<uint32_t> *memory1;
    dlsc_tlm_memory<uint32_t> *memory2;

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

#define MEMTEST

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/


#ifdef MEMTEST
    memtest = new dlsc_tlm_memtest<uint32_t>("memtest",(1<<LEN));
    #define MASTER memtest
#else
    initiator = new dlsc_tlm_initiator_nb<uint32_t>("initiator",(1<<LEN));
    #define MASTER initiator
#endif

#if (INPUTS > 0)
    SP_CELL(axi_master0,dlsc_axi4lb_tlm_master_32b);
        /*AUTOINST*/
        SP_TEMPLATE(axi_master0,"axi_(.*)","in0_$1");
    MASTER->socket.bind(axi_master0->socket);
#endif
#if (INPUTS > 1)
    SP_CELL(axi_master1,dlsc_axi4lb_tlm_master_32b);
        /*AUTOINST*/
        SP_TEMPLATE(axi_master1,"axi_(.*)","in1_$1");
    MASTER->socket.bind(axi_master1->socket);
#endif
#if (INPUTS > 2)
    SP_CELL(axi_master2,dlsc_axi4lb_tlm_master_32b);
        /*AUTOINST*/
        SP_TEMPLATE(axi_master2,"axi_(.*)","in2_$1");
    MASTER->socket.bind(axi_master2->socket);
#endif
#if (INPUTS > 3)
    SP_CELL(axi_master3,dlsc_axi4lb_tlm_master_32b);
        /*AUTOINST*/
        SP_TEMPLATE(axi_master3,"axi_(.*)","in3_$1");
    MASTER->socket.bind(axi_master3->socket);
#endif
#if (INPUTS > 4)
    SP_CELL(axi_master4,dlsc_axi4lb_tlm_master_32b);
        /*AUTOINST*/
        SP_TEMPLATE(axi_master4,"axi_(.*)","in4_$1");
    MASTER->socket.bind(axi_master4->socket);
#endif

#if (OUTPUTS > 0)
    SP_CELL(axi_slave0,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/
        SP_TEMPLATE(axi_slave0,"axi_(.*)","out0_$1");
    memory0 = new dlsc_tlm_memory<uint32_t>("memory0",4*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(10,SC_NS));
    memory0->set_error_rate(1.0);
    axi_slave0->socket.bind(memory0->socket);
#endif
#if (OUTPUTS > 1)
    SP_CELL(axi_slave1,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/
        SP_TEMPLATE(axi_slave1,"axi_(.*)","out1_$1");
    memory1 = new dlsc_tlm_memory<uint32_t>("memory1",4*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(10,SC_NS));
    memory1->set_error_rate(1.0);
    axi_slave1->socket.bind(memory1->socket);
#endif
#if (OUTPUTS > 2)
    SP_CELL(axi_slave2,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/
        SP_TEMPLATE(axi_slave2,"axi_(.*)","out2_$1");
    memory2 = new dlsc_tlm_memory<uint32_t>("memory2",4*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(10,SC_NS));
    memory2->set_error_rate(1.0);
    axi_slave2->socket.bind(memory2->socket);
#endif

#ifdef MEMTEST
    memtest->set_ignore_error(true);
    memtest->set_max_outstanding(MOT*INPUTS*2);
#endif

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

#ifdef MEMTEST
    memtest->test(0,4*4096,1*1000*10);
#else
    transaction ts;
    std::deque<uint32_t> data;
    std::deque<uint32_t> strb;
    
    data.push_back(0x12345678);
    data.push_back(0xFEEDFACE);
    data.push_back(0xABCDEF98);
    initiator->nb_write(0x1000,data);

    initiator->nb_read(0x3000,13);
    initiator->nb_read(0x3200,4);

    if(initiator->get_socket_size() > 1)
        initiator->set_socket(1);
    
    data.clear();
    data.push_back(0x543210AB);
    data.push_back(0xDEADBEEF);
    data.push_back(0xCBA98765);
    initiator->nb_write(0x2000,data);

    initiator->nb_read(0x1208,1);
    initiator->nb_read(0x1300,15);

    initiator->wait();
#endif

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(10,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/




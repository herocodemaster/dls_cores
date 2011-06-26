//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_tlm_memory.h"

/*AUTOSUBCELL_CLASS*/

#define DATA            PARAM_DATA

#define DATA_MAX ((1<<DATA)-1)

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();

    void m_rst_thread();
    void s_rst_thread();
    
    dlsc_tlm_initiator_nb<uint32_t> *initiator;

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
    
    initiator = new dlsc_tlm_initiator_nb<uint32_t>("initiator");
    memory = new dlsc_tlm_memory<uint32_t>("memory",16*1024*1024,0,sc_core::sc_time(2.5,SC_NS),sc_core::sc_time(10,SC_NS));

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/


    SP_CELL(axi_master,dlsc_axi4lb_tlm_master_32b);
        SP_PIN(axi_master,rst,m_rst);
        /*AUTOINST*/
    
    SP_TEMPLATE(axi_master,"axi_(.*)","m_$1");

    initiator->socket.bind(axi_master->socket);


    SP_CELL(axi_slave,dlsc_axi4lb_tlm_slave_32b);
        SP_PIN(axi_slave,rst,s_rst);
        /*AUTOINST*/
    
    SP_TEMPLATE(axi_slave,"axi_(.*)","s_$1");

    axi_slave->socket.bind(memory->socket);


    m_rst       = 1;
    s_rst       = 1;

    SC_THREAD(m_rst_thread);
    SC_THREAD(s_rst_thread);

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::m_rst_thread() {
    m_rst       = 1;
    wait(100,SC_NS);
    m_rst       = 0;

    while(true) {

        wait(rand()%10000,SC_NS);
        wait(clk.posedge_event());
        m_rst       = 1;

        if(rand()%3==0) {
            // do long reset
            wait(rand()%3000,SC_NS);
        }
        
        wait(clk.posedge_event());
        m_rst       = 0;

    }
}

void __MODULE__::s_rst_thread() {
    s_rst       = 1;
    wait(100,SC_NS);
    s_rst       = 0;

    while(true) {

        wait(rand()%10000,SC_NS);
        wait(clk.posedge_event());
        s_rst       = 1;

        if(rand()%3==0) {
            // do long reset
            wait(rand()%3000,SC_NS);
        }
        
        wait(clk.posedge_event());
        s_rst       = 0;

    }
}

void __MODULE__::stim_thread() {
    wait(1,SC_US);

    for(int i=0;i<10000;++i) {

        uint32_t addr = (rand() % 1000) << 2;
        uint32_t len = (rand() % 16) + 1;
        assert(len > 0 && len <= 16);
        assert((addr + 4*len) < 4096);

//        uint32_t addr = (rand() % (4*1024*1024)) << 2;
//        uint32_t len  = (rand() % 16) + 1;
//
//        if( addr + len > 
//
//        if( (addr & 0xFFF) + len*4 > 4096 ) {
//            len = (4096 - (addr & 0xFFF))/4;
//        }

        if(rand()%2) {
            initiator->nb_read(addr,len);
        } else {
            std::deque<uint32_t> data;
            for(int i=0;i<len;++i) {
                data.push_back(rand());
            }
            initiator->nb_write(addr,data);
        }

        wait(100,SC_NS);

        if(rand()%100==0) {
            initiator->wait();
        }
    }

    initiator->wait();

    dlsc_okay("didn't block!");

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




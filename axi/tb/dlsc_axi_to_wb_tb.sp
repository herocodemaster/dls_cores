//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"

/*AUTOSUBCELL_CLASS*/

#define WB_PIPELINE     PARAM_WB_PIPELINE


SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();
    
    dlsc_tlm_initiator_nb<uint32_t> *initiator;
    
    dlsc_tlm_memtest<uint32_t> *memtest;

    typedef dlsc_tlm_initiator_nb<uint32_t>::transaction transaction;

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
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/


    SP_CELL(axi_master,dlsc_axi4lb_tlm_master_32b);
        /*AUTOINST*/

    initiator = new dlsc_tlm_initiator_nb<uint32_t>("initiator");
    initiator->socket.bind(axi_master->socket);
    
//    memtest = new dlsc_tlm_memtest<uint32_t>("memtest");
//    memtest->socket.bind(axi_master->socket);


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

    memory = new dlsc_tlm_memory<uint32_t>("memory",16*1024*1024,0,sc_core::sc_time(5.0,SC_NS),sc_core::sc_time(0,SC_NS));

    wb_slave->socket.bind(memory->socket);


    rst         = 1;

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::stim_thread() {
    transaction ts;

    rst         = 1;
    wait(1,SC_US);
    wait(clk.posedge_event());
    rst         = 0;
    wait(clk.posedge_event());

    std::deque<uint32_t> data;
    data.push_back(0xDEADBEEF);
    data.push_back(0xCAFEBABE);
    ts = initiator->nb_write(0x40,data);
    ts->wait();

    ts = initiator->nb_read(0x44,16);
    ts->b_read(data);



//    for(int i=0;i<10000;++i) {
//
//        uint32_t addr = (rand() % 1000) << 2;
//        uint32_t len = (rand() % 16) + 1;
//        assert(len > 0 && len <= 16);
//        assert((addr + 4*len) < 4096);
//
////        uint32_t addr = (rand() % (4*1024*1024)) << 2;
////        uint32_t len  = (rand() % 16) + 1;
////
////        if( addr + len > 
////
////        if( (addr & 0xFFF) + len*4 > 4096 ) {
////            len = (4096 - (addr & 0xFFF))/4;
////        }
//
//        if(rand()%2) {
//            initiator->nb_read(addr,len);
//        } else {
//            std::deque<uint32_t> data;
//            for(int i=0;i<len;++i) {
//                data.push_back(rand());
//            }
//            initiator->nb_write(addr,data);
//        }
//
//        wait(100,SC_NS);
//
//        if(rand()%100==0) {
//            initiator->wait();
//        }
//    }

    initiator->wait();

//    memtest->test(0,4*4096,1*1000*10);
//    memtest->test(0,128,100);

    dlsc_okay("didn't block!");

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(1,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/




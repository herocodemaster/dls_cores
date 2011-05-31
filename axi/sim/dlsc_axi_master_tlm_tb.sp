//######################################################################
#sp interface

#include <systemperl.h>

#include <tlm.h>
#include <tlm_utils/simple_initiator_socket.h>

#include "dlsc_tlm_memtest.h"

#include "dlsc_tlm_initiator_nb.h"
//#include "dlsc_tlm_initiator_b.h"
#include "dlsc_tlm_memory.h"

#include "dlsc_tlm_target_nb.h"

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

//    tlm_utils::simple_initiator_socket<__MODULE__,32> socket;

    void stim_thread();
    void watchdog_thread();

    dlsc_tlm_initiator_nb<uint32_t> *initiator;

    dlsc_tlm_memtest<uint32_t> *memtest;

    dlsc_tlm_target_nb<__MODULE__,uint32_t> *target;

    dlsc_tlm_memory<uint32_t> *memory;

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/

public:
    virtual void target_callback(
        dlsc_tlm_target_nb<__MODULE__,uint32_t>::transaction ts);
    virtual void target_callback_tann(
        dlsc_tlm_target_nb<__MODULE__,uint32_t>::transaction ts,
        sc_core::sc_time delay);

//    virtual tlm::tlm_sync_enum nb_transport_bw(
//        tlm::tlm_generic_payload &trans,
//        tlm::tlm_phase &phase,
//        sc_time &delay);

    /*AUTOMETHODS*/

};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

#include "dlsc_main.cpp"

#include "dlsc_tlm_mm.h"

#include "tlm.h"

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS)/*, socket("socket")*/ /*AUTOINIT*/ {
    SP_AUTO_CTOR;

//    initiator = new dlsc_tlm_initiator_nb<uint32_t>("initiator");
    memtest = new dlsc_tlm_memtest<uint32_t>("memtest");

//    target = new dlsc_tlm_target_nb<__MODULE__,uint32_t>(
//        "target",this,&__MODULE__::target_callback_tann);
////        target->socket(initiator->socket);
    
    memory = new dlsc_tlm_memory<uint32_t>("memory",128*1024*1024,0,sc_core::sc_time(10,SC_NS),sc_core::sc_time(10,SC_NS));
        memory->socket(memtest->socket);

    /*AUTOTIEOFF*/
    SP_CELL(dut,Vdlsc_axi_slave_dummy);
        /*AUTOINST*/

//    SP_CELL(axi_master,dlsc_axi4lb_tlm_master_32b);
//        axi_master->socket(memtest->socket);
//        /*AUTOINST*/
//
//    SP_CELL(axi_slave,dlsc_axi4lb_tlm_slave_32b);
////        axi_slave->socket(target->socket);
//        axi_slave->socket(memory->socket);
//        /*AUTOINST*/

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::target_callback(
    dlsc_tlm_target_nb<__MODULE__,uint32_t>::transaction ts)
{
    dlsc_display("target_callback " << sc_core::sc_time_stamp());

    ts->complete_delta(sc_core::sc_time(937,SC_NS));
}

void __MODULE__::target_callback_tann(
    dlsc_tlm_target_nb<__MODULE__,uint32_t>::transaction ts,
    sc_core::sc_time delay)
{
    dlsc_display("target_callback " << (sc_core::sc_time_stamp() + delay));

    if(ts->is_read()) {
        std::vector<uint32_t> data;
        for(uint64_t i = ts->get_address(); data.size() != ts->size(); i+=4) {
            data.push_back(i);
        }
        ts->set_data(data);
        ts->set_response_status(tlm::TLM_OK_RESPONSE);
    }

    ts->complete_delta(sc_core::sc_time(937,SC_NS));
}


void __MODULE__::stim_thread() {
    rst = 1;

    tlm::tlm_global_quantum::instance().set(sc_core::sc_time(100,SC_NS));
    dlsc_display("global quantum: " << (tlm::tlm_global_quantum::instance().get()));

    wait(100,SC_NS);
//    wait(clk.posedge_event());
    rst = 0;

    memtest->test(0,65536,100000);

//    dlsc_tlm_initiator_nb<uint32_t>::transaction t;
//
//    std::vector<uint32_t> data;
//
//    sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
//
//    data.push_back(0xDEADBEEF);
//    data.push_back(0x76543210);
//    
//    t = initiator->nb_write(0x12345678,data,delay); delay += sc_core::sc_time(1,SC_NS);
//    t = initiator->nb_write(0x123456A8,data,delay); delay += sc_core::sc_time(1,SC_NS);
//    data.pop_back();
//    t = initiator->nb_write(0x123456B8,data,delay); delay += sc_core::sc_time(1,SC_NS);
//    data.push_back(0x98765432);
//    initiator->nb_write(0x123456C8,data,delay); delay += sc_core::sc_time(1,SC_NS);
//    data.pop_back();
//    initiator->nb_write(0x123456D8,data,delay); delay += sc_core::sc_time(1,SC_NS);
//    initiator->nb_write(0x123456E8,data,delay); delay += sc_core::sc_time(1,SC_NS);
//
//    dlsc_display("nb_write done " << (sc_core::sc_time_stamp()+delay));
//
//    t->wait(delay);
//    
//    dlsc_display("wait done " << (sc_core::sc_time_stamp()+delay));
//
////    wait(100,SC_NS);
//
//    t->wait(delay);
//
//    dlsc_display("wait done " << (sc_core::sc_time_stamp()+delay));
//    
//    data.push_back(0xCAFEBABE);
//    data.push_back(0x12345678);
//    t = initiator->nb_write(0x12345678,data,delay);
//
//    dlsc_display("nb_write done " << (sc_core::sc_time_stamp()+delay));
//
//    t->wait(delay);
//
//    dlsc_display("wait done " << (sc_core::sc_time_stamp()+delay));
//
//    t = initiator->nb_read(0xCAFEBEE8,9,delay);
//
//    dlsc_display("nb_read done " << (sc_core::sc_time_stamp()+delay));
//
//    initiator->wait(delay);
//
////    t->wait(delay);
//
//    dlsc_display("wait all done " << (sc_core::sc_time_stamp()+delay));
//
//    t->b_read(data,delay);
//    for(std::vector<uint32_t>::iterator it = data.begin(); it != data.end(); ++it) {
//        dlsc_display("data: 0x" << std::hex << std::setw(8) << *it);
//    }
//
//    dlsc_display("wait.. " << (sc_core::sc_time_stamp()+delay));
//    wait(delay);
////    dlsc_display("wait... " << (sc_core::sc_time_stamp()));
////    t->wait();
//    delay = sc_core::SC_ZERO_TIME;
//    dlsc_display("wait done " << (sc_core::sc_time_stamp()+delay));
//
//    wait(100,SC_NS);
//    t.reset();


    wait(10,SC_US);
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



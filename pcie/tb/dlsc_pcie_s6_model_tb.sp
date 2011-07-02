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
    sc_clock sys_clk;

    void stim_thread();
    void watchdog_thread();
    
    dlsc_tlm_initiator_nb<uint32_t> *initiator;
    typedef dlsc_tlm_initiator_nb<uint32_t>::transaction transaction;

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

#define MEMTEST

SP_CTOR_IMP(__MODULE__) : sys_clk("sys_clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    SP_CELL(pcie,dlsc_pcie_s6_model);
        SP_PIN(pcie,user_clk_out,clk);
        SP_PIN(pcie,user_reset_out,rst);
        // loopback
        SP_PIN(pcie,m_axis_rx_tready,s_axis_tx_tready);
        SP_PIN(pcie,m_axis_rx_tvalid,s_axis_tx_tvalid);
        SP_PIN(pcie,m_axis_rx_tlast, s_axis_tx_tlast);
        SP_PIN(pcie,m_axis_rx_tdata, s_axis_tx_tdata);
        /*AUTOINST*/

    // tie-off
    tx_cfg_gnt      = 1;
    rx_np_ok        = 1;

#ifdef MEMTEST
    memtest = new dlsc_tlm_memtest<uint32_t>("memtest",128);
    memtest->socket.bind(pcie->target_socket);
#else
    initiator = new dlsc_tlm_initiator_nb<uint32_t>("initiator",128);
    initiator->socket.bind(pcie->target_socket);
#endif

    memory = new dlsc_tlm_memory<uint32_t>("memory",4*1024*1024,0,sc_core::sc_time(2.5,SC_NS),sc_core::sc_time(20,SC_NS));

    pcie->initiator_socket.bind(memory->socket);

    sys_reset       = 1;

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::stim_thread() {
    sys_reset       = 1;
    wait(1,SC_US);
    wait(sys_clk.posedge_event());
    sys_reset       = 0;
    wait(sys_clk.posedge_event());
    wait(clk.posedge_event());

#ifdef MEMTEST
    memtest->set_max_outstanding(16);   // more MOT for improved performance
    memtest->set_strobe_rate(1);        // sparse strobes are very slow over PCIe
    memtest->test(0,4*4096,1*1000*10);
#else

    std::deque<uint32_t> data;
    std::deque<uint32_t> strb;

    data.push_back(0x12345678);
    data.push_back(0xFEEDFACE);
    data.push_back(0xABCDEF98);
    initiator->nb_write(0,data);

    initiator->nb_read(4,64);

    initiator->wait();
#endif

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




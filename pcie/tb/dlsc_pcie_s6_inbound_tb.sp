//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"

/*AUTOSUBCELL_CLASS*/

#define ADDR            PARAM_ADDR
#define LEN             PARAM_LEN

#if (PARAM_ASYNC>0)
#define ASYNC
#else
#define SYNC
#endif

#if (PARAM_WRITE_EN>0)
#define WRITE_EN
#endif

#if (PARAM_READ_EN>0)
#define READ_EN
#endif

SC_MODULE (__MODULE__) {
private:
    sc_clock        sys_clk;
    sc_signal<bool> sys_reset;
    
    sc_signal<bool> rst;
    sc_signal<bool> pcie_clk;
    sc_signal<bool> pcie_rst;

#ifdef ASYNC
    sc_clock        clk;
#else
    sc_signal<bool> clk;
#endif

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

SP_CTOR_IMP(__MODULE__) :
    sys_clk("sys_clk",10,SC_NS)
#ifdef ASYNC
    ,clk("clk",10,SC_NS) // TODO
#endif
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
#ifdef ASYNC
        SP_PIN(dut,pcie_clk,pcie_clk);
        SP_PIN(dut,pcie_rst,pcie_rst);
#else
        SP_PIN(dut,pcie_clk,clk);
        SP_PIN(dut,pcie_rst,rst);
#endif
        SP_PIN(dut,axi_clk,clk);
        SP_PIN(dut,axi_rst,rst);
        /*AUTOINST*/

    // tie-off
    pcie_max_payload_size   = 2;    // 512 bytes
    
    SP_CELL(axi_slave,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/

    SP_CELL(pcie,dlsc_pcie_s6_model);
#ifdef ASYNC
        SP_PIN(pcie,user_clk_out,pcie_clk);
        SP_PIN(pcie,user_reset_out,pcie_rst);
#else
        SP_PIN(pcie,user_clk_out,clk);
        SP_PIN(pcie,user_reset_out,rst);
#endif
        // RX
        SP_PIN(pcie,m_axis_rx_tready,pcie_rx_ready);
        SP_PIN(pcie,m_axis_rx_tvalid,pcie_rx_valid);
        SP_PIN(pcie,m_axis_rx_tlast, pcie_rx_last);
        SP_PIN(pcie,m_axis_rx_tdata, pcie_rx_data);
        // TX
        SP_PIN(pcie,s_axis_tx_tready,pcie_tx_ready);
        SP_PIN(pcie,s_axis_tx_tvalid,pcie_tx_valid);
        SP_PIN(pcie,s_axis_tx_tlast, pcie_tx_last);
        SP_PIN(pcie,s_axis_tx_tdata, pcie_tx_data);
        // Error
        SP_PIN(pcie,cfg_err_cpl_rdy,pcie_err_ready);
        SP_PIN(pcie,cfg_err_ur,pcie_err_unsupported);
        /*AUTOINST*/

    // tie-off
    tx_cfg_gnt      = 1;

#ifdef MEMTEST
    memtest = new dlsc_tlm_memtest<uint32_t>("memtest",128);
    memtest->socket.bind(pcie->target_socket);
#else
    initiator = new dlsc_tlm_initiator_nb<uint32_t>("initiator",128);
    initiator->socket.bind(pcie->target_socket);
#endif

    memory = new dlsc_tlm_memory<uint32_t>("memory",4*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(20,SC_NS));

    axi_slave->socket.bind(memory->socket);

    pcie->initiator_socket.bind(memory->socket);

#ifdef ASYNC
    rst             = 1;
#endif
    sys_reset       = 1;

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::stim_thread() {
    wait(1,SC_US);
    wait(sys_clk.posedge_event());
    sys_reset       = 0;
#ifdef ASYNC
    wait(clk.posedge_event());
    rst             = 0;
#endif
    wait(sys_clk.posedge_event());
    wait(clk.posedge_event());

#ifdef MEMTEST
    memory->set_error_rate_read(1.0);
    memtest->set_ignore_error_read(true);
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

    initiator->nb_read(4,16);

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




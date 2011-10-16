//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"
#include "dlsc_tlm_channel.h"
#include "dlsc_tlm_fabric.h"

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

    dlsc_tlm_fabric<uint32_t> *fabric;

    dlsc_tlm_memory<uint32_t> *memory;

    dlsc_tlm_channel<uint32_t> *pcie_channel;
    dlsc_tlm_channel<uint32_t> *dummy_channel;

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
    pcie_max_payload_size    = 2;    // 512 bytes
    
    SP_CELL(axi_slave,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/

    SP_CELL(pcie,dlsc_pcie_s6_model);
        /*AUTOINST*/
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
        // FC
        SP_PIN(pcie,fc_sel,pcie_fc_sel);
        SP_PIN(pcie,fc_ph,pcie_fc_ph);
        SP_PIN(pcie,fc_pd,pcie_fc_pd);
        // Error
        SP_PIN(pcie,cfg_err_cpl_rdy,pcie_err_ready);
        SP_PIN(pcie,cfg_err_ur,pcie_err_unsupported);

    // tie-off
    tx_cfg_gnt      = 1;
    
    initiator       = new dlsc_tlm_initiator_nb<uint32_t>("initiator",128);
    memtest         = new dlsc_tlm_memtest<uint32_t>("memtest",128);
    fabric          = new dlsc_tlm_fabric<uint32_t>("fabric");
    pcie_channel    = new dlsc_tlm_channel<uint32_t>("pcie_channel",true);
    dummy_channel   = new dlsc_tlm_channel<uint32_t>("dummy_channel",true);
    memory          = new dlsc_tlm_memory<uint32_t>("memory",4*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(20,SC_NS));
    
    memtest->socket.bind(fabric->in_socket);
    initiator->socket.bind(fabric->in_socket);

    pcie->initiator_socket.bind(fabric->in_socket); // tie-off
    pcie_channel->out_socket.bind(pcie->target_socket);

    fabric->out_socket.bind(pcie_channel->in_socket);   // socket 0
    fabric->out_socket.bind(dummy_channel->in_socket);  // socket 1 (catches anything that misses 0)

#ifndef READ_EN
    fabric->set_read_okay(0,false);     // disallow reads via PCIe
#endif
#ifndef WRITE_EN
    fabric->set_write_okay(0,false);    // disallow writes via PCIe
#endif

    pcie_channel->set_delay(sc_core::sc_time(500,SC_NS),sc_core::sc_time(1000,SC_NS));
    dummy_channel->set_delay(sc_core::sc_time(1000,SC_NS),sc_core::sc_time(1100,SC_NS)); // longer delay, to prevent reads before a posted write completes
    
    axi_slave->socket.bind(memory->socket);
    dummy_channel->out_socket.bind(memory->socket);

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

    memory->set_error_rate_read(1.0);
    memtest->set_ignore_error_read(true);
    memtest->set_max_outstanding(16);   // more MOT for improved performance
    memtest->set_strobe_rate(1);        // sparse strobes are very slow over PCIe
    memtest->test(0,4*4096,1*1000*10);

    // test link reset recovery
    transaction ts, tswait;
    std::deque<uint32_t> data;
    std::deque<uint32_t> strb;
    
    int i,j;

    for(i=0;i<20;++i) {     // resets
        dlsc_info("testing reset recovery (" << (i+1) << "/20)");
        for(j=0;j<100;++j) {     // transactions
            if((rand()%100)>=50) {
                // write
                data.resize((rand()%(1<<LEN))+1);
                ts = initiator->nb_write((rand()%500)*4,data);
            } else {
                // read
                ts = initiator->nb_read((rand()%500)*4,(rand()%128)+1);
            }
            if(j==35) tswait = ts;
        }
        // wait for some transactions to complete
        tswait->wait();
        // reset it
        wait(sys_clk.posedge_event());
        dlsc_verb("applying sys_reset");
        sys_reset       = 1;
        wait(100+(rand()%1000),SC_NS);
        wait(sys_clk.posedge_event());
        dlsc_verb("removing sys_reset");
        sys_reset       = 0;
        wait(sys_clk.posedge_event());

        // wait for all transactions to finish
        initiator->wait();

        while(rst) {
            // wait for AXI reset to subside
            wait(clk.posedge_event());
        }
    }

    // run another memtest
    memtest->test(0,4*4096,1*1000*1);

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


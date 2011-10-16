//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"
#include "dlsc_tlm_channel.h"
#include "dlsc_tlm_fabric.h"

typedef uint64_t vluint64_t;

/*AUTOSUBCELL_CLASS*/
    
#define APB_CLK_DOMAIN PARAM_APB_CLK_DOMAIN
#define IB_CLK_DOMAIN PARAM_IB_CLK_DOMAIN
#define OB_CLK_DOMAIN PARAM_OB_CLK_DOMAIN
#define APB_ADDR PARAM_APB_ADDR
#define AUTO_POWEROFF PARAM_AUTO_POWEROFF
#define INTERRUPTS PARAM_INTERRUPTS
#define INT_ASYNC PARAM_INT_ASYNC
#define IB_ADDR PARAM_IB_ADDR
#define IB_LEN PARAM_IB_LEN
#define IB_WRITE_BUFFER PARAM_IB_WRITE_BUFFER
#define IB_WRITE_MOT PARAM_IB_WRITE_MOT
#define IB_READ_BUFFER PARAM_IB_READ_BUFFER
#define IB_READ_MOT PARAM_IB_READ_MOT
#define OB_ADDR PARAM_OB_ADDR
#define OB_LEN PARAM_OB_LEN
#define OB_WRITE_SIZE PARAM_OB_WRITE_SIZE
#define OB_WRITE_MOT PARAM_OB_WRITE_MOT
#define OB_READ_MOT PARAM_OB_READ_MOT
#define OB_READ_CPLH PARAM_OB_READ_CPLH
#define OB_READ_CPLD PARAM_OB_READ_CPLD
#define OB_READ_TIMEOUT PARAM_OB_READ_TIMEOUT
#define OB_TAG PARAM_OB_TAG
#define OB_TRANS_REGIONS PARAM_OB_TRANS_REGIONS

#if (IB_LEN<OB_LEN)
#define LEN IB_LEN
#else
#define LEN OB_LEN
#endif

#if (PARAM_APB_CLK_DOMAIN!=0)
#define APB_ASYNC
#else
#define APB_SYNC
#endif
#if (PARAM_IB_CLK_DOMAIN!=0)
#define IB_ASYNC
#else
#define IB_SYNC
#endif
#if (PARAM_OB_CLK_DOMAIN!=0)
#define OB_ASYNC
#else
#define OB_SYNC
#endif

#if (PARAM_APB_EN>0)
#define APB_EN
#endif
#if (PARAM_IB_READ_EN>0)
#define IB_READ_EN
#endif
#if (PARAM_IB_WRITE_EN>0)
#define IB_WRITE_EN
#endif
#if (PARAM_OB_READ_EN>0)
#define OB_READ_EN
#endif
#if (PARAM_OB_WRITE_EN>0)
#define OB_WRITE_EN
#endif



SC_MODULE (__MODULE__) {
private:
    sc_clock        sys_clk;
    sc_signal<bool> sys_reset;

    sc_clock        clk1;
    sc_clock        clk2;
    sc_clock        clk3;

    sc_signal<bool> rst1;
    sc_signal<bool> rst2;
    sc_signal<bool> rst3;

    void set_reset(bool rst);

    void stim_thread();
    void watchdog_thread();

    dlsc_tlm_initiator_nb<uint32_t> *initiator;
    typedef dlsc_tlm_initiator_nb<uint32_t>::transaction transaction;

    dlsc_tlm_memtest<uint32_t>  *memtest;
    dlsc_tlm_fabric<uint32_t>   *fabric;
    dlsc_tlm_channel<uint32_t>  *pcie_channel;
    dlsc_tlm_memory<uint32_t>   *memory;

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
    sys_clk("sys_clk",10,SC_NS),
    clk1("clk1",25,SC_NS),
    clk2("clk2",10,SC_NS),
    clk3("clk3",7,SC_NS)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
#if (PARAM_APB_CLK_DOMAIN==1)
        SP_PIN(dut,apb_clk,clk1);
        SP_PIN(dut,apb_rst,rst1);
#elif (PARAM_APB_CLK_DOMAIN==2)
        SP_PIN(dut,apb_clk,clk2);
        SP_PIN(dut,apb_rst,rst2);
#elif (PARAM_APB_CLK_DOMAIN==3)
        SP_PIN(dut,apb_clk,clk3);
        SP_PIN(dut,apb_rst,rst3);
#else
        SP_PIN(dut,apb_clk,user_clk_out);
        SP_PIN(dut,apb_rst,user_reset_out);
#endif
#if (PARAM_IB_CLK_DOMAIN==1)
        SP_PIN(dut,ib_clk,clk1);
        SP_PIN(dut,ib_rst,rst1);
#elif (PARAM_IB_CLK_DOMAIN==2)
        SP_PIN(dut,ib_clk,clk2);
        SP_PIN(dut,ib_rst,rst2);
#elif (PARAM_IB_CLK_DOMAIN==3)
        SP_PIN(dut,ib_clk,clk3);
        SP_PIN(dut,ib_rst,rst3);
#else
        SP_PIN(dut,ib_clk,user_clk_out);
        SP_PIN(dut,ib_rst,user_reset_out);
#endif
#if (PARAM_OB_CLK_DOMAIN==1)
        SP_PIN(dut,ob_clk,clk1);
        SP_PIN(dut,ob_rst,rst1);
#elif (PARAM_OB_CLK_DOMAIN==2)
        SP_PIN(dut,ob_clk,clk2);
        SP_PIN(dut,ob_rst,rst2);
#elif (PARAM_OB_CLK_DOMAIN==3)
        SP_PIN(dut,ob_clk,clk3);
        SP_PIN(dut,ob_rst,rst3);
#else
        SP_PIN(dut,ob_clk,user_clk_out);
        SP_PIN(dut,ob_rst,user_reset_out);
#endif
        /*AUTOINST*/

    SP_CELL(pcie,dlsc_pcie_s6_model);
        /*AUTOINST*/
    
    SP_CELL(apb_master,dlsc_apb_tlm_master_32b);
        /*AUTOINST*/
#if (PARAM_APB_CLK_DOMAIN==1)
        SP_PIN(apb_master,clk,clk1);
        SP_PIN(apb_master,rst,rst1);
#elif (PARAM_APB_CLK_DOMAIN==2)
        SP_PIN(apb_master,clk,clk2);
        SP_PIN(apb_master,rst,rst2);
#elif (PARAM_APB_CLK_DOMAIN==3)
        SP_PIN(apb_master,clk,clk3);
        SP_PIN(apb_master,rst,rst3);
#else
        SP_PIN(apb_master,clk,user_clk_out);
        SP_PIN(apb_master,rst,user_reset_out);
#endif

    SP_CELL(axi_slave,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/
#if (PARAM_IB_CLK_DOMAIN==1)
        SP_PIN(axi_slave,clk,clk1);
        SP_PIN(axi_slave,rst,rst1);
#elif (PARAM_IB_CLK_DOMAIN==2)
        SP_PIN(axi_slave,clk,clk2);
        SP_PIN(axi_slave,rst,rst2);
#elif (PARAM_IB_CLK_DOMAIN==3)
        SP_PIN(axi_slave,clk,clk3);
        SP_PIN(axi_slave,rst,rst3);
#else
        SP_PIN(axi_slave,clk,user_clk_out);
        SP_PIN(axi_slave,rst,user_reset_out);
#endif
        SP_TEMPLATE(axi_slave,"axi_(.*)","ib_$1");
    
    SP_CELL(axi_master,dlsc_axi4lb_tlm_master_32b);
        /*AUTOINST*/
#if (PARAM_OB_CLK_DOMAIN==1)
        SP_PIN(axi_master,clk,clk1);
        SP_PIN(axi_master,rst,rst1);
#elif (PARAM_OB_CLK_DOMAIN==2)
        SP_PIN(axi_master,clk,clk2);
        SP_PIN(axi_master,rst,rst2);
#elif (PARAM_OB_CLK_DOMAIN==3)
        SP_PIN(axi_master,clk,clk3);
        SP_PIN(axi_master,rst,rst3);
#else
        SP_PIN(axi_master,clk,user_clk_out);
        SP_PIN(axi_master,rst,user_reset_out);
#endif
        SP_TEMPLATE(axi_master,"axi_(.*)","ob_$1");
    
    fabric          = new dlsc_tlm_fabric<uint32_t>("fabric");
    fabric->out_socket.bind(axi_master->socket);
    
    memory          = new dlsc_tlm_memory<uint32_t>("memory",4*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(20,SC_NS));

    axi_slave->socket.bind(memory->socket);

    pcie_channel    = new dlsc_tlm_channel<uint32_t>("pcie_channel");
    pcie_channel->set_delay(sc_core::sc_time(500,SC_NS),sc_core::sc_time(1000,SC_NS));
    
    memtest         = new dlsc_tlm_memtest<uint32_t>("memtest",(1<<LEN));
    memtest->socket.bind(fabric->in_socket);
    memtest->socket.bind(pcie_channel->in_socket);
    pcie_channel->out_socket.bind(pcie->target_socket);

    initiator       = new dlsc_tlm_initiator_nb<uint32_t>("initiator",(1<<LEN));
    initiator->socket.bind(fabric->in_socket);
    initiator->socket.bind(pcie_channel->in_socket);
    initiator->socket.bind(apb_master->socket); // TODO
    pcie_channel->out_socket.bind(pcie->target_socket);

    pcie->initiator_socket.bind(pcie_channel->in_socket);
    pcie_channel->out_socket.bind(memory->socket);

    rst1            = 1;
    rst2            = 1;
    rst3            = 1;
    sys_reset       = 1;

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::set_reset(bool rst) {
    wait(clk3.posedge_event());
    rst3            = rst;
    wait(clk2.posedge_event());
    rst2            = rst;
    wait(clk1.posedge_event());
    rst1            = rst;
    wait(clk3.posedge_event());
    wait(clk2.posedge_event());
    wait(clk1.posedge_event());
}

void __MODULE__::stim_thread() {
    wait(1,SC_US);
    wait(sys_clk.posedge_event());
    sys_reset       = 0;
    set_reset(false);

    memory->set_error_rate_read(1.0);
    memtest->set_ignore_error_read(true);
    memtest->set_max_outstanding(32);   // more MOT for improved performance
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
            initiator->set_socket(rand()%2);
            if((rand()%100)>=50) {
                // write
                data.resize((rand()%(1<<LEN))+1);
                ts = initiator->nb_write((rand()%500)*4,data);
            } else {
                // read
                ts = initiator->nb_read((rand()%500)*4,(rand()%(1<<LEN))+1);
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

        while(user_reset_out) {
            // wait for reset to subside
            wait(user_clk_out.posedge_event());
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




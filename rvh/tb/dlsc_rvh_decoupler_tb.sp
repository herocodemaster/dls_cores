//######################################################################
#sp interface

#include <systemperl.h>
#include <iostream>
#include <vector>

#include "dlsc_rvh_source.h"
#include "dlsc_rvh_sink.h"

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    sc_fifo<uint32_t> data_tx;
    sc_fifo<uint32_t> data_rx;
    sc_fifo<uint32_t> data_rx_expect;

    dlsc_rvh_source<uint32_t> *data_source;
    dlsc_rvh_sink<uint32_t> *data_sink;

    void reset();

    void stim_thread();
    void rx_thread();

    void watchdog_thread();

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/

public:
    /*AUTOMETHODS*/

};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

#include "dlsc_main.cpp"


#include <iostream>
#include <iomanip>

#include <vector>
#include <deque>

#include <scv.h>

using namespace std;

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/

    SP_CELL (dut,Vdlsc_rvh_decoupler);
        /*AUTOINST*/

    data_source = new dlsc_rvh_source<uint32_t>("data_source");
        data_source->clk(clk);
        data_source->ready(source_ready);
        data_source->valid(source_valid);
        data_source->data(source_data);
        data_source->data_fifo(data_tx);

    data_sink = new dlsc_rvh_sink<uint32_t>("data_sink");
        data_sink->clk(clk);
        data_sink->ready(sink_ready);
        data_sink->valid(sink_valid);
        data_sink->data(sink_data);
        data_sink->data_fifo(data_rx);

    SC_THREAD(stim_thread);
    SC_THREAD(rx_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::reset() {
    data_source->flush();
    data_sink->flush();
    wait(clk.posedge_event());
    rst = 1;
    wait(clk.posedge_event());
    rst = 0;
}

void __MODULE__::stim_thread() {

    rst = 1;

    scv_smart_ptr<uint32_t> d;
    scv_smart_ptr<bool> b;

    scv_bag<bool> b_bag;
    b_bag.push(false,99);
    b_bag.push(true,1);
    b->set_mode(b_bag);

    wait(100,SC_NS);
    wait(clk.posedge_event());

    rst = 0;
    
    wait(100,SC_NS);


    int mode = 0;
    for(int i=0;i<7000;++i) {
        if(i%1000==0) {
            switch(mode) {
                case 0:
                    data_source->set_percent_valid(100);
                    data_sink->set_percent_ready(100);
                    break;
                case 1:
                    data_source->set_percent_valid(10);
                    data_sink->set_percent_ready(100);
                    break;
                case 2:
                    data_source->set_percent_valid(100);
                    data_sink->set_percent_ready(10);
                    break;
                case 3:
                    data_source->set_percent_valid(80);
                    data_sink->set_percent_ready(30);
                    break;
                case 4:
                    data_source->set_percent_valid(30);
                    data_sink->set_percent_ready(80);
                    break;
                case 5:
                    data_source->set_percent_valid(80);
                    data_sink->set_percent_ready(80);
                    break;
                case 6:
                    data_source->set_percent_valid(10);
                    data_sink->set_percent_ready(10);
                    break;
            }
            mode++;
        }

        d->next();
        data_rx_expect.write(*d);
        data_tx.write(*d);

        b->next();
        if(*b) {
            reset();
        }
    }

    data_source->flush();

    wait(1000,SC_NS);

    dut->final();
    sc_stop();
}

void __MODULE__::rx_thread() {
    while(true) {
        uint32_t d, e;
        data_rx.read(d);
        if(!data_rx_expect.nb_read(e)) {
            dlsc_error("unexpected data: " << d);
        } else {
            dlsc_assert(d == e);
        }
    }
}

void __MODULE__::watchdog_thread() {
    wait(10,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/


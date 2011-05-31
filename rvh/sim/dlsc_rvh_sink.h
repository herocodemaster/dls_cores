
#ifndef DLSC_RVH_SINK_H_INCLUDED
#define DLSC_RVH_SINK_H_INCLUDED

#include <vector>
#include <systemc.h>
#include <stdexcept>
#include <scv.h>

template <typename T>
SC_MODULE(dlsc_rvh_sink) {
public:
    sc_in<bool>     clk;
    
    sc_out<bool>    ready;
    sc_in<bool>     valid;
    sc_in<T>        data;
    
    sc_port<sc_fifo_out_if<T> > data_fifo;

    dlsc_rvh_sink(sc_module_name nm);
    
    SC_HAS_PROCESS(dlsc_rvh_sink);

    void set_percent_ready(int percent);
    void flush(int cycles);

private:
    scv_smart_ptr<bool> ready_bool;

    void data_thread();
};

template <typename T>
dlsc_rvh_sink<T>::dlsc_rvh_sink(sc_module_name nm) : clk("clk"), ready("ready"), valid("valid"), data("data"), data_fifo("data_fifo"), sc_module(nm) {
    SC_THREAD(data_thread);
    set_percent_ready(100);
}

template <typename T>
void dlsc_rvh_sink<T>::set_percent_ready(int percent) {
    if(percent < 0 || percent > 100) {
        throw std::invalid_argument("invalid percent");
    }

    scv_bag<bool> b_dist;
    if(percent != 100)
        b_dist.push(false,100-percent);
    if(percent != 0)
        b_dist.push(true,percent);
    ready_bool->set_mode(b_dist);
}


template <typename T>
void dlsc_rvh_sink<T>::flush(int cycles=10) {
    int i=0;
    while(i < cycles) {
        wait(clk.posedge_event());
        if(!ready || valid) {
            i = 0;
        } else {
            i++;
        }
    }
}

template <typename T>
void dlsc_rvh_sink<T>::data_thread() {
    ready   = 0;
    
    wait(clk.posedge_event());

    while(true) {
        if(ready && valid) {
            T d     = data;

            if(!data_fifo->nb_write(d)) {
                ready   = 0;
                data_fifo->write(d);
                wait(clk.posedge_event());
            }
        }
        
        // allowed to change ready if:
        // - we're not currently asserting ready
        // - or we've just accepted a datum
        if(!ready || valid) {
            ready_bool->next();
            ready   = *ready_bool;
        }
                
        wait(clk.posedge_event());
    }
}

#endif



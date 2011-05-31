
#ifndef DLSC_RVH_SOURCE_H_INCLUDED
#define DLSC_RVH_SOURCE_H_INCLUDED

#include <vector>
#include <systemc.h>
#include <stdexcept>
#include <scv.h>

template <typename T>
SC_MODULE(dlsc_rvh_source) {
public:
    sc_in<bool>     clk;

    sc_in<bool>     ready;
    sc_out<bool>    valid;
    sc_out<T>       data;
    
    sc_port<sc_fifo_in_if<T> > data_fifo;

    dlsc_rvh_source(sc_module_name nm);
    
    SC_HAS_PROCESS(dlsc_rvh_source);

    void set_percent_valid(int percent);
    void flush();

private:
    scv_smart_ptr<bool> valid_bool;

    void data_thread();
};

template <typename T>
dlsc_rvh_source<T>::dlsc_rvh_source(sc_module_name nm) : clk("clk"), ready("ready"), valid("valid"), data("data"), data_fifo("data_fifo"), sc_module(nm) {
    SC_THREAD(data_thread);
    set_percent_valid(100);
}

template <typename T>
void dlsc_rvh_source<T>::set_percent_valid(int percent) {
    if(percent < 0 || percent > 100) {
        throw std::invalid_argument("invalid percent");
    }

    scv_bag<bool> b_dist;
    if(percent != 100)
        b_dist.push(false,100-percent);
    if(percent != 0)
        b_dist.push(true,percent);
    valid_bool->set_mode(b_dist);
}

template <typename T>
void dlsc_rvh_source<T>::flush() {
    // must wait to allow pending fifo writes to register
    wait(SC_ZERO_TIME);

    // wait for fifo to be empty
    while(data_fifo->num_available() > 0) {
        wait(clk.posedge_event());
    }
}

template <typename T>
void dlsc_rvh_source<T>::data_thread() {
    valid   = 0;

    wait(clk.posedge_event());

    while(true) {
        // allowed to assert new datum if:
        // - we're not currently asserting a datum
        // - or a datum has just been accepted
        if(!valid || ready) {
            T d;

            valid_bool->next();
            if(*valid_bool) {
                if(!data_fifo->nb_read(d)) {
                    valid   = 0;
                    data_fifo->read(d);
                    wait(clk.posedge_event());
                }

                data    = d;
                valid   = 1;
            } else {
                valid   = 0;
            }
        }
        
        wait(clk.posedge_event());
    }
}

#endif


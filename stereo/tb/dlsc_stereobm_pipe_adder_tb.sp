//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#define DATA 16
#define SUM_DATA (DATA+4)
#define SAD 15
#define MULT_R 3
#define META 4

#define INPUTS (SAD+MULT_R-1)

struct check_type {
    uint32_t data[MULT_R];
    uint32_t meta;
};

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void check_method();
    void watchdog_thread();

    void run_test(unsigned int iterations);

    std::deque<check_type> check_vals;

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

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,Vdlsc_stereobm_pipe_adder);
        /*AUTOINST*/

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);

    SC_METHOD(check_method);
        sensitive << clk.posedge_event();
}

uint32_t rand_val() { return rand() % (((1<<DATA)-1)/SAD); }

void __MODULE__::run_test(unsigned int iterations) {
    in_valid    = 0;

    std::deque<uint32_t> vals;
    vals.resize(INPUTS);
    check_type chk;
    sc_bv<INPUTS*DATA> data;
    unsigned int j,i=0;
    while(i<iterations) {
        if(rand()%10) {
            std::generate(vals.begin(),vals.end(),rand_val);
            for(j=0;j<INPUTS;++j) {
                data.range((j*DATA)+DATA-1,(j*DATA)) = vals[j];
            }
            for(j=0;j<MULT_R;++j) {
                chk.data[j] = std::accumulate(vals.begin()+j,vals.begin()+j+SAD,0);
            }
            
            chk.meta    = rand() % ((1<<META)-1);

            in_valid    = 1;
            in_data     = data;
            in_meta     = chk.meta;

            check_vals.push_back(chk);

            ++i;
        } else {
            in_valid    = 0;
            in_meta     = 0;
            in_data     = 0;
        }

        wait(clk.posedge_event());
    }

    in_valid    = 0;
    in_meta     = 0;
    in_data     = 0;

    // wait for completion
    while(!check_vals.empty()) {
        wait(clk.posedge_event());
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;

    wait(100,SC_NS);
    wait(clk.posedge_event());
    rst     = 0;
    
    wait(100,SC_NS);
    wait(clk.posedge_event());

    // first test
    run_test(42);
    run_test(1000);
    
    wait(100,SC_NS);

    // confirm that a single-cycle reset works
    wait(clk.posedge_event());
    rst     = 1;
    wait(clk.posedge_event());
    rst     = 0;
    wait(clk.posedge_event());
    
    run_test(153);

    wait(10,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::check_method() {
    if(!check_vals.empty() && out_valid) {
        sc_bv<MULT_R*SUM_DATA> data;
        data = 0;
        check_type chk = check_vals.front(); check_vals.pop_front();
        for(int i=0;i<MULT_R;++i) {
            data.range((i*SUM_DATA)+SUM_DATA-1,(i*SUM_DATA)) = chk.data[i];
        }
        dlsc_assert(out_data.read() == data);
        dlsc_assert(static_cast<uint32_t>(out_meta.read()) == chk.meta);
    }
}

void __MODULE__::watchdog_thread() {
    wait(1,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/




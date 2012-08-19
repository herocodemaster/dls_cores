//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#define SIGNED      PARAM_SIGNED
#define IN_BITS     PARAM_IN_BITS
#define OUT_BITS    PARAM_OUT_BITS
#define INPUTS      PARAM_INPUTS
#define META        PARAM_META

#define IN_BITS_I (IN_BITS*INPUTS)

#define IN_MASK     ((1ull<<IN_BITS)-1ull)
#define OUT_MASK    ((1ull<<OUT_BITS)-1ull)
#define META_MASK   ((1ull<<META)-1ull)

#if(!SIGNED)
    #define IN_MAX      (((1<<(IN_BITS  ))-1)/INPUTS)
    #define IN_MIN      0
#else
    #define IN_MAX      (((1<<(IN_BITS-1))-1)/INPUTS)
    #define IN_MIN      (-IN_MAX)
#endif

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void check_method();
    void watchdog_thread();

    void run_test(unsigned int iterations);

    std::deque<uint64_t> check_vals;
    std::deque<uint64_t> meta_vals;

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
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);

    SC_METHOD(check_method);
        sensitive << clk.posedge_event();
}

void __MODULE__::run_test(unsigned int iterations) {
    in_valid    = 0;

#if IN_BITS_I <= 64
    uint64_t data;
#else
    sc_bv<IN_BITS_I> data;
#endif
    unsigned int i=0;
    while(i<iterations) {
        if(dlsc_rand_bool(90.0)) {
            int64_t sum = 0;
            data = 0;
            for(unsigned int j=0;j<INPUTS;++j) {
                int64_t val = dlsc_rand(IN_MIN,IN_MAX);
                sum += val;
                val &= IN_MASK;
#if IN_BITS_I <= 64
                data |= ((uint64_t)val) << (j*IN_BITS);
#else
                data.range((j*IN_BITS)+IN_BITS-1,(j*IN_BITS)) = val;
#endif
            }
            uint64_t meta = dlsc_rand_u64(0,META_MASK);

            in_valid    = 1;
            in_data     = data;
            in_meta     = meta;

            sum         &= OUT_MASK;

            check_vals.push_back(sum);
            meta_vals.push_back(meta);

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
    if(out_valid) {
        if(check_vals.empty()) {
            dlsc_error("unexpected output");
        } else {
            dlsc_assert(out_data == check_vals.front());
            dlsc_assert(out_meta == meta_vals.front());
            check_vals.pop_front();
            meta_vals.pop_front();
        }
    }
}

void __MODULE__::watchdog_thread() {
    wait(1,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/




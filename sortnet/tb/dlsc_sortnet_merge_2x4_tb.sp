//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#define INPUTS  8
#define META    8
#define DATA    16
#define ID      8

#define ID_I    (INPUTS*ID)
#define DATA_I  (INPUTS*DATA)

/*AUTOSUBCELL_CLASS*/

struct check_pair {
    unsigned int    id;
    unsigned int    data;
};

struct check_type {
    unsigned int    meta;
    check_pair      val[INPUTS];
};

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
    SP_CELL(dut,Vdlsc_sortnet_merge_2x4);
        /*AUTOINST*/

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);

    SC_METHOD(check_method);
        sensitive << clk.posedge_event();
}

bool compare_pairs(const check_pair &a, const check_pair &b) {
    if(a.data == b.data) return (a.id < b.id);
    return (a.data < b.data);
}

void __MODULE__::run_test(unsigned int iterations) {
    in_valid    = 0;

#if DATA_I <= 64
    uint64_t data;
#else
    sc_bv<DATA_I> data;
#endif

#if ID_I <= 64
    uint64_t id;
#else
    sc_bv<ID_I> id;
#endif

    check_type chk;
    unsigned int i=0;
    while(i<iterations) {
        if(rand()%10) {
            data    = 0;
            id      = 0;
            chk.meta = rand()%((1<<META)-1);
            for(int j=0;j<INPUTS;++j) {
                chk.val[j].id   = (j+1);//rand()%((1<<  ID)-1);
                chk.val[j].data = rand()%((1<<DATA)-1);
            }

            // sort top and bottom halves
            std::sort(chk.val,chk.val+(INPUTS/2),compare_pairs);
            std::sort(chk.val+(INPUTS/2),chk.val+INPUTS,compare_pairs);

            for(int j=0;j<INPUTS;++j) {
#if DATA_I <= 64
                data |= ((uint64_t)chk.val[j].data) << (j*DATA);
#else
                data.range( (j*DATA)+DATA-1, (j*DATA) ) = chk.val[j].data;
#endif

#if ID_I <= 64
                id   |= ((uint64_t)chk.val[j].id  ) << (j*  ID);
#else
                id.range( (j*  ID)+  ID-1, (j*  ID) ) = chk.val[j].id;
#endif
            }

            in_valid    = 1;
            in_meta     = chk.meta;
            in_data     = data;
            in_id       = id;

            // sort whole thing
            std::sort(chk.val,chk.val+INPUTS,compare_pairs);

            check_vals.push_back(chk);

            ++i;
        } else {
            in_valid    = 0;
            in_meta     = 0;
            in_data     = 0;
            in_id       = 0;
        }

        wait(clk.posedge_event());
    }

    in_valid    = 0;
    in_meta     = 0;
    in_data     = 0;
    in_id       = 0;

//    // wait for completion
//    while(!check_vals.empty()) {
//        wait(clk.posedge_event());
//    }
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
    if(rst) {
        check_vals.clear();
        return;
    }
    if(!out_valid) {
        return;
    }
    if(check_vals.empty()) {
        dlsc_error("unexpected data");
        return;
    }

    check_type chk = check_vals.front(); check_vals.pop_front();

    dlsc_assert(out_meta.read() == chk.meta);

    sc_bv<ID_I>     ids     = out_id.read();
    sc_bv<DATA_I>   datas   = out_data.read();

    for(int i=0;i<INPUTS;++i) {
        unsigned int data   = datas.range( (i*DATA)+DATA-1 , (i*DATA) ).to_uint();
        unsigned int id     =   ids.range( (i*  ID)+  ID-1 , (i*  ID) ).to_uint();
        if( data != chk.val[i].data || id != chk.val[i].id )
        {
            dlsc_error("miscompare; expected: data = " << chk.val[i].data << ", id = " << chk.val[i].id << "; but got: data = " << data << ", id = " << id);
        } else {
            dlsc_assert( id == chk.val[i].id && data == chk.val[i].data );
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




//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

// Verilog parameters
#define ADDR        30
#define DATA        32
#define LINE        4
#define SIZE        9
#define USE_WRAP    0

#define LINE_SIZE   (1<<LINE)
#define LINE_MASK   ((((uint64_t)1)<<LINE)-1)

/*AUTOSUBCELL_CLASS*/

struct r_type {
    sc_time     time;
    uint32_t    data;
    uint32_t    resp;
    uint64_t    addr;
    bool        last;
    bool        prefetch;
};

struct hint_type {
    sc_time     time;
    uint64_t    addr;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void ar_method();
    std::deque<uint64_t> ar_prev;

    void r_method();
    std::deque<r_type> r_vals;

    void hint_method();
    std::deque<hint_type> hints;

    void stats_method();
    int stat_cycles;
    int stat_ar_count;
    int stat_ar_prefetch;
    int stat_r_used;
    int stat_r_stall;

    void halt_method();
    bool stim_halt;

    void stim_thread();
    void watchdog_thread();

    int errors_sent;
    r_type errors_latch;

    uint32_t *mem;

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

#define MEM_SIZE (1024*1024)

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,Vdlsc_cpu1_icache);
        /*AUTOINST*/

    rst = 1;

    errors_sent = 0;

    mem = new uint32_t[MEM_SIZE];
    for(int i=0;i<MEM_SIZE;++i)
        mem[i] = (uint32_t)(i);

    SC_METHOD(ar_method);
        sensitive << clk.posedge_event();
    SC_METHOD(r_method);
        sensitive << clk.posedge_event();
    SC_METHOD(hint_method);
        sensitive << clk.posedge_event();
    SC_METHOD(stats_method);
        sensitive << clk.posedge_event();

    stat_cycles     = 0;
    stat_ar_count   = 0;
    stat_ar_prefetch= 0;
    stat_r_used     = 0;
    stat_r_stall    = 0;
    
    SC_METHOD(halt_method);
        sensitive << clk.posedge_event();

    stim_halt = false;

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::halt_method() {
    if(rst) {
        halt_req    = 0;
        return;
    }

    if(stim_halt || (halt_req && !halt_ack)) {
        halt_req    = 1;
        return;
    }

    if(halt_ack) {
        if((rand()%50)==0) {
            halt_req    = 0;
        }
    } else {
        halt_req = (rand()%50000) == 0;
    }
}

void __MODULE__::stats_method() {

    ++stat_cycles;

    if(axi_ar_valid && axi_ar_ready) {
        ++stat_ar_count;
        if(axi_ar_prefetch) {
            ++stat_ar_prefetch;
        }
    }

    if(axi_r_valid) {
        ++stat_r_used;
    }

    if(axi_r_ready && !axi_r_valid) {
        ++stat_r_stall;
    }

}

void __MODULE__::ar_method() {

    if(rst) {
        axi_ar_ready    = 0;
        ar_prev.clear();
        return;
    }
    
    uint64_t addr;
    uint64_t addr_lo;

    if(axi_ar_ready && axi_ar_valid) {

        addr    = axi_ar_addr;

        if(addr >= MEM_SIZE) {
            dlsc_warn("MEM_SIZE exceeded");
            addr    = 0;
        }

        addr_lo = addr & LINE_MASK;
        addr    = addr - addr_lo;

        for(int i=0;i<ar_prev.size();++i) {
            if(ar_prev[i] == addr) {
                dlsc_warn("redundant fetch at 0x" << std::hex << addr);
            }
        }

        ar_prev.push_front(addr);
        if(ar_prev.size() > 2) ar_prev.pop_back();

        r_type rval;

        // ~10 cycle latency
        rval.time = sc_time_stamp() + sc_time(100,SC_NS);
        rval.prefetch = axi_ar_prefetch.read();

        bool err = false;
            
        for(int i=0;i<LINE_SIZE;++i) {
            rval.last   = (i==(LINE_SIZE-1));
            rval.addr   = (addr+addr_lo);

            if(err || rand()%10000) {
                rval.data       = mem[rval.addr];
                rval.resp       = 0;
            } else {
                rval.data       = rand();
                rval.resp       = 1;
                err             = true;
            }

            r_vals.push_back(rval);

            addr_lo = (addr_lo + 1) & LINE_MASK;
        }

    }

    if(!axi_ar_ready || axi_ar_valid) {
        if(rand()%10) {
            axi_ar_ready = 1;
        } else {
            axi_ar_ready = 0;
        }
    }

}

void __MODULE__::r_method() {
    if(rst) {
        axi_r_valid     = 0;
        axi_r_last      = 0;
        axi_r_resp      = 0;
        axi_r_data      = 0;
        r_vals.clear();
        return;
    }

    if(!axi_r_valid || axi_r_ready) {
        if(!r_vals.empty() && r_vals.front().time <= sc_time_stamp() && rand()%10) {
            r_type rval = r_vals.front(); r_vals.pop_front();
            axi_r_valid     = 1;
            axi_r_last      = rval.last;
            axi_r_resp      = rval.resp;
            axi_r_data      = rval.data;
            if(rval.resp != 0) {
                errors_latch = rval;
                ++errors_sent;
            }
        } else {
            axi_r_valid     = 0;
            axi_r_last      = 0;
            axi_r_resp      = 0;
            axi_r_data      = 0;
        }
    }

}

void __MODULE__::hint_method() {
    prefetch_valid  = 0;
    prefetch_addr   = 0;

    if(rst) {
        hints.clear();
        return;
    }

    if(hints.size() < 3 && rand()%100 == 0) {
        hint_type hint;
        if(rand()%2) {
            hint.addr = rand();
        } else {
            hint.addr = in_pc.read() - (rand() % 100);
        }
        hint.addr = hint.addr % (MEM_SIZE-LINE_SIZE);
        hint.time = sc_time_stamp() + sc_time(50,SC_NS);
        prefetch_valid  = 1;
        prefetch_addr   = hint.addr;
        hints.push_back(hint);
    }
}

void __MODULE__::stim_thread() {
    rst = 1;
    wait(1,SC_US);
    wait(clk.negedge_event());
    rst = 0;

    uint64_t addr = 0;
    in_pc.write(addr);
    wait(clk.negedge_event());

    int ops     = 0;
    int cycles  = 0;

    int errors_flagged = 0;

    for(int j=0;j<10;++j) {
        for(int i=0;i<50000;++i) {
            while(out_miss.read()) {
                ++cycles;
                if(err_flag && !err_ack) {
                    ar_prev.clear(); // error will cause redundant fetches; suppress warnings
                    ++errors_flagged;
                    dlsc_assert_equals(errors_flagged,errors_sent);
                    dlsc_assert_equals(errors_latch.addr,err_addr.read());
                    dlsc_assert_equals(errors_latch.prefetch,err_prefetch.read());
                    err_ack = 1;
                }
                if(!err_flag) {
                    err_ack = 0;
                }
                wait(clk.negedge_event());
            }
            dlsc_assert_equals(out_data.read(),mem[addr]);
            if(rand()%30) {
                addr += 1;
            } else if(addr > 50 && rand()%5) {
                addr -= (rand()%50);
            } else if(rand()%3==0) {
                addr = rand() % 100;
            } else {
                if(!hints.empty() && hints.front().time <= sc_time_stamp()) {
                    addr    = hints.front().addr; hints.pop_front();
                } else {
                    addr = rand();
                }
            }
            addr = addr % (MEM_SIZE-LINE_SIZE);
            in_pc.write(addr);
            ++ops;
            ++cycles;
            wait(clk.negedge_event());
        }

        stim_halt = true;
        while(!halt_ack) wait(clk.negedge_event());
        stim_halt = false;

        rst         = 1;

        for(int i=0;i<MEM_SIZE;++i) {
            mem[i] = rand();
        }

        dlsc_info("reset");
        
        wait(clk.negedge_event());
        rst         = 0;
    }

    dlsc_info("cycles per instruction: " << (cycles/(ops*1.0f)));
    dlsc_info("axi_ar_prefetch: " << ((stat_ar_prefetch*100)/stat_ar_count) << "%");
    dlsc_info("axi_r_valid usage: " << ((stat_r_used*100)/stat_cycles) << "%");
    dlsc_info("axi_r_ready stall: " << ((stat_r_stall*100)/stat_r_used) << "%");

    wait(10,SC_US);
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




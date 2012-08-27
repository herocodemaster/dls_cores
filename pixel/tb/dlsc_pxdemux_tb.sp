//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include "dlsc_tlm_initiator_nb.h"

#include <deque>

// for syntax highlighter: SC_MODULE

/*AUTOSUBCELL_CLASS*/

struct out_type {
    bool        last;
    uint32_t    data;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;
    sc_clock csr_clk;

    void clk_method();
    void stim_thread();
    void watchdog_thread();
    
    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);
    dlsc_tlm_initiator_nb<uint32_t> *csr_initiator;

    std::deque<uint32_t> in_queue;
    std::deque<out_type> out_queue[PARAM_STREAMS];

    int cfg_x;
    int cfg_y;
    bool auto_mode;
    std::deque<uint32_t> stream_selects;

    float in_rate;
    float out_rate[PARAM_STREAMS];

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/

public:

    /*AUTOMETHODS*/

};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) :
    clk("clk",8,SC_NS),
    csr_clk("csr_clk",20,SC_NS)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        SP_PIN(dut,px_clk,clk);
        SP_PIN(dut,px_rst,rst);
        /*AUTOINST*/
    
    SP_CELL(csr_master,dlsc_csr_tlm_master_32b);
        SP_PIN(csr_master,clk,csr_clk);
        SP_PIN(csr_master,rst,csr_rst);
        /*AUTOINST*/
    
    csr_initiator   = new dlsc_tlm_initiator_nb<uint32_t>("csr_initiator",1);
    csr_initiator->socket.bind(csr_master->socket);

    rst         = 1;
    csr_rst     = 1;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

const uint32_t REG_CORE_MAGIC      = 0x0;
const uint32_t REG_CORE_VERSION    = 0x1;
const uint32_t REG_CORE_INTERFACE  = 0x2;
const uint32_t REG_CORE_INSTANCE   = 0x3;
const uint32_t REG_CONTROL         = 0x4;
const uint32_t REG_STATUS          = 0x5;
const uint32_t REG_X_RES           = 0x6;
const uint32_t REG_Y_RES           = 0x7;
const uint32_t REG_FIFO_FREE       = 0x8;
const uint32_t REG_STREAM_SELECT   = 0x9;

void __MODULE__::reg_write(uint32_t addr, uint32_t data) {
    csr_initiator->b_write(addr<<2,data);
    dlsc_verb("wrote 0x" << std::hex << addr << " : 0x" << data);
}

uint32_t __MODULE__::reg_read(uint32_t addr) {
    uint32_t data = csr_initiator->b_read(addr<<2);
    dlsc_verb("read 0x" << std::hex << addr << " : 0x" << data);
    return data;
}

void __MODULE__::clk_method() {
    if(rst) {
        px_in_valid     = 0;
        px_in_data      = 0;
        px_out_ready    = 0;
        for(int i=0;i<PARAM_STREAMS;i++) {
            out_queue[i].clear();
        }
        return;
    }

    // ** input **

    if(px_in_ready) px_in_valid = 0;
    if(!in_queue.empty() && (!px_in_valid || px_in_ready) && dlsc_rand_bool(in_rate)) {
        px_in_data = in_queue.front(); in_queue.pop_front();
        px_in_valid = 1;
    }

    // ** outputs **

    uint32_t next_px_out_ready = 0;

    for(int i=0;i<PARAM_STREAMS;i++) {
        if(dlsc_rand_bool(out_rate[i])) {
            next_px_out_ready |= (1<<i);
        }

        if( !(px_out_ready & px_out_valid & (1<<i)) ) {
            continue;
        }

        if(out_queue[i].empty()) {
            dlsc_error("unexpected output");
            continue;
        }

        out_type out = out_queue[i].front(); out_queue[i].pop_front();

        uint32_t data = (px_out_data.read() >> (i*PARAM_BITS)) & ((1ull<<PARAM_BITS)-1ull);
        bool last = (px_out_last & (1<<i));

        dlsc_assert_equals(out.data,data);
        dlsc_assert_equals(out.last,last);
    }

    px_out_ready.write(next_px_out_ready);
}

void __MODULE__::stim_thread() {
    rst     = 1;
    csr_rst = 1;
    wait(1,SC_US);

    uint32_t data;
    
    for(int iterations=0;iterations<30;iterations++) {
        dlsc_info("iteration " << iterations);

        wait(clk.posedge_event());
        rst     = 0;
        wait(clk.posedge_event());
        wait(csr_clk.posedge_event());
        csr_rst = 0;
        wait(csr_clk.posedge_event());

        // check common registers
        data = reg_read(REG_CORE_MAGIC);
        dlsc_assert_equals(data,0xa4b885ed);
        data = reg_read(REG_CORE_VERSION);
        dlsc_assert_equals(data,0x20120826);
        data = reg_read(REG_CORE_INTERFACE);
        dlsc_assert_equals(data,0x20120826);
        data = reg_read(REG_CORE_INSTANCE);
        dlsc_assert_equals(data,PARAM_CORE_INSTANCE);
        
        int fifo_depth = reg_read(REG_FIFO_FREE);

        // randomize rates
        in_rate = 0.1 * dlsc_rand(200,1000);
        for(int i=0;i<PARAM_STREAMS;i++) {
            out_rate[i] = 0.1 * dlsc_rand(200,1000);
        }

        // randomize config
        switch(dlsc_rand(0,9)) {
            case 3:
                cfg_x   = PARAM_MAX_H;
                cfg_y   = dlsc_rand(2,10);
                break;
            case 7:
                cfg_x   = dlsc_rand(2,10);
                cfg_y   = PARAM_MAX_V;
                break;
            default:
                cfg_x   = dlsc_rand(50,300);
                cfg_y   = dlsc_rand(50,300);
        }
        auto_mode           = dlsc_rand_bool(50.0);
        int fifo_entries    = auto_mode ? dlsc_rand(1,fifo_depth) : dlsc_rand(1,fifo_depth*2);
        int frames          = auto_mode ? dlsc_rand(1,fifo_entries*2) : dlsc_rand(1,fifo_entries);

        dlsc_info("auto_mode:    " << auto_mode);
        dlsc_info("cfg_x:        " << cfg_x);
        dlsc_info("cfg_y:        " << cfg_y);
        dlsc_info("fifo_entries: " << fifo_entries);
        dlsc_info("frames:       " << frames);

        // create select sequence
        stream_selects.clear();
        while((int)stream_selects.size() < fifo_entries) {
            stream_selects.push_back(dlsc_rand(0,((1<<PARAM_STREAMS)-1)));
        }

        // create frames
        for(int f=0;f<frames;f++) {
            for(int y=0;y<cfg_y;y++) {
                for(int x=0;x<cfg_x;x++) {
                    out_type out;
                    out.last    = (y == (cfg_y-1)) && (x == (cfg_x-1));
                    out.data    = dlsc_rand_u32(0,((1u<<PARAM_BITS)-1u));
                    in_queue.push_back(out.data);
                    for(int i=0;i<PARAM_STREAMS;i++) {
                        if(stream_selects[f%stream_selects.size()] & (1<<i)) {
                            out_queue[i].push_back(out);
                        }
                    }
                }
            }
        }

        // write config
        reg_write(REG_X_RES,cfg_x);
        reg_write(REG_Y_RES,cfg_y);

        if(auto_mode) {
            while(!stream_selects.empty()) {
                reg_write(REG_STREAM_SELECT,stream_selects.front());
                stream_selects.pop_front();
            }
        }

        // enable
        reg_write(REG_CONTROL,0x1 | (auto_mode ? 0x2 : 0x0));

        // wait for completion
        bool done = false;
        while(!done) {
            wait(dlsc_rand(1000,10000),SC_NS);
            done = in_queue.empty();
            for(int i=0;i<PARAM_STREAMS;i++) {
                if(!out_queue[i].empty()) done = false;
            }
            if(stream_selects.empty()) continue;

            data = reg_read(REG_STATUS);
            if(!(data & (1u<<1)) && dlsc_rand_bool(99.0)) continue;

            data = reg_read(REG_FIFO_FREE);
            if(data<1) continue;

            int updates = dlsc_rand(1,std::min((int)data,(int)stream_selects.size()));
            for(int i=0;i<updates;i++) {
                reg_write(REG_STREAM_SELECT,stream_selects.front());
                stream_selects.pop_front();
            }                
        }

        // check configuration
        data = reg_read(REG_CONTROL);
        dlsc_assert_equals(data, 0x1 | (auto_mode ? 0x2 : 0x0));
        data = reg_read(REG_X_RES);
        dlsc_assert_equals(data, cfg_x);
        data = reg_read(REG_Y_RES);
        dlsc_assert_equals(data, cfg_y);

        // disable
        reg_write(REG_CONTROL,0x0);

        // reset
        if(dlsc_rand_bool(50.0)) {
            wait(clk.posedge_event());
            rst = 1;
            wait(clk.posedge_event());
        }
        if(dlsc_rand_bool(50.0)) {
            wait(csr_clk.posedge_event());
            csr_rst = 1;
            wait(csr_clk.posedge_event());
        }
        
        // wait
        if(dlsc_rand_bool(50.0)) {
            wait(1,SC_US);
        }
    }

    wait(10,SC_US);

    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    for(int i=0;i<200;i++) {
        wait(5,SC_MS);
        dlsc_info(". " << in_queue.size() << " " << out_queue[0].size());
    }

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/


//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include "dlsc_tlm_initiator_nb.h"

#include <deque>

// for syntax highlighter: SC_MODULE

#define PX_MAX ((1<<PARAM_BITS)-1)

/*AUTOSUBCELL_CLASS*/

struct px_type {
    bool        last;
    uint32_t    data[PARAM_CHANNELS];
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

    std::deque<px_type> in_queue;
    std::deque<px_type> out_queue;

    int cfg_x;
    int cfg_y;
    bool auto_mode;
    std::deque<px_type> gains;

    float in_rate;
    float out_rate;

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
const uint32_t REG_CHANNELS        = 0x8;
const uint32_t REG_MAX_GAIN        = 0x9;
const uint32_t REG_POST_DIVIDER    = 0xA;
const uint32_t REG_FIFO_FREE       = 0xB;
const uint32_t REG_GAIN0           = 0xC;
const uint32_t REG_GAIN1           = 0xD;
const uint32_t REG_GAIN2           = 0xE;
const uint32_t REG_GAIN3           = 0xF;

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
        in_queue.clear();
        out_queue.clear();
        return;
    }

    // ** input **

    if(px_in_ready) px_in_valid = 0;
    if(!in_queue.empty() && (!px_in_valid || px_in_ready) && dlsc_rand_bool(in_rate)) {
        px_type px = in_queue.front(); in_queue.pop_front();
        uint64_t data = 0;
        for(int i=0;i<PARAM_CHANNELS;i++) {
            data |= (px.data[i] & PX_MAX) << (i*PARAM_BITS);
        }
        px_in_data.write(data);
        px_in_valid = 1;
    }

    // ** output **

    if(px_out_ready && px_out_valid) {
        if(out_queue.empty()) {
            dlsc_error("unexpected output");
        } else {
            px_type px = out_queue.front(); out_queue.pop_front();
            dlsc_assert_equals(px.last,px_out_last);
            for(int i=0;i<PARAM_CHANNELS;i++) {
                uint32_t data = (px_out_data.read() >> (i*PARAM_BITS)) & PX_MAX;
                dlsc_assert_equals(px.data[i],data);
            }
        }
    }

    px_out_ready = dlsc_rand_bool(out_rate);
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
        dlsc_assert_equals(data,0xecdc2d4d);
        data = reg_read(REG_CORE_VERSION);
        dlsc_assert_equals(data,0x20120826);
        data = reg_read(REG_CORE_INTERFACE);
        dlsc_assert_equals(data,0x20120826);
        data = reg_read(REG_CORE_INSTANCE);
        dlsc_assert_equals(data,PARAM_CORE_INSTANCE);
        
        int fifo_depth = reg_read(REG_FIFO_FREE);

        // randomize rates
        in_rate = 0.1 * dlsc_rand(200,1000);
        out_rate = 0.1 * dlsc_rand(200,1000);

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

        // create gain sequence
        gains.clear();
        while((int)gains.size() < fifo_entries) {
            px_type gain;
            for(int i=0;i<PARAM_CHANNELS;i++) {
                gain.data[i] = dlsc_rand(0,((1<<PARAM_GAINB)-1));
            }
            gains.push_back(gain);
        }

        // create frames
        for(int f=0;f<frames;f++) {
            for(int y=0;y<cfg_y;y++) {
                for(int x=0;x<cfg_x;x++) {
                    px_type out;
                    out.last    = (y == (cfg_y-1)) && (x == (cfg_x-1));
                    // create pixel
                    for(int i=0;i<PARAM_CHANNELS;i++) {
                        out.data[i] = dlsc_rand_u32(0,PX_MAX);
                    }
                    in_queue.push_back(out);
                    // apply gains
                    px_type gain = gains[f%gains.size()];
                    for(int i=0;i<PARAM_CHANNELS;i++) {
                        uint64_t d = out.data[i] * gain.data[i];
                        d >>= PARAM_DIVB;
                        if(d > PX_MAX) d = PX_MAX;
                        out.data[i] = d;
                    }
                    out_queue.push_back(out);
                }
            }
        }

        // write config
        reg_write(REG_X_RES,cfg_x);
        reg_write(REG_Y_RES,cfg_y);

        if(auto_mode) {
            while(!gains.empty()) {
                for(int i=0;i<PARAM_CHANNELS;i++) {
                    reg_write(REG_GAIN0+i,gains.front().data[i]);
                }
                gains.pop_front();
            }
        }

        // enable
        reg_write(REG_CONTROL,0x1 | (auto_mode ? 0x2 : 0x0));

        // wait for completion
        while(!(in_queue.empty() && out_queue.empty())) {
            wait(dlsc_rand(1000,10000),SC_NS);
            if(gains.empty()) continue;

            data = reg_read(REG_STATUS);
            if(!(data & (1u<<1)) && dlsc_rand_bool(99.0)) continue;

            data = reg_read(REG_FIFO_FREE);
            if(data<1) continue;

            int updates = dlsc_rand(1,std::min((int)data,(int)gains.size()));
            for(int j=0;j<updates;j++) {
                for(int i=0;i<PARAM_CHANNELS;i++) {
                    reg_write(REG_GAIN0+i,gains.front().data[i]);
                }
                gains.pop_front();
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
        dlsc_info(". " << in_queue.size() << " " << out_queue.size());
    }

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/


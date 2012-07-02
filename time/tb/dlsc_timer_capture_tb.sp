//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include "dlsc_tlm_initiator_nb.h"

#include <deque>

// for syntax highlighter: SC_MODULE

/*AUTOSUBCELL_CLASS*/

struct channel_state {
    int source;
    bool pos;
    bool neg;
    int prescaler;
    int ps_cnt;
    int events;
    std::deque<uint64_t> time_q;
    std::deque<uint32_t> state_q;
    std::deque<uint32_t> meta_q;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void clk_method();
    void stim_thread();
    void watchdog_thread();
    
    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);
    dlsc_tlm_initiator_nb<uint32_t> *csr_initiator;

    double rates[PARAM_INPUTS];

    bool enabled;
    channel_state channels[PARAM_CHANNELS];

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
    clk("clk",10,SC_NS)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/
    
    SP_CELL(csr_master,dlsc_csr_tlm_master_32b);
        /*AUTOINST*/
    
    csr_initiator   = new dlsc_tlm_initiator_nb<uint32_t>("csr_initiator",1);
    csr_initiator->socket.bind(csr_master->socket);

    rst         = 1;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

const uint32_t REG_CORE_MAGIC      = 0x00;
const uint32_t REG_CORE_VERSION    = 0x01;
const uint32_t REG_CORE_INTERFACE  = 0x02;
const uint32_t REG_CORE_INSTANCE   = 0x03;
const uint32_t REG_CONTROL         = 0x04;
const uint32_t REG_STATUS          = 0x05;
const uint32_t REG_INT_FLAGS       = 0x06;
const uint32_t REG_INT_SELECT      = 0x07;
const uint32_t REG_FIFO_COUNT      = 0x08;
const uint32_t REG_FIFO_CHANNEL    = 0x09;
const uint32_t REG_FIFO_META       = 0x0A;
const uint32_t REG_FIFO_LOW        = 0x0B;
const uint32_t REG_FIFO_HIGH       = 0x0C;
const uint32_t REG_SOURCE          = 0x10;
const uint32_t REG_PRESCALER       = 0x20;
const uint32_t REG_EVENT           = 0x30;

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
        enabled     = false;
        for(int i=0;i<PARAM_CHANNELS;i++) {
            channel_state &ch = channels[i];
            ch.source       = i;
            ch.pos          = false;
            ch.neg          = false;
            ch.prescaler    = 0;
        }
    }
    
    if(!enabled) {
        for(int i=0;i<PARAM_CHANNELS;i++) {
            channel_state &ch = channels[i];
            ch.ps_cnt       = 0;
            ch.events       = 0;
            ch.time_q.clear();
            ch.state_q.clear();
            ch.meta_q.clear();
        }
        timebase_cnt.write(0);
        trigger.write(0);
        meta.write(0);
        return;
    }
    
    uint64_t time   = timebase_cnt.read() + 1;//dlsc_rand_u64();
    uint64_t inputs = trigger.read();
    uint64_t prev   = inputs;
    uint32_t metas[PARAM_INPUTS];

    for(int i=0;i<PARAM_INPUTS;i++) {
        metas[i] = dlsc_rand_u32(0,(1u<<PARAM_META)-1);
        if(dlsc_rand_bool(rates[i])) {
            inputs ^= (1ull << i);
        }
    }

    timebase_cnt.write(time);
    trigger.write(inputs);

#if ((PARAM_INPUTS*PARAM_META) <= 64)
    uint64_t data = 0;
    for(int i=0;i<PARAM_INPUTS;i++) {
        data |= metas[i] << (i*PARAM_META);
    }
#else
    sc_bv<PARAM_INPUTS*PARAM_META> data = 0;
    for(int i=0;i<PARAM_INPUTS;i++) {
        data.range( ((i+1)*PARAM_META)-1 , (i*PARAM_META) ) = metas[i];
    }
#endif
    meta.write(data);

    uint64_t rise   = (~prev) & ( inputs);
    uint64_t fall   = ( prev) & (~inputs);

    uint32_t states = 0;
    for(int i=0;i<PARAM_CHANNELS;i++) {
        channel_state &ch = channels[i];
        if(inputs & (1ull << ch.source)) {
            states |= (1u << i);
        }
    }

    for(int i=0;i<PARAM_CHANNELS;i++) {
        channel_state &ch = channels[i];
        assert(ch.source >= 0 && ch.source < PARAM_INPUTS);
        if( (ch.pos && (rise & (1ull << ch.source))) ||
            (ch.neg && (fall & (1ull << ch.source))) )
        {
            ch.events++;
            if(ch.ps_cnt == ch.prescaler) {
                ch.ps_cnt = 0;
                ch.time_q.push_back(time);
                ch.state_q.push_back(states);
                ch.meta_q.push_back(metas[ch.source]);
            } else {
                ch.ps_cnt++;
            }
        }
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(1,SC_US);
    wait(clk.posedge_event());
    rst     = 0;
    wait(1,SC_US);

    uint32_t data;

    for(int iterations=0;iterations<5;iterations++) {
        dlsc_info("iteration " << iterations);

        wait(clk.posedge_event());
        rst     = 0;
        wait(clk.posedge_event());
        assert(!enabled);

        // setup inputs
        for(int i=0;i<PARAM_INPUTS;i=i+1) {
            rates[i] = 0.01 * dlsc_rand(1,100);
        }

        // check common registers
        data = reg_read(REG_CORE_MAGIC);
        dlsc_assert_equals(data,0xFA2D8F2A);
        data = reg_read(REG_CORE_VERSION);
        dlsc_assert_equals(data,0x20120607);
        data = reg_read(REG_CORE_INTERFACE);
        dlsc_assert_equals(data,0x20120607);
        data = reg_read(REG_CORE_INSTANCE);
        dlsc_assert_equals(data,PARAM_CORE_INSTANCE);

        // setup capture channels
        for(int i=0;i<PARAM_CHANNELS;i++) {
            channel_state &ch = channels[i];
            ch.source   = PARAM_NOMUX ? i : dlsc_rand(0,PARAM_INPUTS-1);
            ch.pos      = dlsc_rand_bool(50.0);
            ch.neg      = dlsc_rand_bool(50.0);
            if(dlsc_rand_bool(50.0)) {
                ch.prescaler    = 0;
            } else {
                ch.prescaler    = dlsc_rand(0,(1<<PARAM_PBITS)-1);
            }
            data = ch.source | (ch.pos ? 0x100 : 0) | (ch.neg ? 0x200 : 0);
            reg_write(REG_SOURCE+i,data);
            reg_write(REG_PRESCALER+i,ch.prescaler);
        }

        // setup interrupts
        data = dlsc_rand_u32();
        reg_write(REG_INT_SELECT,data);
        
        // enable
        reg_write(REG_CONTROL,0x1);
        enabled = true;

        // monitor event FIFO
        for(int j=0;j<10000;j++) {
            wait(dlsc_rand(10,1000),SC_NS);

            if(!( (csr_int && dlsc_rand_bool(75.0)) || dlsc_rand_bool(10.0) )) continue;

            uint32_t int_flags = reg_read(REG_INT_FLAGS);
            uint32_t int_flags_next = int_flags & 0xFFFF; // don't clear event loss flags until we're done with them

            int fifo_count = dlsc_rand(-(PARAM_DEPTH/2),(PARAM_DEPTH/2));
            
            if(dlsc_rand_bool(50.0)) {
                fifo_count += (int)reg_read(REG_FIFO_COUNT);
            }

            for(int i=0;i<fifo_count;i++) {
                data = reg_read(REG_FIFO_CHANNEL);
                if(data & 0x80000000) break;

                int channel = (data >> 16) & 0xF;
                uint32_t ff_states = (data & 0xFFFF);

                uint32_t ff_meta = reg_read(REG_FIFO_META);

                uint64_t ff_time = reg_read(REG_FIFO_LOW);
                ff_time |= ((uint64_t)reg_read(REG_FIFO_HIGH) << 32);

                if(channel < 0 || channel >= PARAM_CHANNELS) {
                    dlsc_error("invalid channel: " << channel);
                    continue;
                }

                while(true) {
                    channel_state &ch = channels[channel];
                    
                    if(ch.time_q.empty() || ch.state_q.empty() || ch.meta_q.empty()) {
                        dlsc_error("channel FIFO empty: " << channel);
                        break;
                    }

                    uint32_t ch_states  = ch.state_q.front(); ch.state_q.pop_front();
                    uint32_t ch_meta    = ch.meta_q.front(); ch.meta_q.pop_front();
                    uint64_t ch_time    = ch.time_q.front(); ch.time_q.pop_front();

                    if( (int_flags & (0x10000<<channel)) && (ch_states != ff_states || ch_meta != ff_meta || ch_time != ff_time) ) {
                        // ignore mismatch if event(s) were lost
                        dlsc_info("ignoring possible mismatch due to event loss flag: " << channel);
                        continue;
                    }

                    dlsc_assert_equals(ch_states,ff_states);
                    dlsc_assert_equals(ch_meta,  ff_meta);
                    dlsc_assert_equals(ch_time,  ff_time);

                    break;
                }
            }

            if(dlsc_rand_bool(25.0)) {
                for(int i=0;i<PARAM_CHANNELS;i++) {
                    if(dlsc_rand_bool(75.0)) continue;
                    channel_state &ch = channels[i];

                    data = reg_read(REG_EVENT+i);
                    if(data & 0x80000000) {
                        // overflowed
                        dlsc_info("counter overflow: " << i);
                        dlsc_assert(ch.events >= (1<<PARAM_EBITS));
                        ch.events &= ((1<<PARAM_EBITS)-1);
                        data &= 0x7FFFFFFF;
                    }

                    int diff = ch.events - (int)data;
                    if(diff >= 0 && diff <= 2) {
                        dlsc_okay("event counter okay: " << i << ", " << ch.events << ", " << (int)data);
                    } else {
                        dlsc_error("event counter mismatch: " << i << ", " << ch.events << ", " << (int)data);
                    }

                    ch.events -= (int)data;
                }
            }

            reg_write(REG_INT_FLAGS,int_flags_next);
        }
        
        // disable
        if(dlsc_rand_bool(50.0)) {
            reg_write(REG_CONTROL,0x0);
            enabled = false;
        }

        // reset
        if(enabled || dlsc_rand_bool(50.0)) {
            wait(clk.posedge_event());
            rst     = 1;
        }

        // wait a bit
        if(dlsc_rand_bool(50.0)) {
            wait(1,SC_MS);
        }
    }

    wait(1,SC_MS);

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


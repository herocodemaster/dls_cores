//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include <deque>

#include "dlsc_bv.h"
#include "dlsc_random.h"

// for syntax highlighter: SC_MODULE

/*AUTOSUBCELL_CLASS*/

int const WINX          = PARAM_WINX;
int const WINY          = PARAM_WINY;

int const CENX          = WINX/2;
int const CENY          = WINY/2;

int const BITS          = PARAM_BITS;
uint32_t const PX_MAX   = ((1ull<<BITS)-1ull);

int const MIN_WIDTH     = WINX;
int const MAX_WIDTH     = PARAM_MAXX;
int const MIN_HEIGHT    = WINY;
int const MAX_HEIGHT    = (1<<PARAM_YB);

bool const EM_FILL      = (PARAM_EDGE_MODE == 1);
bool const EM_REPEAT    = (PARAM_EDGE_MODE == 2);
bool const EM_BAYER     = (PARAM_EDGE_MODE == 3);
bool const EM_NONE      = !(EM_FILL || EM_REPEAT || EM_BAYER);

struct InType
{
    uint32_t data;
    bool unmask;
};

struct OutType
{
    dlsc_bv<WINY,BITS> data;
    int x;
    int y;
    bool unmask;
    bool last;
    bool last_x;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void ClkMethod();
    void StimThread();
    void WatchdogThread();

    dlsc_random rng_;

    double in_rate_;

    std::deque<InType> in_queue_;
    std::deque<OutType> fc_queue_;
    std::deque<OutType> out_queue_;
    bool fc_done_;
    bool out_done_;

    int width_;
    int height_;
    InType fill_;
    InType * frame_;

    void RandomizeFrame();
    InType GetPx(int y, int x);

    void RunTest();
    
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
    clk("clk",10,SC_NS),
    in_rate_(1.0),
    fc_done_(false),
    out_done_(false),
    width_(1),
    height_(1),
    frame_(NULL)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    rst         = 1;

    SC_METHOD(ClkMethod);
        sensitive << clk.posedge_event();

    SC_THREAD(StimThread);
    SC_THREAD(WatchdogThread);
}

void __MODULE__::ClkMethod()
{
    if(rst)
    {
        fc_okay     = 0;
        in_valid    = 0;
        in_unmask   = 0;
        in_data     = 0;
        fc_done_    = false;
        out_done_   = false;
        return;
    }

    // ** input **

    if(in_ready) {
        in_valid    = 0;
    }

    if((!in_valid || in_ready) && rng_.rand_bool(in_rate_))
    {
        if(!in_queue_.empty() && rng_.rand_bool(0.995)) {
            InType const & in = in_queue_.front();
            in_valid    = 1;
            in_unmask   = in.unmask;
            in_data     = in.data;
            in_queue_.pop_front();
        } else {
            in_valid    = 1;
            in_unmask   = 0;
            in_data     = rng_.rand<uint32_t>(0,PX_MAX);
        }
    }

    // ** flow control **

    if(fc_okay) {
        if(rng_.rand_bool(0.005)) {
            fc_okay = 0;
        }
    } else {
        if(rng_.rand_bool(0.02)) {
            fc_okay = 1;
        }
    }

    if(fc_valid)
    {
        if(fc_queue_.empty()) {
            if(fc_unmask || !fc_done_) {
                dlsc_error("unexpected flow control data");
            }
        } else {
            OutType const & out = fc_queue_.front();

            bool const unmask   = fc_unmask.read();
            bool const last     = fc_last.read();
            bool const last_x   = fc_last_x.read();

            bool const mismatch = !((out.unmask == unmask) && (out.last == last) && (out.last_x == last_x));

            if(mismatch) {
                dlsc_error("flow control mismatch at (" << out.y << "," << out.x << "):");
                if(out.unmask != unmask) {
                    dlsc_error("    unmask = " << out.unmask << " != " << unmask);
                }
                if(out.last != last) {
                    dlsc_error("    last   = " << out.last   << " != " << last);
                }
                if(out.last_x != last_x) {
                    dlsc_error("    last_x = " << out.last_x << " != " << last_x);
                }
            } else {
                dlsc_okay("flow control okay");
            }

            if(out.last) {
                fc_done_ = true;
            }

            fc_queue_.pop_front();
        }
    }

    // ** output **

    if(out_valid)
    {
        if(out_queue_.empty()) {
            if(out_unmask || !out_done_) {
                dlsc_error("unexpected output data");
            }
        } else {
            OutType const & out = out_queue_.front();

            bool const unmask   = out_unmask.read();
            bool const last     = out_last.read();
            bool const last_x   = out_last_x.read();
            dlsc_bv<WINY,BITS> const data = out_data.read();

            bool mismatch = !((out.unmask == unmask) && (out.last == last) && (out.last_x == last_x));
            for(int i=0;i<WINY;++i) {
                if(out.data[i] != data[i]) {
                    mismatch = true;
                    break;
                }
            }

            if(mismatch) {
                dlsc_error("output mismatch at (" << out.y << "," << out.x << "):");
                if(out.unmask != unmask) {
                    dlsc_error("    unmask = " << out.unmask << " != " << unmask);
                }
                if(out.last != last) {
                    dlsc_error("    last   = " << out.last   << " != " << last);
                }
                if(out.last_x != last_x) {
                    dlsc_error("    last_x = " << out.last_x << " != " << last_x);
                }
                for(int i=0;i<WINY;++i) {
                    if(out.data[i] != data[i]) {
                        dlsc_error("    data[" << i << "] = 0x" << std::hex << out.data[i] << " != 0x" << std::hex << data[i]);
                    }
                }
            } else {
                dlsc_okay("output okay");
            }

            if(out.last) {
                out_done_ = true;
            }

            out_queue_.pop_front();
        }
    }

    dlsc_assert_equals(out_done_,done);
}

void __MODULE__::RandomizeFrame()
{
    if(frame_) {
        delete[] frame_;
        frame_ = NULL;
    }
    
    assert(width_ > 0 && height_ > 0);

    frame_ = new InType[width_*height_];

    for(int y=0;y<height_;++y) {
        for(int x=0;x<width_;++x) {
            InType & px = frame_[x+y*width_];
            px.unmask = true;
            px.data = rng_.rand<uint32_t>(0,PX_MAX);
            //px.data = (((y+1)&0xFFFF) << 16) | ((x+1)&0xFFFF);
        }
    }
}

InType __MODULE__::GetPx(int y, int x)
{
    if(EM_FILL)
    {
        if(!(y >= 0 && y < height_ && x >= 0 && x < width_)) {
            return fill_;
        }
    }
    if(EM_REPEAT)
    {
        y = std::max(y, 0);
        y = std::min(y, height_-1);
        x = std::max(x, 0);
        x = std::min(x, width_-1);
    }
    if(EM_BAYER)
    {
        // TODO
        assert(0);
    }

    assert(y >= 0 && y < height_ && x >= 0 && x < width_);
    return frame_[x+y*width_];
}

void __MODULE__::RunTest()
{
    in_rate_        = rng_.rand_bool(0.5) ? 1.0 : rng_.rand(0.1,1.0);

    switch(rng_.rand(0,9))
    {
        case 0:
        {
            width_      = MIN_WIDTH;
            height_     = rng_.rand(MIN_HEIGHT,MAX_HEIGHT);
            break;
        }
        case 1:
        {
            width_      = MAX_WIDTH;
            int const max_height = std::max(MIN_HEIGHT,std::min(MAX_HEIGHT,100000/width_));
            height_     = rng_.rand(MIN_HEIGHT,max_height);
        }
        case 2:
        {
            height_     = MIN_HEIGHT;
            width_      = rng_.rand(MIN_WIDTH,MAX_WIDTH);
            break;
        }
        case 3:
        {
            height_     = MAX_HEIGHT;
            int const max_width = std::max(MIN_WIDTH,std::min(MAX_WIDTH,100000/height_));
            width_      = rng_.rand(MIN_WIDTH,max_width);
            break;
        }
        case 4:
        case 5:
        case 6:
        {
            width_      = rng_.rand(MIN_WIDTH,MAX_WIDTH);
            int const max_height = std::max(MIN_HEIGHT,std::min(MAX_HEIGHT,100000/width_));
            height_     = rng_.rand(MIN_HEIGHT,max_height);
            break;
        }
        default:
        {
            height_     = rng_.rand(MIN_HEIGHT,MAX_HEIGHT);
            int const max_width = std::max(MIN_WIDTH,std::min(MAX_WIDTH,100000/height_));
            width_      = rng_.rand(MIN_WIDTH,max_width);
            break;
        }
    }

    fill_.unmask    = true;
    fill_.data      = rng_.rand<uint32_t>(0,PX_MAX);
    
    int const end_height = rng_.rand_bool(0.7) ? height_ : (height_ + rng_.rand(0,height_));

    dlsc_info(" in_rate:    " << in_rate_);
    dlsc_info(" width:      " << width_);
    dlsc_info(" height:     " << height_);
    dlsc_info(" end_height: " << end_height);

    RandomizeFrame();
    
    wait(clk.posedge_event());
    rst             = 1;
    wait(clk.posedge_event());
        
    // hold reset
    for(int i=0;i<34;++i) {
        wait(clk.posedge_event());
    }

    wait(clk.posedge_event());
    cfg_x           = width_-1;
    cfg_y           = height_-1;
    cfg_fill        = fill_.data;
    wait(clk.posedge_event());
    wait(clk.posedge_event());
    rst             = 0;
    wait(clk.posedge_event());

    in_queue_.clear();
    fc_queue_.clear();
    out_queue_.clear();

    // create input

    for(int y=0;y<height_;++y) {
        for(int x=0;x<width_;++x) {
            in_queue_.push_back(GetPx(y,x));
        }
    }

    // create output

    if(EM_NONE)
    {
        // TODO
        assert(0);
    }
    else
    {
        for(int by=0;by<end_height;++by)
        {
            for(int x=-CENX;x<(width_+CENX);++x)
            {
                OutType out;
                out.x       = x;
                out.y       = by;
                out.unmask  = (x >= 0 && x < width_ && by < height_);
                out.last_x  = (x  == (width_ -1));
                out.last    = (by == (height_-1)) && out.last_x;
                for(int dy=0;dy<WINY;++dy)
                {
                    InType const px = GetPx(by+dy-CENY,x);
                    out.data[dy] = px.data;
                }
                fc_queue_.push_back(out);
                out_queue_.push_back(out);
            }
        }
    }

    while(!(in_queue_.empty() && fc_queue_.empty() && out_queue_.empty())) {
        wait(1,SC_US);
    }
    
    wait(clk.posedge_event());
    rst = 1;
    wait(clk.posedge_event());
}

void __MODULE__::StimThread()
{
    rst     = 1;
    wait(1,SC_US);
    wait(clk.posedge_event());

    int const iterations = 100;
    for(int iteration=0;iteration<iterations;++iteration)
    {
        dlsc_info("** iteration " << (iteration+1) << "/" << iterations << " **");
        RunTest();
    }

    wait(10,SC_US);

    dut->final();
    sc_stop();
}

void __MODULE__::WatchdogThread() {
    for(int i=0;i<50;i++) {
        wait(10,SC_MS);
        dlsc_info(". " << in_queue_.size() << " " << fc_queue_.size() << " " << out_queue_.size());
    }

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/


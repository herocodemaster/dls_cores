
#include <iostream>
#include <deque>
#include <algorithm>
#include <numeric>

#include "dlsc_stereobm_models.h"

void dlsc_xsobel(
    const cv::Mat &in,
    cv::Mat &out,
    const dlsc_stereobm_params &params
) {

    for(int y=0;y<in.rows;++y) {

        const uint8_t *r0 = y > 0             ? in.ptr<uint8_t>(y-1) : in.ptr<uint8_t>(y+1);
        const uint8_t *r1 = in.ptr<uint8_t>(y);
        const uint8_t *r2 = y < (in.rows-1)   ? in.ptr<uint8_t>(y+1) : in.ptr<uint8_t>(y-1);

        uint8_t *d      = out.ptr<uint8_t>(y);

        d[0]            = (uint8_t)(params.data_max/2);
        d[in.cols-1]    = (uint8_t)(params.data_max/2);

        for(int x=1;x<(in.cols-1);++x) {
            
            int d0  = r0[x+1] - r0[x-1];
            int d1  = r1[x+1] - r1[x-1];
            int d2  = r2[x+1] - r2[x-1];

            int v   = d0 + 2*d1 + d2 + (params.data_max/2);

            if(v < 0) v = 0;
            else if(v > params.data_max) v = params.data_max;

            d[x]    = (uint8_t)v;

        }

    }

}

void dlsc_stereobm(
    cv::Mat &il,
    cv::Mat &ir,
    cv::Mat &id,
    cv::Mat &valid,
    cv::Mat &filtered,
    const dlsc_stereobm_params &params
) {
    std::deque<uint8_t*> rowsl;         // pointers to rows within current window
    std::deque<uint8_t*> rowsr;         // ""

    std::deque<int> sad_delay;          // delay-line for accumulating column sums into a window
    
    int *disps      = new int[il.cols];
    int *sads       = new int[il.cols];
    int *sads_thresh= new int[il.cols];
    int *sads_prev  = new int[il.cols]; // sad[d-1]
    int *sads_lo    = new int[il.cols]; // sad[mind-1]
    int *sads_hi    = new int[il.cols]; // sad[mind+1]

    // initialize to zero, so values outside of usable area are zeroed
    id          = cv::Mat::zeros(il.rows,il.cols,CV_16S);
    valid       = cv::Mat::zeros(il.rows,il.cols,CV_8UC1);
    filtered    = cv::Mat::zeros(il.rows,il.cols,CV_8UC1);

    // process all rows
    for(int y = 0; y < il.rows; ++y) {
        // accumulate pointers to rows within the params.sad_window window
        rowsl.push_back(il.ptr<uint8_t>(y));
        rowsr.push_back(ir.ptr<uint8_t>(y));

        // can only compute disparities once we have enough rows for a complete params.sad_window window
        if(y >= (params.sad_window-1)) {
            short *dptr = id.ptr<short>(y-(params.sad_window/2));
            uint8_t *vptr = valid.ptr<uint8_t>(y-(params.sad_window/2));
            uint8_t *fptr = filtered.ptr<uint8_t>(y-(params.sad_window/2));

            // initialize row disparity buffer
            for(int x=0;x<il.cols;++x) {
                disps[x]        = 0;
                sads[x]         = INT_MAX/256;
                sads_thresh[x]  = INT_MAX/256;
                sads_prev[x]    = INT_MAX/256;
                sads_lo[x]      = INT_MAX/256;
                sads_hi[x]      = INT_MAX/256;
            }

            // process one disparity level at a time
            for(int d=0;d<params.disparities;++d) {
                int sad_accum = 0;
                sad_delay.clear();
                // process whole row at this disparity
//                for(int x=params.disparities-1;x<il.cols;++x) {
                for(int x=0;x<il.cols;++x) {
                    if(d>x) continue;
                    // sum column
                    int sad = 0;
                    for(int ys=0;ys<params.sad_window;++ys)
                        sad += abs((int)(rowsl[ys][x]) - (int)(rowsr[ys][x-d]));
                    
                    // accumulate window
                    sad_accum += sad;
                    sad_delay.push_back(sad);

                    // once window is filled, produce output
                    if(sad_delay.size()==(unsigned int)params.sad_window) {
                        int xd          = x - (params.sad_window/2);

                        // ** keep track of best sad **
                        if(sad_accum <= sads[xd]) { // favors newer/higher disparities
                            // update thresh
                            if(disps[xd] != (d-1)) {
                                // previous disp is not within exclusion window, so we can use it
                                sads_thresh[xd] = sads[xd];
                            } else {
                                // find best of previous disps's thresh and lo
                                if(sads_lo[xd] < sads_thresh[xd]) {
                                    sads_thresh[xd] = sads_lo[xd];
                                }
                            }
                            // update disp/sad
                            disps[xd]       = d;
                            sads[xd]        = sad_accum;
                        } else if(sad_accum < sads_thresh[xd] && disps[xd] != (d-1)) {
                            sads_thresh[xd] = sad_accum;
                        }

                        // ** keep track of adjacent sads **
                        if(disps[xd] == d) {
                            // capture sad[mind-1]
                            sads_lo[xd]     = sads_prev[xd];
                        }                        
                        if(disps[xd] == (d-1)) {
                            // capture sad[mind+1]
                            sads_hi[xd]     = sad_accum;
                        }
                        sads_prev[xd]   = sad_accum;

                        // subtract column sums falling outside of window
                        sad_accum -= sad_delay.front(); sad_delay.pop_front();
                    }
                } // for(x..
            } // for(d..

            if(params.texture) {
                // texture filtering
                // (reuse params.sad_window logic)
                int sad_accum = 0;
                sad_delay.clear();
                // process whole row
                for(int x=0;x<il.cols;++x) {
                    // sum column
                    int sad = 0;
                    for(int ys=0;ys<params.sad_window;++ys)
                        sad += abs((int)(rowsl[ys][x]) - params.data_max/2);
                    
                    // accumulate window
                    sad_accum += sad;
                    sad_delay.push_back(sad);

                    // once window is filled, produce output
                    if(sad_delay.size()==(unsigned int)params.sad_window) {
                        int xd          = x - (params.sad_window/2);

                        if(sad_accum < params.texture) {
                            // below threshold; filtered
                            fptr[xd] = UCHAR_MAX;
                        }

                        // subtract column sums falling outside of window
                        sad_accum -= sad_delay.front(); sad_delay.pop_front();
                    }
                } // for(x..
            }

            // ** post-process **
            for(int x=(params.disparities-1+(params.sad_window/2));x<(il.cols-(params.sad_window/2));++x) {
//            for(int x=(params.sad_window/2);x<(il.cols-(params.sad_window/2));++x) {

                vptr[x] = UCHAR_MAX;
                dptr[x] = (short)(disps[x] << params.sub_bits);
                
                if(params.sub_bits) {
                    // ** sub-pixel approximation **
                    if(disps[x] > 0 && disps[x] < (params.disparities-1)) {
                        int lo = sads_lo[x] - sads[x];
                        int hi = sads_hi[x] - sads[x];
                        if( lo != hi ) {
                            int t = (lo>hi) ? (lo-hi) : (hi-lo);
                            int b = (lo>hi) ?  lo     :  hi;
                            int d = (t<<(params.sub_bits+params.sub_bits_extra-1))/b;
                            if(lo > hi) {
                                dptr[x] += (short)( (d + ((1<<params.sub_bits_extra)-1)) >> params.sub_bits_extra );
                            } else {
                                dptr[x] += (short)( (((1<<params.sub_bits_extra)-1) - d) >> params.sub_bits_extra );
                            }
                        }
                    }
                }

                if(params.unique_mul) {
                    // ** uniqueness filtering **
                    int thresh = (sads[x] * (params.unique_mul+params.unique_div))/params.unique_div;
                    if(sads_thresh[x] <= thresh) {
                        fptr[x] = UCHAR_MAX;
                    }
                }
            }

            // remove rows falling outside of window
            rowsl.pop_front();
            rowsr.pop_front();
        } // if(y..
    } // for(y..

    // clean up
    delete disps;
    delete sads;
    delete sads_thresh;
    delete sads_prev;
    delete sads_lo;
    delete sads_hi;
}

void dlsc_stereobm_invoker(
    cv::Mat &il,
    cv::Mat &ir,
    cv::Mat &ilf,
    cv::Mat &irf,
    cv::Mat &id,
    cv::Mat &valid,
    cv::Mat &filtered,
    const dlsc_stereobm_params &params
) {

    int width   = params.width;
    int height  = params.height;

    if(width <=0) width  = il.cols;
    if(height<=0) height = il.rows;

    if( (params.scale || il.cols < width || il.rows < height) && (il.cols != width || il.rows != height) ) {
        // perform aspect-ratio-preserving scale
        cv::Mat ils = il.clone();
        cv::Mat irs = ir.clone();

        int w,h;
        float src_aspect = 1.0*il.cols/il.rows;
        float aspect = 1.0*width/height;

        if( src_aspect > aspect ) {
            h = height;
            w = (int)(height*src_aspect);
        } else {
            w = width;
            h = (int)(width/src_aspect);
        }

        cv::resize(ils,il,cv::Size(w,h));
        cv::resize(irs,ir,cv::Size(w,h));
    }

    if(il.cols != width || il.rows != height) {
        // take central crop
        int x   = (il.cols/2) - (width/2);
        int dx  = x + width;
        int y   = (il.rows/2) - (height/2);
        int dy  = y + height;
        il      = il(cv::Range(y,dy),cv::Range(x,dx));
        ir      = ir(cv::Range(y,dy),cv::Range(x,dx));
    }
        
    assert(il.cols == width && il.rows == height);

    ilf = il.clone();
    irf = ir.clone();

    if(params.xsobel) {
        dlsc_xsobel(il,ilf,params);
        dlsc_xsobel(ir,irf,params);
    }
    
    dlsc_stereobm(ilf,irf,id,valid,filtered,params);

    filtered &= valid;
}


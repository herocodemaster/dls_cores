
#ifndef DLSC_STEREOBM_MODELS_INCLUDED
#define DLSC_STEREOBM_MODELS_INCLUDED

#include <cv.h>

struct dlsc_stereobm_params {
    int     disparities;
    int     sad_window;
    int     texture;
    int     data_max;
    int     sub_bits;
    int     sub_bits_extra;
    int     unique_mul;
    int     unique_div;
};

void dlsc_xsobel(
    const cv::Mat &in,
    cv::Mat &out,
    const dlsc_stereobm_params &params
);

void dlsc_stereobm(
    cv::Mat &il,
    cv::Mat &ir,
    cv::Mat &id,
    cv::Mat &valid,
    cv::Mat &filtered,
    const dlsc_stereobm_params &params
);

#endif


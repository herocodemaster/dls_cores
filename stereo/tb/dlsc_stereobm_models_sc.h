
#ifndef DLSC_STEREOBM_MODELS_SC_INCLUDED
#define DLSC_STEREOBM_MODELS_SC_INCLUDED

#include <deque>

// Verilog parameters
#define DATA            PARAM_DATA

#ifdef PARAM_IS_FILTERED
#define DATAF           PARAM_DATAF
#define DATA_MAX        PARAM_DATAF_MAX
#else
#define DATAF           DATA
#define DATA_MAX        ((1<<DATA)-1)
#endif

#define IMG_WIDTH       PARAM_IMG_WIDTH
#define IMG_HEIGHT      PARAM_IMG_HEIGHT
#define DISP_BITS       PARAM_DISP_BITS
#define DISPARITIES     PARAM_DISPARITIES
#define SAD             PARAM_SAD_WINDOW
#define TEXTURE         PARAM_TEXTURE
#define SUB_BITS        PARAM_SUB_BITS
#define SUB_BITS_EXTRA  PARAM_SUB_BITS_EXTRA
#define UNIQUE_MUL      PARAM_UNIQUE_MUL
#define UNIQUE_DIV      PARAM_UNIQUE_DIV
#define OUT_LEFT        PARAM_OUT_LEFT
#define OUT_RIGHT       PARAM_OUT_RIGHT
#define MULT_D          PARAM_MULT_D

#ifdef PARAM_IS_BUFFERED
// MULT_R is effectively 1 when using the prefiltered/buffered wrappers
#define MULT_R          1
#else
#define MULT_R          PARAM_MULT_R
#endif

#define DISP_BITS_R (DISP_BITS*MULT_R)
#define DATA_R      (DATA*MULT_R)
#define DATAF_R     (DATAF*MULT_R)

#define DISP_BITS_S (DISP_BITS+SUB_BITS)
#define DISP_BITS_SR (DISP_BITS_S*MULT_R)

#define SAD_MAX ((1<<SAD_BITS)-1)

#define USE_XSOBEL      (DATA != DATAF)

struct in_type {
    unsigned int    left[MULT_R];
    unsigned int    right[MULT_R];
};

struct out_type {
    unsigned int    disp[MULT_R];
    bool            disp_valid[MULT_R];
    bool            disp_valid_any;
    bool            disp_filtered[MULT_R];
    unsigned int    left[MULT_R];
    unsigned int    right[MULT_R];
    bool            frame_first;
    bool            frame_last;
    bool            row_first;
    bool            row_last;
    unsigned int    x;
    unsigned int    y;
};


void dlsc_stereobm_run_test(
    const char *left_image,
    const char *right_image,
    std::deque<in_type> &in_vals,
    std::deque<out_type> &out_vals
);

#endif


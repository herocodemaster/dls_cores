
// Provides a macro for calculating the amount of delay through a dlsc_divu instance.

`ifndef DLSC_DIVU_DELAY_INCLUDED
`define DLSC_DIVU_DELAY_INCLUDED

// Delay through module is:
//  For CYCLES ==  1, delay is QB+1 cycles (fully pipelined)
//  For CYCLES >= QB, delay is QB+2 cycles (fully sequential)
//  For other cases , delay is QB+4 cycles (hybrid)
//

`define dlsc_divu_delay(param_cycles,param_qb) ( ((param_cycles)==1) ? ((param_qb)+1) : ((param_cycles)>=(param_qb)) ? ((param_qb)+2) : ((param_qb)+4) )

`endif


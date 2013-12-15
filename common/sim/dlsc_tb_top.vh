
// This file must be included only once inside the top testbench module.
// Lower level testbench modules that depend on the various dlsc_ macros
// should just include "dlsc_sim.vh" directly.

`include "dlsc_sim.vh"


// *** random ***

`ifndef RANDSEED
    `define RANDSEED 42
`endif

// _dlsc_rand: returns a random number in the specified range
// (just shorthand for $dist_uniform)
initial _dlsc_rand.seed = `RANDSEED;
function signed [63:0] _dlsc_rand;
    input signed [63:0] min;
    input signed [63:0] max;
    integer seed;
begin
    _dlsc_rand = $dist_uniform(seed,min,max);
end
endfunction


// *** assertions ***

integer _dlsc_err_cnt = 0;
integer _dlsc_chk_cnt = 0;
integer _dlsc_warn_cnt = 0;

// _dlsc_assert_report: prints pass/fail based on running count of assertion failures
task _dlsc_assert_report;
begin
    if(_dlsc_err_cnt > 0 || _dlsc_chk_cnt == 0) begin
        $display("%t: *** FAILED *** (%0d errors/%0d assertions, %0d warnings)", $time, _dlsc_err_cnt, _dlsc_chk_cnt, _dlsc_warn_cnt);
    end else begin
        if(_dlsc_warn_cnt > 0) begin
            $display("%t: *** PASSED with WARNINGS *** (%0d assertions evaluated, %0d warnings)", $time, _dlsc_chk_cnt, _dlsc_warn_cnt);
        end else begin
            $display("%t: *** PASSED *** (%0d assertions evaluated, %0d warnings)", $time, _dlsc_chk_cnt, _dlsc_warn_cnt);
        end
    end
end
endtask

// invoke to record a warning
task _dlsc_warn;
begin
    _dlsc_warn_cnt = _dlsc_warn_cnt + 1;
end
endtask

// invoke to record a successfull check
task _dlsc_okay;
begin
    _dlsc_chk_cnt = _dlsc_chk_cnt + 1;
end
endtask

// invoke to record a failing check
task _dlsc_error;
begin
    _dlsc_chk_cnt = _dlsc_chk_cnt + 1;
    _dlsc_err_cnt = _dlsc_err_cnt + 1;
end
endtask

// print reports and end simulation
task _dlsc_finish;
begin
    _dlsc_assert_report;
    $finish;
end
endtask

integer _dlsc_dump_disable = 0;

// initial setup
initial begin
    $timeformat(-6,3," us",15);

    `dlsc_display("using random seed: %0d", `RANDSEED);

`ifdef DUMPFILE
    if($value$plusargs("NODUMP=%d",_dlsc_dump_disable)) begin
        _dlsc_dump_disable = 1;
    end
    if(!_dlsc_dump_disable) begin
        `dlsc_display("dumping enabled");
        $dumpfile(`DUMPFILE);
        $dumpvars;
    end else begin
        `dlsc_display("dumping disabled");
    end
`endif
end


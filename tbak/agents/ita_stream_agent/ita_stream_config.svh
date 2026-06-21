`ifndef ITA_STREAM_CONFIG_SVH
`define ITA_STREAM_CONFIG_SVH

class ita_stream_config extends uvm_object;
    `uvm_object_utils(ita_stream_config)

    virtual ita_mha8_if vif;
    uvm_active_passive_enum is_active = UVM_PASSIVE;
    ita_stream_kind_e kind = ITA_STREAM_HEAD_INPUT;
    int unsigned head_id = 0;
    // TODO Stage 3-5: use kind + head_id to bind one reusable agent to input/weight/bias/output.

    bit enable_random_stall = 1'b0;
    int unsigned min_stall_cycles = 0;
    int unsigned max_stall_cycles = 0;
    // TODO Stage 5: add deterministic ready first, then optional random backpressure.

    function new(string name = "ita_stream_config");
        super.new(name);
    endfunction : new

    function bit is_sink();
        return kind inside {
            ITA_STREAM_HEAD_OUTPUT,
            ITA_STREAM_SUM_OUTPUT,
            ITA_STREAM_FF_OUTPUT
        };
    endfunction : is_sink

    function bit is_source();
        return !is_sink();
    endfunction : is_source

    function int unsigned next_stall_cycles();
        // TODO Stage 5: implement stall generation after the always-ready output path works.
        return 0;
    endfunction : next_stall_cycles

endclass : ita_stream_config

`endif // ITA_STREAM_CONFIG_SVH

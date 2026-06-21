`ifndef ITA_STREAM_CONFIG_SVH
`define ITA_STREAM_CONFIG_SVH

class ita_stream_config extends uvm_object;
    `uvm_object_utils(ita_stream_config)

    virtual ita_mha8_if vif;
    uvm_active_passive_enum is_active = UVM_PASSIVE;
    ita_stream_kind_e kind = ITA_STREAM_HEAD_INPUT;
    int unsigned head_id = 0;

    bit enable_random_stall = 1'b0;
    int unsigned min_stall_cycles = 0;
    int unsigned max_stall_cycles = 0;
    // TODO Stage 5: implement ready/backpressure configuration after the deterministic output-ready path works.

    function new(string name = "ita_stream_config");
        super.new(name);
    endfunction : new

    function bit is_sink();
        // TODO Stage 5: return true for output sink streams after output ready driving is implemented.
        return 1'b0;
    endfunction : is_sink

    function bit is_source();
        // TODO Stage 3-4: return true for input/weight/bias source streams after source driving is implemented.
        return 1'b0;
    endfunction : is_source

    function int unsigned next_stall_cycles();
        // TODO Stage 5: implement stall generation after the always-ready output path works.
        return 0;
    endfunction : next_stall_cycles

endclass : ita_stream_config

`endif // ITA_STREAM_CONFIG_SVH

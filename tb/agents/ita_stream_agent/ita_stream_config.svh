`ifndef ITA_STREAM_CONFIG_SVH
`define ITA_STREAM_CONFIG_SVH

typedef enum int unsigned {
    ITA_NATIVE_VR_FAULT_NONE,
    ITA_NATIVE_VR_FAULT_DROP_VALID,
    ITA_NATIVE_VR_FAULT_MUTATE_PAYLOAD_AND_METADATA
} ita_native_vr_fault_e;

class ita_stream_config extends uvm_object;
    `uvm_object_utils(ita_stream_config)

    virtual ita_mha8_if vif;
    uvm_active_passive_enum is_active = UVM_PASSIVE;
    ita_stream_kind_e kind = ITA_STREAM_HEAD_INPUT;
    int unsigned head_id = 0;

    bit enable_random_stall = 1'b0;
    int unsigned min_stall_cycles = 0;
    int unsigned max_stall_cycles = 0;

    bit enable_source_gap = 1'b0;
    int unsigned source_gap_min = 0;
    int unsigned source_gap_max = 0;

    bit enable_sink_backpressure = 1'b0;
    int unsigned ready_low_min = 0;
    int unsigned ready_low_max = 0;
    int unsigned ready_high_min = 1;
    int unsigned ready_high_max = 1;

    bit native_vr_fault_enable = 1'b0;
    ita_native_vr_fault_e native_vr_fault_mode = ITA_NATIVE_VR_FAULT_NONE;
    bit native_vr_fault_injected = 1'b0;

    function new(string name = "ita_stream_config");
        super.new(name);
    endfunction : new

    function bit is_sink();
        // Stage 5: return true for output sink streams after output ready driving is implemented.
        return kind inside {
            ITA_STREAM_HEAD_OUTPUT,
            ITA_STREAM_SUM_OUTPUT,
            ITA_STREAM_FF_OUTPUT
        };
    endfunction : is_sink

    function bit is_source();
        // Stage 3-4: return true for input/weight/bias source streams after source driving is implemented.
        return kind inside {
            ITA_STREAM_HEAD_INPUT,
            ITA_STREAM_HEAD_WEIGHT,
            ITA_STREAM_HEAD_BIAS,
            ITA_STREAM_FF_INPUT,
            ITA_STREAM_FF_WEIGHT,
            ITA_STREAM_FF_BIAS
        };
    endfunction : is_source

    function int unsigned next_stall_cycles();
        if (!enable_random_stall || max_stall_cycles == 0)
            return 0;
        if (max_stall_cycles <= min_stall_cycles)
            return min_stall_cycles;
        return $urandom_range(max_stall_cycles, min_stall_cycles);
    endfunction : next_stall_cycles

    function int unsigned random_range(int unsigned min_value, int unsigned max_value);
        if (max_value <= min_value)
            return min_value;
        return $urandom_range(max_value, min_value);
    endfunction : random_range

    function int unsigned next_source_gap_cycles();
        if (!enable_source_gap || source_gap_max == 0)
            return 0;
        return random_range(source_gap_min, source_gap_max);
    endfunction : next_source_gap_cycles

    function int unsigned next_ready_low_cycles();
        if (!enable_sink_backpressure || ready_low_max == 0)
            return 0;
        return random_range(ready_low_min, ready_low_max);
    endfunction : next_ready_low_cycles

    function int unsigned next_ready_high_cycles();
        if (!enable_sink_backpressure || ready_high_max == 0)
            return 1;
        return random_range(ready_high_min, ready_high_max);
    endfunction : next_ready_high_cycles

endclass : ita_stream_config

`endif // ITA_STREAM_CONFIG_SVH

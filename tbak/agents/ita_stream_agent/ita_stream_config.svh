`ifndef ITA_STREAM_CONFIG_SVH
`define ITA_STREAM_CONFIG_SVH

class ita_stream_config extends uvm_object;
    `uvm_object_utils(ita_stream_config)

    virtual ita_mha8_if vif;
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    ita_stream_kind_e kind = ITA_STREAM_HEAD_INPUT;
    ita_stream_direction_e direction = ITA_STREAM_SOURCE;
    int unsigned head_id = 0;
    bit enable_random_stall = 1'b0;
    int unsigned min_stall_cycles = 0;
    int unsigned max_stall_cycles = 0;

    function new(string name = "ita_stream_config");
        super.new(name);
    endfunction : new

    function int unsigned next_stall_cycles();
        if (!enable_random_stall || max_stall_cycles == 0) begin
            return 0;
        end
        if (max_stall_cycles <= min_stall_cycles) begin
            return min_stall_cycles;
        end
        return $urandom_range(max_stall_cycles, min_stall_cycles);
    endfunction : next_stall_cycles

endclass : ita_stream_config

`endif // ITA_STREAM_CONFIG_SVH

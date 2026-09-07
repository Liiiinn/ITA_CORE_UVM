// Existing vector-driven tests with online comparison enabled by default.
class ita_mha8_online_qkv_test extends ita_mha8_qkv_directed_test;
    `uvm_component_utils(ita_mha8_online_qkv_test)

    function new(
        string        name   = "ita_mha8_online_qkv_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction : new

    function void set_scenario_defaults(ita_mha8_scenario_cfg scenario_cfg);
        super.set_scenario_defaults(scenario_cfg);
        scenario_cfg.enable_online_ref_model = 1'b1;
    endfunction : set_scenario_defaults
endclass : ita_mha8_online_qkv_test


class ita_mha8_online_attnff_test extends ita_mha8_attn_directed_test;
    `uvm_component_utils(ita_mha8_online_attnff_test)

    function new(
        string        name   = "ita_mha8_online_attnff_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction : new

    function void set_scenario_defaults(ita_mha8_scenario_cfg scenario_cfg);
        super.set_scenario_defaults(scenario_cfg);
        scenario_cfg.enable_online_ref_model = 1'b1;
    endfunction : set_scenario_defaults
endclass : ita_mha8_online_attnff_test

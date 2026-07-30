`ifndef ITA_MHA8_LINEAR_DIRECTED_TEST_SVH
`define ITA_MHA8_LINEAR_DIRECTED_TEST_SVH

class ita_mha8_linear_directed_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_mha8_linear_directed_test)

    function new(string name = "ita_mha8_linear_directed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    virtual function void set_scenario_defaults(ita_mha8_scenario_cfg scenario_cfg);
        scenario_cfg.stream_path = "logger/uvm_linear_head0_stream.csv";
        scenario_cfg.layer = Linear;
        scenario_cfg.directed_step = MatMul;
        scenario_cfg.activation = Identity;
        scenario_cfg.post_vseq_drain_cycles = 200;
    endfunction : set_scenario_defaults

    virtual task configure_vseq(ita_mha8_vsequence vseq);
        ita_mha8_core_item core;

        core = ita_mha8_core_item::type_id::create("core");
        core.load_stream_csv(scenario.stream_path, scenario.layer, scenario.directed_step);
        if (scenario.requant_path != "")
            core.load_requant_csv(scenario.requant_path);
        vseq.core = core;
    endtask : configure_vseq
endclass

`endif // ITA_MHA8_LINEAR_DIRECTED_TEST_SVH

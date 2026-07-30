`ifndef ITA_MHA8_ATTN_DIRECTED_TEST_SVH
`define ITA_MHA8_ATTN_DIRECTED_TEST_SVH

class ita_mha8_attn_directed_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_mha8_attn_directed_test)

    function new(string name = "ita_mha8_attn_directed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    virtual function void set_scenario_defaults(ita_mha8_scenario_cfg scenario_cfg);
        scenario_cfg.stream_path = "logger/uvm_pyita_attn_mha8_stream.csv";
        scenario_cfg.layer = Attention;
        scenario_cfg.directed_step = Idle;
        scenario_cfg.activation = Identity;
        scenario_cfg.post_vseq_drain_cycles = 2000;
    endfunction : set_scenario_defaults

    virtual task configure_vseq(ita_mha8_vsequence vseq);
        ita_mha8_core_item core;

        core = ita_mha8_core_item::type_id::create("core");
        core.load_stream_csv(
            scenario.stream_path,
            scenario.layer,
            scenario.directed_step,
            scenario.activation,
            scenario.tile_s,
            scenario.tile_e,
            scenario.tile_p,
            scenario.tile_f);
        if (scenario.requant_path != "")
            core.load_requant_csv(scenario.requant_path);
        vseq.core = core;
    endtask : configure_vseq
endclass

`endif // ITA_MHA8_ATTN_DIRECTED_TEST_SVH

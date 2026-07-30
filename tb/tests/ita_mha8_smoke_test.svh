`ifndef ITA_MHA8_SMOKE_TEST_SVH
`define ITA_MHA8_SMOKE_TEST_SVH

class ita_mha8_smoke_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_mha8_smoke_test)

    function new(string name = "ita_mha8_smoke_test", uvm_component parent = null);
        super.new(name, parent);       
    endfunction : new

    virtual function void set_scenario_defaults(ita_mha8_scenario_cfg scenario_cfg);
        scenario_cfg.post_vseq_drain_cycles = 5;
    endfunction : set_scenario_defaults
endclass

`endif // ITA_MHA8_SMOKE_TEST_SVH

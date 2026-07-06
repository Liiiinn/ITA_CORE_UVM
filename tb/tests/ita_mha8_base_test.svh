`ifndef ITA_MHA8_BASE_TEST_SVH
`define ITA_MHA8_BASE_TEST_SVH

class ita_mha8_base_test extends uvm_test;
    `uvm_component_utils(ita_mha8_base_test)

    virtual ita_mha8_if vif;
    ita_mha8_env_config cfg;
    ita_mha8_env env;

    function new(string name = "ita_mha8_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual ita_mha8_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("ITA_TEST_VIF", "ita_mha8_if was not set")
        end

        cfg = ita_mha8_env_config::type_id::create("cfg");
        cfg.vif = vif;
        cfg.create_default_agent_configs();
        // Stage 2-5: override cfg from derived tests before env is created.
        // TODO S13_REGRESSION: add future plusargs to enable SVA, online coverage, and structural predictor modes.
        // TODO S13_REGRESSION: define directed coverage targets for S64/S128/S256 and Identity/Relu/Gelu cases.

        uvm_config_db#(ita_mha8_env_config)::set(this, "env", "cfg", cfg);
        env = ita_mha8_env::type_id::create("env", this);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        // TODO Stage 1: keep this base test build-only; do not start ctrl or stream sequences here.
        // TODO S13_REGRESSION: document pass criteria as UVM_ERROR=0, SVA violation=0, SCB errors=0, timeout=0, offline compare PASS, and coverage goal met.
    endtask : run_phase

endclass : ita_mha8_base_test

class ita_base_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_base_test)

    function new(string name = "ita_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

endclass : ita_base_test

`endif // ITA_MHA8_BASE_TEST_SVH

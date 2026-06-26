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

        uvm_config_db#(ita_mha8_env_config)::set(this, "env", "cfg", cfg);
        env = ita_mha8_env::type_id::create("env", this);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        // TODO Stage 1: keep this base test build-only; do not start ctrl or stream sequences here.
    endtask : run_phase

endclass : ita_mha8_base_test

class ita_base_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_base_test)

    function new(string name = "ita_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

endclass : ita_base_test

`endif // ITA_MHA8_BASE_TEST_SVH

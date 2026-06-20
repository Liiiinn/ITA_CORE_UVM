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

        uvm_config_db#(ita_mha8_env_config)::set(this, "env", "cfg", cfg);
        env = ita_mha8_env::type_id::create("env", this);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        // TODO Stage 1: keep this base test as build-only smoke for learning the UVM hierarchy.
        // TODO Stage 2: add a minimal ctrl sequence that drives ctrl_i and start behavior.
        // TODO Stage 3: add one head-0 stream transaction through input/weight/bias agents.
        // TODO Stage 4: move Linear directed stimulus into ita_linear_directed_test.
        // TODO Stage 5: pass actual/expected/compare paths into the logger and Python compare flow.
    endtask : run_phase

endclass : ita_mha8_base_test

class ita_base_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_base_test)

    function new(string name = "ita_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

endclass : ita_base_test

class ita_linear_directed_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_linear_directed_test)

    function new(string name = "ita_linear_directed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    task run_phase(uvm_phase phase);
        // TODO Stage 4: drive a small manually-checkable Linear testcase on head 0.
        // TODO Stage 5: dump actual output and pass paths to the Phase 2 compare scripts.
    endtask : run_phase

endclass : ita_linear_directed_test

`endif // ITA_MHA8_BASE_TEST_SVH

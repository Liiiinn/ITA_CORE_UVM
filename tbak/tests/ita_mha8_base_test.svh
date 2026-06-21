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
        // TODO Stage 6: override cfg paths and head selection from plusargs before env is created.

        uvm_config_db#(ita_mha8_env_config)::set(this, "env", "cfg", cfg);
        env = ita_mha8_env::type_id::create("env", this);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        // TODO Stage 1: keep this base test build-only; do not start sequences here.
        // TODO Stage 2: create a derived ctrl smoke test when ready to drive ctrl_i.
        // TODO Stage 5: add a timeout only after at least one sequence can produce expected activity.
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
        // TODO Stage 6: create one ita_mha8_core_item with layer=Linear and activation=Identity.
        // TODO Stage 6: start a ctrl item on env.ctrl_agt.sqr before driving stream payloads.
        // TODO Stage 6: drive input, weight, and bias payloads on head 0 through the three source agents.
        // TODO Stage 6: keep env.output_stream_agt ready while collecting actual output samples.
        // TODO Stage 7: pass expected_path, actual_path, and compare_path into the logger/compare flow.
    endtask : run_phase

endclass : ita_linear_directed_test

`endif // ITA_MHA8_BASE_TEST_SVH

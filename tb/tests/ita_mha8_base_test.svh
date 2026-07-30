`ifndef ITA_MHA8_BASE_TEST_SVH
`define ITA_MHA8_BASE_TEST_SVH

class ita_mha8_base_test extends uvm_test;
    `uvm_component_utils(ita_mha8_base_test)

    virtual ita_mha8_if vif;
    ita_mha8_scenario_cfg scenario;
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

        scenario = ita_mha8_scenario_cfg::type_id::create("scenario");
        set_scenario_defaults(scenario);
        scenario.load_plusargs();
        scenario.normalize();

        cfg = ita_mha8_env_config::type_id::create("cfg");
        cfg.vif = vif;
        cfg.apply_scenario(scenario);
        cfg.create_default_agent_configs();

        uvm_config_db#(ita_mha8_env_config)::set(this, "env", "cfg", cfg);
        env = ita_mha8_env::type_id::create("env", this);
    endfunction : build_phase

    virtual function void set_scenario_defaults(ita_mha8_scenario_cfg scenario_cfg);
    endfunction : set_scenario_defaults

    virtual function ita_mha8_vsequence create_vseq();
        return ita_mha8_vsequence::type_id::create("vseq");
    endfunction : create_vseq

    virtual task configure_vseq(ita_mha8_vsequence vseq);
    endtask : configure_vseq

    virtual task pre_vseq_start();
    endtask : pre_vseq_start

    task run_phase(uvm_phase phase);
        ita_mha8_vsequence vseq;

        phase.raise_objection(this);
        pre_vseq_start();

        vseq = create_vseq();
        if (vseq == null)
            `uvm_fatal("ITA_TEST_VSEQ", "create_vseq returned null")
        vseq.scenario = scenario;
        configure_vseq(vseq);
        vseq.start(env.vsqr);

        repeat (scenario.post_vseq_drain_cycles) @(posedge vif.clk_i);
        phase.drop_objection(this);
    endtask : run_phase

endclass : ita_mha8_base_test

class ita_base_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_base_test)

    function new(string name = "ita_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

endclass : ita_base_test

`endif // ITA_MHA8_BASE_TEST_SVH

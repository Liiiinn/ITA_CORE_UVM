`ifndef ITA_MHA8_ENV_SVH
`define ITA_MHA8_ENV_SVH

class ita_mha8_env extends uvm_env;
    `uvm_component_utils(ita_mha8_env)

    // TODO Stage 1: create ctrl plus input/weight/bias/output stream agents for the head-0 learning path.
    // TODO Stage 2: connect stream monitor analysis ports into a small transaction fan-in point.
    // TODO Stage 3: add a logger that dumps actual output samples to a deterministic compare path.
    // TODO Stage 4: add a smoke scoreboard for counts, X/Z checks, timeout, and valid-ready protocol.
    // TODO Stage 5: expand from one configured head to all 8 heads with clear mismatch attribution.
    ita_mha8_env_config cfg;

    ita_ctrl_agent ctrl_agt;
    ita_stream_agent input_stream_agt;
    ita_stream_agent weight_stream_agt;
    ita_stream_agent bias_stream_agt;
    ita_stream_agent output_stream_agt;

    function new(string name = "ita_mha8_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ita_mha8_env_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("ITA_ENV_CFG", "ita_mha8_env_config was not set")
        end

        uvm_config_db#(ita_ctrl_config)::set(this, "ctrl_agt", "cfg", cfg.ctrl_cfg);
        ctrl_agt = ita_ctrl_agent::type_id::create("ctrl_agt", this);

        uvm_config_db#(ita_stream_config)::set(this, "input_stream_agt", "cfg", cfg.input_stream_cfg);
        input_stream_agt = ita_stream_agent::type_id::create("input_stream_agt", this);

        uvm_config_db#(ita_stream_config)::set(this, "weight_stream_agt", "cfg", cfg.weight_stream_cfg);
        weight_stream_agt = ita_stream_agent::type_id::create("weight_stream_agt", this);

        uvm_config_db#(ita_stream_config)::set(this, "bias_stream_agt", "cfg", cfg.bias_stream_cfg);
        bias_stream_agt = ita_stream_agent::type_id::create("bias_stream_agt", this);

        uvm_config_db#(ita_stream_config)::set(this, "output_stream_agt", "cfg", cfg.output_stream_cfg);
        output_stream_agt = ita_stream_agent::type_id::create("output_stream_agt", this);
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction : connect_phase

endclass : ita_mha8_env

`endif // ITA_MHA8_ENV_SVH

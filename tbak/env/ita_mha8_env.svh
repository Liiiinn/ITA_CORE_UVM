`ifndef ITA_MHA8_ENV_SVH
`define ITA_MHA8_ENV_SVH

class ita_mha8_env extends uvm_env;
    `uvm_component_utils(ita_mha8_env)

    ita_mha8_env_config cfg;

    ita_ctrl_agent ctrl_agt;
    ita_stream_agent input_stream_agt;
    ita_stream_agent weight_stream_agt;
    ita_stream_agent bias_stream_agt;
    ita_stream_agent output_stream_agt;
    // TODO Stage 5: declare logger and smoke scoreboard handles here when those components are introduced.

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
        // TODO Stage 2: start the first minimal ctrl sequence from the test through ctrl_agt.sqr.

        uvm_config_db#(ita_stream_config)::set(this, "input_stream_agt", "cfg", cfg.input_stream_cfg);
        input_stream_agt = ita_stream_agent::type_id::create("input_stream_agt", this);

        uvm_config_db#(ita_stream_config)::set(this, "weight_stream_agt", "cfg", cfg.weight_stream_cfg);
        weight_stream_agt = ita_stream_agent::type_id::create("weight_stream_agt", this);

        uvm_config_db#(ita_stream_config)::set(this, "bias_stream_agt", "cfg", cfg.bias_stream_cfg);
        bias_stream_agt = ita_stream_agent::type_id::create("bias_stream_agt", this);
        // TODO Stage 3: drive one head-0 input/weight/bias transaction through these three sequencers.

        uvm_config_db#(ita_stream_config)::set(this, "output_stream_agt", "cfg", cfg.output_stream_cfg);
        output_stream_agt = ita_stream_agent::type_id::create("output_stream_agt", this);
        // TODO Stage 4: use output_stream_agt as the first sink monitor/ready driver for per-head output.
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // TODO Stage 5: connect stream agent analysis ports into logger and smoke scoreboard here.
        // TODO Stage 5: connect issued_ap ports only for expected transaction counting, not payload comparison.
    endfunction : connect_phase

endclass : ita_mha8_env

`endif // ITA_MHA8_ENV_SVH

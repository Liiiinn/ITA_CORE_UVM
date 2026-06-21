`ifndef ITA_MHA8_ENV_SVH
`define ITA_MHA8_ENV_SVH

class ita_mha8_env extends uvm_env;
    `uvm_component_utils(ita_mha8_env)

    ita_mha8_env_config cfg;

    ita_ctrl_agent ctrl_agt;
    // TODO Stage 2: complete the shared ctrl path before adding stream stimulus.

    ita_stream_agent input_agt       [8];
    ita_stream_agent weight_agt      [8];
    ita_stream_agent bias_agt        [8];
    ita_stream_agent head_output_agt [8];
    // TODO Stage 3-5: implement head0 input, weight, bias, and output agents first; keep MHA8 array shape.

    ita_stream_agent sum_output_agt;
    ita_stream_agent ff_input_agt;
    ita_stream_agent ff_weight_agt;
    ita_stream_agent ff_bias_agt;
    ita_stream_agent ff_output_agt;
    // TODO Stage 11: connect sum and feed-forward agents after full head path coverage exists.

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

        for (int unsigned h = 0; h < 8; h++) begin
            uvm_config_db#(ita_stream_config)::set(this, $sformatf("input_agt_%0d", h), "cfg", cfg.input_cfg[h]);
            uvm_config_db#(ita_stream_config)::set(this, $sformatf("weight_agt_%0d", h), "cfg", cfg.weight_cfg[h]);
            uvm_config_db#(ita_stream_config)::set(this, $sformatf("bias_agt_%0d", h), "cfg", cfg.bias_cfg[h]);
            uvm_config_db#(ita_stream_config)::set(this, $sformatf("head_output_agt_%0d", h), "cfg", cfg.head_output_cfg[h]);

            input_agt[h] = ita_stream_agent::type_id::create($sformatf("input_agt_%0d", h), this);
            weight_agt[h] = ita_stream_agent::type_id::create($sformatf("weight_agt_%0d", h), this);
            bias_agt[h] = ita_stream_agent::type_id::create($sformatf("bias_agt_%0d", h), this);
            head_output_agt[h] = ita_stream_agent::type_id::create($sformatf("head_output_agt_%0d", h), this);
            // TODO Stage 3-5: fill only head0 behavior first; the loop exists to preserve MHA8 shape.
        end

        uvm_config_db#(ita_stream_config)::set(this, "sum_output_agt", "cfg", cfg.sum_output_cfg);
        uvm_config_db#(ita_stream_config)::set(this, "ff_input_agt", "cfg", cfg.ff_input_cfg);
        uvm_config_db#(ita_stream_config)::set(this, "ff_weight_agt", "cfg", cfg.ff_weight_cfg);
        uvm_config_db#(ita_stream_config)::set(this, "ff_bias_agt", "cfg", cfg.ff_bias_cfg);
        uvm_config_db#(ita_stream_config)::set(this, "ff_output_agt", "cfg", cfg.ff_output_cfg);

        sum_output_agt = ita_stream_agent::type_id::create("sum_output_agt", this);
        ff_input_agt = ita_stream_agent::type_id::create("ff_input_agt", this);
        ff_weight_agt = ita_stream_agent::type_id::create("ff_weight_agt", this);
        ff_bias_agt = ita_stream_agent::type_id::create("ff_bias_agt", this);
        ff_output_agt = ita_stream_agent::type_id::create("ff_output_agt", this);
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // TODO Stage 7: connect head_output_agt[0].ap to a passive actual-output logger.
        // TODO Stage 8: connect monitor analysis ports to a smoke scoreboard for count/X/Z/timeout checks.
        // TODO Stage 10: connect logger output to the Phase 2 compare path.
        // TODO Stage 11: fan in heads 1-7, sum, and feed-forward analysis ports.
    endfunction : connect_phase

endclass : ita_mha8_env

`endif // ITA_MHA8_ENV_SVH

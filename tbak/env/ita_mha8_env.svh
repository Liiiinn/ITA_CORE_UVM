`ifndef ITA_MHA8_ENV_SVH
`define ITA_MHA8_ENV_SVH

class ita_mha8_env extends uvm_env;
    `uvm_component_utils(ita_mha8_env)

    ita_mha8_env_config cfg;
    ita_mha8_vsequencer vsqr;

    ita_ctrl_agent ctrl_agt;
    ita_stream_agent input_agt       [8];
    ita_stream_agent weight_agt      [8];
    ita_stream_agent bias_agt        [8];
    ita_stream_agent head_output_agt [8];

    ita_stream_agent sum_output_agt;
    ita_stream_agent ff_input_agt;
    ita_stream_agent ff_weight_agt;
    ita_stream_agent ff_bias_agt;
    ita_stream_agent ff_output_agt;

    ita_mha8_logger logger;
    ita_mha8_scoreboard scb;
    // Stage 11: create sum and feed-forward agents after full head-path coverage exists.

    function new(string name = "ita_mha8_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ita_mha8_env_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("ITA_ENV_CFG", "ita_mha8_env_config was not set")
        end

        // Stage 2: set ctrl_cfg into uvm_config_db and create ctrl_agt.
        uvm_config_db#(ita_ctrl_config)::set(this, "ctrl_agt", "cfg", cfg.ctrl_cfg);
        ctrl_agt = ita_ctrl_agent::type_id::create("ctrl_agt", this);
        // Stage 3: set input_cfg[0] into uvm_config_db and create input_agt[0].
        // Stage 4: set weight_cfg[0]/bias_cfg[0] and create weight_agt[0]/bias_agt[0].
        // Stage 5: set head_output_cfg[0] and create head_output_agt[0].
        // Stage 11: create heads 1-7, sum_output_agt, and ff_* agents.
        for (int unsigned h = 0; h < 8; h ++) begin
            uvm_config_db#(ita_stream_config)::set(this, $sformatf("input_agt[%0d]", h), "cfg", cfg.input_cfg[h]);
            input_agt[h] = ita_stream_agent::type_id::create($sformatf("input_agt[%0d]", h), this);

            uvm_config_db#(ita_stream_config)::set(this, $sformatf("weight_agt[%0d]", h), "cfg", cfg.weight_cfg[h]);
            weight_agt[h] = ita_stream_agent::type_id::create($sformatf("weight_agt[%0d]", h), this);
            
            uvm_config_db#(ita_stream_config)::set(this, $sformatf("bias_agt[%0d]", h), "cfg", cfg.bias_cfg[h]);
            bias_agt[h] = ita_stream_agent::type_id::create($sformatf("bias_agt[%0d]", h), this);                 
        
            uvm_config_db#(ita_stream_config)::set(this, $sformatf("head_output_agt[%0d]", h), "cfg", cfg.head_output_cfg[h]);
            head_output_agt[h] = ita_stream_agent::type_id::create($sformatf("head_output_agt[%0d]", h), this);
        end

        uvm_config_db#(ita_stream_config)::set(this, "sum_output_agt", "cfg", cfg.sum_output_cfg);
        sum_output_agt = ita_stream_agent::type_id::create("sum_output_agt", this);

        uvm_config_db#(ita_stream_config)::set(this, "ff_input_agt", "cfg", cfg.ff_input_cfg);
        ff_input_agt = ita_stream_agent::type_id::create("ff_input_agt", this);
        uvm_config_db#(ita_stream_config)::set(this, "ff_weight_agt", "cfg", cfg.ff_weight_cfg);
        ff_weight_agt = ita_stream_agent::type_id::create("ff_weight_agt", this);
        uvm_config_db#(ita_stream_config)::set(this, "ff_bias_agt", "cfg", cfg.ff_bias_cfg);
        ff_bias_agt = ita_stream_agent::type_id::create("ff_bias_agt", this);
        uvm_config_db#(ita_stream_config)::set(this, "ff_output_agt", "cfg", cfg.ff_output_cfg);
        ff_output_agt = ita_stream_agent::type_id::create("ff_output_agt", this);

        logger = ita_mha8_logger::type_id::create("logger", this);
        scb = ita_mha8_scoreboard::type_id::create("scb", this);
        vsqr = ita_mha8_vsequencer::type_id::create("vsqr", this);
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        vsqr.vif = cfg.vif;
        vsqr.ctrl_sqr = ctrl_agt.sqr;

        // Stage 7: connect head_output_agt[0].ap to a passive actual-output logger.
        // Stage 8: connect monitor analysis ports to a smoke scoreboard for count/X/Z/timeout checks.
        for (int unsigned h = 0; h < 8; h++) begin
            vsqr.inp_sqr[h] = input_agt[h].sqr;
            vsqr.weight_sqr[h] = weight_agt[h].sqr;
            vsqr.bias_sqr[h] = bias_agt[h].sqr;
            vsqr.head_output_sqr[h] = head_output_agt[h].sqr;

            input_agt[h].ap.connect(logger.stream_imp);
            weight_agt[h].ap.connect(logger.stream_imp);
            bias_agt[h].ap.connect(logger.stream_imp);
            head_output_agt[h].ap.connect(logger.output_imp);

            input_agt[h].ap.connect(scb.source_export);
            weight_agt[h].ap.connect(scb.source_export);
            bias_agt[h].ap.connect(scb.source_export);
            head_output_agt[h].ap.connect(scb.output_export);
        end
        // Stage 10: logger CSV output feeds parse_actual.py through the manifest-driven smoke flow.
        // Stage 11: fan in sum and feed-forward analysis ports.
        vsqr.sum_output_sqr = sum_output_agt.sqr;
        vsqr.ff_inp_sqr = ff_input_agt.sqr;
        vsqr.ff_weight_sqr = ff_weight_agt.sqr;
        vsqr.ff_bias_sqr = ff_bias_agt.sqr;
        vsqr.ff_output_sqr = ff_output_agt.sqr;

        sum_output_agt.ap.connect(logger.output_imp);
        ff_input_agt.ap.connect(logger.stream_imp);
        ff_weight_agt.ap.connect(logger.stream_imp);
        ff_bias_agt.ap.connect(logger.stream_imp);
        ff_output_agt.ap.connect(logger.output_imp);

        sum_output_agt.ap.connect(scb.output_export);
        ff_input_agt.ap.connect(scb.source_export);
        ff_weight_agt.ap.connect(scb.source_export);
        ff_bias_agt.ap.connect(scb.source_export);
        ff_output_agt.ap.connect(scb.output_export);
    endfunction : connect_phase

endclass : ita_mha8_env

`endif // ITA_MHA8_ENV_SVH

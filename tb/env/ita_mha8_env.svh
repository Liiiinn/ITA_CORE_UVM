`ifndef ITA_MHA8_ENV_SVH
`define ITA_MHA8_ENV_SVH

class ita_mha8_env extends uvm_env;
    `uvm_component_utils(ita_mha8_env)

    ita_mha8_env_config cfg;

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

    ita_mha8_ref_model ref_model;
    ita_mha8_scoreboard scb;
    ita_mha8_transaction_logger txn_logger;

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

        if (cfg.has_ref_model) begin
            ref_model = ita_mha8_ref_model::type_id::create("ref_model", this);
        end

        if (cfg.has_scoreboard) begin
            scb = ita_mha8_scoreboard::type_id::create("scb", this);
        end

        if (cfg.has_transaction_logger) begin
            txn_logger = ita_mha8_transaction_logger::type_id::create("txn_logger", this);
        end
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (ref_model != null) begin
            ctrl_agt.ap.connect(ref_model.ctrl_imp);

            for (int unsigned h = 0; h < 8; h++) begin
                input_agt[h].issued_ap.connect(ref_model.stream_imp);
                weight_agt[h].issued_ap.connect(ref_model.stream_imp);
                bias_agt[h].issued_ap.connect(ref_model.stream_imp);
            end

            ff_input_agt.issued_ap.connect(ref_model.stream_imp);
            ff_weight_agt.issued_ap.connect(ref_model.stream_imp);
            ff_bias_agt.issued_ap.connect(ref_model.stream_imp);
        end

        if (scb != null) begin
            for (int unsigned h = 0; h < 8; h++) begin
                head_output_agt[h].ap.connect(scb.actual_fifo.analysis_export);
            end

            sum_output_agt.ap.connect(scb.actual_fifo.analysis_export);
            ff_output_agt.ap.connect(scb.actual_fifo.analysis_export);

            if (ref_model != null) begin
                ref_model.expected_ap.connect(scb.expected_fifo.analysis_export);
            end
        end

        if (txn_logger != null) begin
            for (int unsigned h = 0; h < 8; h++) begin
                input_agt[h].issued_ap.connect(txn_logger.source_imp);
                weight_agt[h].issued_ap.connect(txn_logger.source_imp);
                bias_agt[h].issued_ap.connect(txn_logger.source_imp);
                head_output_agt[h].ap.connect(txn_logger.stream_imp);
            end

            sum_output_agt.ap.connect(txn_logger.stream_imp);
            ff_input_agt.issued_ap.connect(txn_logger.source_imp);
            ff_weight_agt.issued_ap.connect(txn_logger.source_imp);
            ff_bias_agt.issued_ap.connect(txn_logger.source_imp);
            ff_output_agt.ap.connect(txn_logger.stream_imp);
        end
    endfunction : connect_phase

endclass : ita_mha8_env

`endif // ITA_MHA8_ENV_SVH

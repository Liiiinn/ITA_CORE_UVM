`ifndef ITA_MHA8_ENV_CONFIG_SVH
`define ITA_MHA8_ENV_CONFIG_SVH

class ita_mha8_env_config extends uvm_object;
    `uvm_object_utils(ita_mha8_env_config)

    virtual ita_mha8_if vif;

    ita_ctrl_config ctrl_cfg;
    ita_stream_config input_cfg       [8];
    ita_stream_config weight_cfg      [8];
    ita_stream_config bias_cfg        [8];
    ita_stream_config head_output_cfg [8];

    ita_stream_config sum_output_cfg;
    ita_stream_config ff_input_cfg;
    ita_stream_config ff_weight_cfg;
    ita_stream_config ff_bias_cfg;
    ita_stream_config ff_output_cfg;
    // Stage 11: create sum/feed-forward configs after the head0 path works.

    function new(string name = "ita_mha8_env_config");
        super.new(name);
    endfunction : new

    function void create_default_agent_configs();
        // Stage 2: allocate ctrl_cfg and bind cfg.vif to the ctrl agent config.
        ctrl_cfg = ita_ctrl_config::type_id::create("ctrl_cfg");
        ctrl_cfg.vif = vif;
        ctrl_cfg.is_active = UVM_ACTIVE;
        // Stage 3: allocate input_cfg[0] for ITA_STREAM_HEAD_INPUT with head_id 0.
        // Stage 4: allocate weight_cfg[0] and bias_cfg[0] for head_id 0.
        // Stage 5: allocate head_output_cfg[0] for output ready/monitoring.
        for (int unsigned h; h < 8; h++) begin
            input_cfg[h] = create_stream_cfg($sformatf("input_cfg_%0d", h), ITA_STREAM_HEAD_INPUT, h, UVM_ACTIVE);
            weight_cfg[h] = create_stream_cfg($sformatf("weight_cfg_%0d", h), ITA_STREAM_HEAD_WEIGHT, h, UVM_ACTIVE);
            bias_cfg[h] = create_stream_cfg($sformatf("bias_cfg_%0d", h), ITA_STREAM_HEAD_BIAS, h, UVM_ACTIVE);
            head_output_cfg[h] = create_stream_cfg($sformatf("head_output_cfg_%0d", h), ITA_STREAM_HEAD_OUTPUT, h, UVM_ACTIVE);
        end
        // Stage 11: expand config creation to heads 1-7, sum, and feed-forward paths.
        sum_output_cfg = create_stream_cfg("sum_output_cfg", ITA_STREAM_SUM_OUTPUT, 0, UVM_ACTIVE);
        ff_input_cfg = create_stream_cfg("ff_input_cfg", ITA_STREAM_FF_INPUT, 0, UVM_ACTIVE);
        ff_weight_cfg = create_stream_cfg("ff_weight_cfg", ITA_STREAM_FF_WEIGHT, 0, UVM_ACTIVE);
        ff_bias_cfg = create_stream_cfg("ff_bias_cfg", ITA_STREAM_FF_BIAS, 0, UVM_ACTIVE);
        ff_output_cfg = create_stream_cfg("ff_output_cfg", ITA_STREAM_FF_OUTPUT, 0, UVM_ACTIVE);
    endfunction : create_default_agent_configs

    function ita_stream_config create_stream_cfg(
        string name,
        ita_stream_kind_e kind,
        int unsigned head_id,
        uvm_active_passive_enum is_active
    );
        ita_stream_config cfg;

        cfg = ita_stream_config::type_id::create(name);
        cfg.vif = vif;
        cfg.kind = kind;
        cfg.head_id = head_id;
        cfg.is_active = is_active;
        return cfg;
    endfunction : create_stream_cfg

endclass : ita_mha8_env_config

`endif // ITA_MHA8_ENV_CONFIG_SVH

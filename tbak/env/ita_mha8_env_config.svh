`ifndef ITA_MHA8_ENV_CONFIG_SVH
`define ITA_MHA8_ENV_CONFIG_SVH

class ita_mha8_env_config extends uvm_object;
    `uvm_object_utils(ita_mha8_env_config)

    virtual ita_mha8_if vif;

    ita_ctrl_config ctrl_cfg;
    // TODO Stage 2: create ctrl_cfg, set vif/is_active, and add shared ctrl timing knobs.

    ita_stream_config input_cfg       [8];
    ita_stream_config weight_cfg      [8];
    ita_stream_config bias_cfg        [8];
    ita_stream_config head_output_cfg [8];
    // TODO Stage 3-5: create per-head stream configs; enable only head0 while learning.

    ita_stream_config sum_output_cfg;
    ita_stream_config ff_input_cfg;
    ita_stream_config ff_weight_cfg;
    ita_stream_config ff_bias_cfg;
    ita_stream_config ff_output_cfg;
    // TODO Stage 11: create sum/feed-forward configs after the head0 path works.

    function new(string name = "ita_mha8_env_config");
        super.new(name);
    endfunction : new

    function void create_default_agent_configs();
        // TODO Stage 2: allocate ctrl_cfg and bind cfg.vif to the ctrl agent config.
        // TODO Stage 3: allocate input_cfg[0] for ITA_STREAM_HEAD_INPUT with head_id 0.
        // TODO Stage 4: allocate weight_cfg[0] and bias_cfg[0] for head_id 0.
        // TODO Stage 5: allocate head_output_cfg[0] for output ready/monitoring.
        // TODO Stage 11: expand config creation to heads 1-7, sum, and feed-forward paths.
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

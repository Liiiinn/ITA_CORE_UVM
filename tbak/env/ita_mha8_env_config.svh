`ifndef ITA_MHA8_ENV_CONFIG_SVH
`define ITA_MHA8_ENV_CONFIG_SVH

class ita_mha8_env_config extends uvm_object;
    `uvm_object_utils(ita_mha8_env_config)

    virtual ita_mha8_if vif;

    ita_ctrl_config ctrl_cfg;
    ita_stream_config input_stream_cfg;
    ita_stream_config weight_stream_cfg;
    ita_stream_config bias_stream_cfg;
    ita_stream_config output_stream_cfg;

    function new(string name = "ita_mha8_env_config");
        super.new(name);
    endfunction : new

    function void create_default_agent_configs();
        ctrl_cfg = ita_ctrl_config::type_id::create("ctrl_cfg");
        ctrl_cfg.vif = vif;
        ctrl_cfg.is_active = UVM_ACTIVE;

        input_stream_cfg = create_stream_cfg("input_stream_cfg", ITA_STREAM_HEAD_INPUT, ITA_STREAM_SOURCE, 0, UVM_ACTIVE);
        weight_stream_cfg = create_stream_cfg("weight_stream_cfg", ITA_STREAM_HEAD_WEIGHT, ITA_STREAM_SOURCE, 0, UVM_ACTIVE);
        bias_stream_cfg = create_stream_cfg("bias_stream_cfg", ITA_STREAM_HEAD_BIAS, ITA_STREAM_SOURCE, 0, UVM_ACTIVE);
        output_stream_cfg = create_stream_cfg("output_stream_cfg", ITA_STREAM_HEAD_OUTPUT, ITA_STREAM_SINK, 0, UVM_ACTIVE);
    endfunction : create_default_agent_configs

    function ita_stream_config create_stream_cfg(
        string name,
        ita_stream_kind_e kind,
        ita_stream_direction_e direction,
        int unsigned head_id,
        uvm_active_passive_enum is_active
    );
        ita_stream_config stream_cfg;

        stream_cfg = ita_stream_config::type_id::create(name);
        stream_cfg.vif = vif;
        stream_cfg.is_active = is_active;
        stream_cfg.kind = kind;
        stream_cfg.direction = direction;
        stream_cfg.head_id = head_id;
        return stream_cfg;
    endfunction : create_stream_cfg

endclass : ita_mha8_env_config

`endif // ITA_MHA8_ENV_CONFIG_SVH

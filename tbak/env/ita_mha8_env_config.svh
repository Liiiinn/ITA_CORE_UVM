`ifndef ITA_MHA8_ENV_CONFIG_SVH
`define ITA_MHA8_ENV_CONFIG_SVH

class ita_mha8_env_config extends uvm_object;
    `uvm_object_utils(ita_mha8_env_config)

    virtual ita_mha8_if vif;

    ita_ctrl_config ctrl_cfg;
    // TODO Stage 2: add shared MHA8 ctrl defaults for layer, activation, tiles, requant, and start timing.

    ita_stream_config input_cfg       [8];
    ita_stream_config weight_cfg      [8];
    ita_stream_config bias_cfg        [8];
    ita_stream_config head_output_cfg [8];
    // TODO Stage 3-5: keep the per-head config shape, but implement and enable head0 streams first.

    ita_stream_config sum_output_cfg;
    ita_stream_config ff_input_cfg;
    ita_stream_config ff_weight_cfg;
    ita_stream_config ff_bias_cfg;
    ita_stream_config ff_output_cfg;
    // TODO Stage 11: enable sum and feed-forward paths after the head0 MHA path is understood.

    function new(string name = "ita_mha8_env_config");
        super.new(name);
    endfunction : new

    function void create_default_agent_configs();
        ctrl_cfg = ita_ctrl_config::type_id::create("ctrl_cfg");
        ctrl_cfg.vif = vif;
        ctrl_cfg.is_active = UVM_ACTIVE;

        for (int unsigned h = 0; h < 8; h++) begin
            uvm_active_passive_enum head_mode;

            head_mode = (h == 0) ? UVM_ACTIVE : UVM_PASSIVE;
            // TODO Stage 3: use head0 as the first exercise target; keep heads 1-7 passive until Stage 11.

            input_cfg[h] = create_stream_cfg($sformatf("input_cfg_%0d", h), ITA_STREAM_HEAD_INPUT, h, head_mode);
            weight_cfg[h] = create_stream_cfg($sformatf("weight_cfg_%0d", h), ITA_STREAM_HEAD_WEIGHT, h, head_mode);
            bias_cfg[h] = create_stream_cfg($sformatf("bias_cfg_%0d", h), ITA_STREAM_HEAD_BIAS, h, head_mode);
            head_output_cfg[h] = create_stream_cfg($sformatf("head_output_cfg_%0d", h), ITA_STREAM_HEAD_OUTPUT, h, head_mode);
        end

        sum_output_cfg = create_stream_cfg("sum_output_cfg", ITA_STREAM_SUM_OUTPUT, 0, UVM_PASSIVE);
        ff_input_cfg = create_stream_cfg("ff_input_cfg", ITA_STREAM_FF_INPUT, 0, UVM_PASSIVE);
        ff_weight_cfg = create_stream_cfg("ff_weight_cfg", ITA_STREAM_FF_WEIGHT, 0, UVM_PASSIVE);
        ff_bias_cfg = create_stream_cfg("ff_bias_cfg", ITA_STREAM_FF_BIAS, 0, UVM_PASSIVE);
        ff_output_cfg = create_stream_cfg("ff_output_cfg", ITA_STREAM_FF_OUTPUT, 0, UVM_PASSIVE);
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

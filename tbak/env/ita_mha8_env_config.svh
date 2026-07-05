`ifndef ITA_MHA8_ENV_CONFIG_SVH
`define ITA_MHA8_ENV_CONFIG_SVH

class ita_mha8_env_config extends uvm_object;
    `uvm_object_utils(ita_mha8_env_config)

    virtual ita_mha8_if vif;

    int unsigned tile_s = 1;
    int unsigned tile_e = 1;
    int unsigned tile_p = 1;
    int unsigned tile_f = 1;

    bit source_gap_enable = 1'b0;
    int unsigned source_gap_min = 0;
    int unsigned source_gap_max = 0;
    int unsigned input_source_gap_min = 0;
    int unsigned input_source_gap_max = 0;
    int unsigned weight_source_gap_min = 0;
    int unsigned weight_source_gap_max = 0;
    int unsigned bias_source_gap_min = 0;
    int unsigned bias_source_gap_max = 0;

    bit sink_bp_enable = 1'b0;
    int unsigned ready_low_min = 0;
    int unsigned ready_low_max = 0;
    int unsigned ready_high_min = 1;
    int unsigned ready_high_max = 1;

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
        load_tile_plusargs();
        load_protocol_plusargs();

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
        apply_protocol_cfg(cfg);
        return cfg;
    endfunction : create_stream_cfg

    function void apply_protocol_cfg(ita_stream_config cfg);
        if (cfg.is_source()) begin
            cfg.source_gap_min = source_gap_min_for_kind(cfg.kind);
            cfg.source_gap_max = source_gap_max_for_kind(cfg.kind);
            cfg.enable_source_gap = source_gap_enable || (cfg.source_gap_max != 0);

            cfg.enable_random_stall = cfg.enable_source_gap;
            cfg.min_stall_cycles = cfg.source_gap_min;
            cfg.max_stall_cycles = cfg.source_gap_max;
        end

        if (cfg.is_sink()) begin
            cfg.enable_sink_backpressure = sink_bp_enable;
            cfg.ready_low_min = ready_low_min;
            cfg.ready_low_max = ready_low_max;
            cfg.ready_high_min = ready_high_min;
            cfg.ready_high_max = ready_high_max;
        end
    endfunction : apply_protocol_cfg

    function int unsigned source_gap_min_for_kind(ita_stream_kind_e kind);
        case (kind)
            ITA_STREAM_HEAD_INPUT,
            ITA_STREAM_FF_INPUT:
                return input_source_gap_min;
            ITA_STREAM_HEAD_WEIGHT,
            ITA_STREAM_FF_WEIGHT:
                return weight_source_gap_min;
            ITA_STREAM_HEAD_BIAS,
            ITA_STREAM_FF_BIAS:
                return bias_source_gap_min;
            default:
                return source_gap_min;
        endcase
    endfunction : source_gap_min_for_kind

    function int unsigned source_gap_max_for_kind(ita_stream_kind_e kind);
        case (kind)
            ITA_STREAM_HEAD_INPUT,
            ITA_STREAM_FF_INPUT:
                return input_source_gap_max;
            ITA_STREAM_HEAD_WEIGHT,
            ITA_STREAM_FF_WEIGHT:
                return weight_source_gap_max;
            ITA_STREAM_HEAD_BIAS,
            ITA_STREAM_FF_BIAS:
                return bias_source_gap_max;
            default:
                return source_gap_max;
        endcase
    endfunction : source_gap_max_for_kind

    function void load_tile_plusargs();
        void'($value$plusargs("ITA_TILE_S=%d", tile_s));
        void'($value$plusargs("ITA_TILE_E=%d", tile_e));
        void'($value$plusargs("ITA_TILE_P=%d", tile_p));
        void'($value$plusargs("ITA_TILE_F=%d", tile_f));
    endfunction : load_tile_plusargs

    function void load_protocol_plusargs();
        int unsigned tmp;

        tmp = source_gap_enable;
        if ($value$plusargs("ITA_SOURCE_GAP_ENABLE=%d", tmp))
            source_gap_enable = (tmp != 0);
        void'($value$plusargs("ITA_SOURCE_GAP_MIN=%d", source_gap_min));
        void'($value$plusargs("ITA_SOURCE_GAP_MAX=%d", source_gap_max));
        input_source_gap_min = source_gap_min;
        input_source_gap_max = source_gap_max;
        weight_source_gap_min = source_gap_min;
        weight_source_gap_max = source_gap_max;
        bias_source_gap_min = source_gap_min;
        bias_source_gap_max = source_gap_max;
        void'($value$plusargs("ITA_INPUT_SOURCE_GAP_MIN=%d", input_source_gap_min));
        void'($value$plusargs("ITA_INPUT_SOURCE_GAP_MAX=%d", input_source_gap_max));
        void'($value$plusargs("ITA_WEIGHT_SOURCE_GAP_MIN=%d", weight_source_gap_min));
        void'($value$plusargs("ITA_WEIGHT_SOURCE_GAP_MAX=%d", weight_source_gap_max));
        void'($value$plusargs("ITA_BIAS_SOURCE_GAP_MIN=%d", bias_source_gap_min));
        void'($value$plusargs("ITA_BIAS_SOURCE_GAP_MAX=%d", bias_source_gap_max));

        tmp = sink_bp_enable;
        if ($value$plusargs("ITA_SINK_BP_ENABLE=%d", tmp))
            sink_bp_enable = (tmp != 0);
        void'($value$plusargs("ITA_READY_LOW_MIN=%d", ready_low_min));
        void'($value$plusargs("ITA_READY_LOW_MAX=%d", ready_low_max));
        void'($value$plusargs("ITA_READY_HIGH_MIN=%d", ready_high_min));
        void'($value$plusargs("ITA_READY_HIGH_MAX=%d", ready_high_max));

        if (source_gap_max < source_gap_min)
            source_gap_max = source_gap_min;
        if (input_source_gap_max < input_source_gap_min)
            input_source_gap_max = input_source_gap_min;
        if (weight_source_gap_max < weight_source_gap_min)
            weight_source_gap_max = weight_source_gap_min;
        if (bias_source_gap_max < bias_source_gap_min)
            bias_source_gap_max = bias_source_gap_min;
        if (ready_low_max < ready_low_min)
            ready_low_max = ready_low_min;
        if (ready_high_min == 0)
            ready_high_min = 1;
        if (ready_high_max < ready_high_min)
            ready_high_max = ready_high_min;
    endfunction : load_protocol_plusargs

endclass : ita_mha8_env_config

`endif // ITA_MHA8_ENV_CONFIG_SVH

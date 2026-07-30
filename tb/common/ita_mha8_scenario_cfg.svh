`ifndef ITA_MHA8_SCENARIO_CFG_SVH
`define ITA_MHA8_SCENARIO_CFG_SVH

class ita_mha8_scenario_cfg extends uvm_object;
    `uvm_object_utils(ita_mha8_scenario_cfg)

    string stream_path = "";
    string requant_path = "";

    layer_e layer = Attention;
    step_e directed_step = Idle;
    activation_e activation = Identity;
    int unsigned tile_s = 1;
    int unsigned tile_e = 1;
    int unsigned tile_p = 1;
    int unsigned tile_f = 1;

    int unsigned num_jobs = 8;
    int unsigned protocol_tile_min = 1;
    int unsigned protocol_tile_max = 2;
    int unsigned protocol_start_gap_max = 0;
    string protocol_projection = "ATTNFF";
    bit protocol_config_toggle = 1'b0;

    int unsigned group_idle_gap_min = 0;
    int unsigned group_idle_gap_max = 0;
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
    int unsigned output_wait_timeout_cycles = 1000000;
    bit output_bp_timeout_test = 1'b0;

    string coverage_target_mode = "MID_RESET";
    string mid_reset_step_name = "Q";
    int unsigned mid_reset_cycles = 3;

    string native_vr_fault_kind = "";
    string native_vr_fault_mode = "";
    int unsigned native_vr_fault_head = 0;

    int unsigned post_vseq_drain_cycles = 0;

    function new(string name = "ita_mha8_scenario_cfg");
        super.new(name);
    endfunction : new

    function void load_plusargs();
        string value;
        int unsigned tmp;

        void'($value$plusargs("ITA_STREAM_CSV=%s", stream_path));
        void'($value$plusargs("ITA_REQUANT_CSV=%s", requant_path));
        void'($value$plusargs("ITA_TILE_S=%d", tile_s));
        void'($value$plusargs("ITA_TILE_E=%d", tile_e));
        void'($value$plusargs("ITA_TILE_P=%d", tile_p));
        void'($value$plusargs("ITA_TILE_F=%d", tile_f));

        if ($value$plusargs("ITA_ACTIVATION=%s", value)) begin
            case (value)
                "Identity", "identity": activation = Identity;
                "Relu",     "relu":     activation = Relu;
                "Gelu",     "gelu":     activation = Gelu;
                default:
                    `uvm_fatal("ATTN_TEST", $sformatf("Unsupported ITA_ACTIVATION=%s", value))
            endcase
        end

        if ($value$plusargs("ITA_DIRECTED_LAYER=%s", value)) begin
            case (value)
                "Attention",       "attention":       layer = Attention;
                "SingleAttention", "singleattention": layer = SingleAttention;
                default:
                    `uvm_fatal("ATTN_TEST", $sformatf("Unsupported ITA_DIRECTED_LAYER=%s", value))
            endcase
        end

        if ($value$plusargs("ITA_DIRECTED_STEP=%s", value)) begin
            case (value)
                "Q", "q": directed_step = Q;
                "K", "k": directed_step = K;
                "V", "v": directed_step = V;
                default:
                    `uvm_fatal("ITA_STEP", $sformatf("Unsupported ITA_DIRECTED_STEP=%s; expected Q, K, or V", value))
            endcase
        end

        void'($value$plusargs("ITA_NUM_JOBS=%d", num_jobs));
        void'($value$plusargs("ITA_PROTOCOL_TILE_MIN=%d", protocol_tile_min));
        void'($value$plusargs("ITA_PROTOCOL_TILE_MAX=%d", protocol_tile_max));
        void'($value$plusargs("ITA_PROTOCOL_START_GAP_MAX=%d", protocol_start_gap_max));
        void'($value$plusargs("ITA_PROTOCOL_PROJECTION=%s", protocol_projection));
        tmp = protocol_config_toggle;
        if ($value$plusargs("ITA_PROTOCOL_CONFIG_TOGGLE=%d", tmp))
            protocol_config_toggle = (tmp != 0);

        void'($value$plusargs("ITA_GROUP_IDLE_GAP_MIN=%d", group_idle_gap_min));
        void'($value$plusargs("ITA_GROUP_IDLE_GAP_MAX=%d", group_idle_gap_max));
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
        void'($value$plusargs("ITA_OUTPUT_WAIT_TIMEOUT_CYCLES=%d", output_wait_timeout_cycles));
        tmp = output_bp_timeout_test;
        if ($value$plusargs("ITA_OUTPUT_BP_TIMEOUT_TEST=%d", tmp))
            output_bp_timeout_test = (tmp != 0);

        void'($value$plusargs("ITA_COV_TARGET_MODE=%s", coverage_target_mode));
        void'($value$plusargs("ITA_MID_RESET_STEP=%s", mid_reset_step_name));
        void'($value$plusargs("ITA_MID_RESET_CYCLES=%d", mid_reset_cycles));

        void'($value$plusargs("ITA_NATIVE_VR_FAULT_KIND=%s", native_vr_fault_kind));
        void'($value$plusargs("ITA_NATIVE_VR_FAULT_MODE=%s", native_vr_fault_mode));
        void'($value$plusargs("ITA_NATIVE_VR_FAULT_HEAD=%d", native_vr_fault_head));
    endfunction : load_plusargs

    function void normalize();
        if (num_jobs == 0)
            num_jobs = 1;
        if (protocol_tile_min < 1)
            protocol_tile_min = 1;
        if (protocol_tile_max > 4)
            protocol_tile_max = 4;
        if (protocol_tile_max < protocol_tile_min)
            protocol_tile_max = protocol_tile_min;
        if (group_idle_gap_max < group_idle_gap_min)
            group_idle_gap_max = group_idle_gap_min;
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
        if (output_wait_timeout_cycles == 0)
            output_wait_timeout_cycles = 1;
        if (mid_reset_cycles == 0)
            mid_reset_cycles = 1;
    endfunction : normalize

endclass : ita_mha8_scenario_cfg

`endif // ITA_MHA8_SCENARIO_CFG_SVH

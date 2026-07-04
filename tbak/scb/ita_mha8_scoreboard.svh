`ifndef ITA_MHA8_SCOREBOARD_SVH
`define ITA_MHA8_SCOREBOARD_SVH

class ita_mha8_scoreboard extends uvm_component;
    `uvm_component_utils(ita_mha8_scoreboard)

    uvm_analysis_export #(ita_stream_item) source_export;
    uvm_analysis_export #(ita_stream_item) output_export;
    uvm_analysis_export #(ita_ctrl_item) ctrl_export;

    uvm_tlm_analysis_fifo #(ita_stream_item) source_fifo;
    uvm_tlm_analysis_fifo #(ita_stream_item) output_fifo;
    uvm_tlm_analysis_fifo #(ita_ctrl_item) ctrl_fifo;

    int unsigned input_count;
    int unsigned weight_count;
    int unsigned bias_count;

    int unsigned actual_count;

    int unsigned tile_s;
    int unsigned tile_e;
    int unsigned tile_p;
    int unsigned tile_f;

    int unsigned stream_count_by_key[string];
    int unsigned output_count_by_key[string];
    int unsigned source_total_by_step[string];
    int unsigned output_total_by_step[string];
    int unsigned input_count_by_segment[string];
    int unsigned weight_count_by_segment[string];
    int unsigned bias_count_by_segment[string];
    int unsigned source_segment_seen[string];
    int unsigned source_segment_count_by_step_head[string];
    step_e       source_step_by_step_head[string];
    int unsigned source_head_by_step_head[string];

    int unsigned output_segment_seen[string];
    int unsigned output_segment_count_by_kind_step_head[string];
    ita_stream_kind_e output_kind_by_kind_step_head[string];
    step_e       output_step_by_kind_step_head[string];
    int unsigned output_head_by_kind_step_head[string];

    bit          beat_seen[string];
    int unsigned max_beat_id_by_key[string];
    int unsigned last_beat_id_by_key[string];
    bit          has_last_beat_by_key[string];

    int unsigned current_job_id;
    int unsigned ctrl_count;
    bit          has_active_ctrl;
    layer_e      active_layer;
    activation_e active_activation;

    int unsigned rule_error_count;
    int unsigned max_rule_errors;

    // TODO S13_STRUCT_PREDICTOR: avoid full QK/AV global output order checks unless DUT exposes enough softmax-loop debug metadata.

    function new(string name = "ita_mha8_scoreboard", uvm_component parent = null);
        super.new(name, parent);

        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        current_job_id = 0;
        ctrl_count = 0;
        has_active_ctrl = 1'b0;
        active_layer = Attention;
        active_activation = Identity;
        rule_error_count = 0;
        max_rule_errors = 128;

        ctrl_export = new("ctrl_export", this);
        source_export = new("source_export", this);
        output_export = new("output_export", this);

        ctrl_fifo = new("ctrl_fifo", this);
        source_fifo = new("source_fifo", this);
        output_fifo = new("output_fifo", this);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        void'(uvm_config_db#(int unsigned)::get(this, "", "tile_s", tile_s));
        void'(uvm_config_db#(int unsigned)::get(this, "", "tile_e", tile_e));
        void'(uvm_config_db#(int unsigned)::get(this, "", "tile_p", tile_p));
        void'(uvm_config_db#(int unsigned)::get(this, "", "tile_f", tile_f));

        `uvm_info("ITA_SCB_CFG",
            $sformatf("Scoreboard tile config: tile_s=%0d tile_e=%0d tile_p=%0d tile_f=%0d",
                tile_s, tile_e, tile_p, tile_f),
            UVM_LOW)
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ctrl_export.connect(ctrl_fifo.analysis_export);
        source_export.connect(source_fifo.analysis_export);
        output_export.connect(output_fifo.analysis_export);
    endfunction : connect_phase

    task run_phase(uvm_phase phase);
        fork
            process_ctrl_fifo();
            process_source_fifo();
            process_output_fifo();
        join
    endtask : run_phase

    task process_ctrl_fifo();
        ita_ctrl_item tr;

        forever begin
            ctrl_fifo.get(tr);
            ctrl_count++;
            current_job_id++;
            has_active_ctrl = 1'b1;
            active_layer = tr.ctrl.layer;
            active_activation = tr.ctrl.activation;

            `uvm_info("ITA_SCB_CTRL",
                $sformatf("Observed ctrl job=%0d layer=%s activation=%s tile_s/e/p/f=%0d/%0d/%0d/%0d",
                    current_job_id, active_layer.name(), active_activation.name(),
                    tr.ctrl.tile_s, tr.ctrl.tile_e, tr.ctrl.tile_p, tr.ctrl.tile_f),
                UVM_LOW)
        end
    endtask : process_ctrl_fifo

    task process_source_fifo();
        ita_stream_item tr;

        forever begin
            source_fifo.get(tr);

            case(tr.kind)
                ITA_STREAM_HEAD_INPUT: input_count++;
                ITA_STREAM_FF_INPUT: input_count++;
                ITA_STREAM_HEAD_WEIGHT: weight_count++;
                ITA_STREAM_FF_WEIGHT: weight_count++;
                ITA_STREAM_HEAD_BIAS: bias_count++;
                ITA_STREAM_FF_BIAS: bias_count++;
                default:
                    `uvm_error("ITA_SCB_KIND",
                        $sformatf("Unexpected stream kind=%0d", tr.kind))
            endcase

            record_source_transaction(tr);
            sanity_check_source(tr);
        end
    endtask : process_source_fifo

    task process_output_fifo();
        ita_stream_item tr;

        forever begin
            output_fifo.get(tr);
            actual_count++;
            record_output_transaction(tr);
            sanity_check_actual(tr);
        end
    endtask : process_output_fifo

    function string stream_kind_label(ita_stream_kind_e kind);
        case (kind)
            ITA_STREAM_HEAD_INPUT:  return "head_input";
            ITA_STREAM_HEAD_WEIGHT: return "head_weight";
            ITA_STREAM_HEAD_BIAS:   return "head_bias";
            ITA_STREAM_HEAD_OUTPUT: return "head_output";
            ITA_STREAM_SUM_OUTPUT:  return "sum_output";
            ITA_STREAM_FF_INPUT:    return "ff_input";
            ITA_STREAM_FF_WEIGHT:   return "ff_weight";
            ITA_STREAM_FF_BIAS:     return "ff_bias";
            ITA_STREAM_FF_OUTPUT:   return "ff_output";
            default:                return "unknown";
        endcase
    endfunction : stream_kind_label

    function string count_key(ita_stream_item tr);
        return count_key_from_fields(tr.kind, tr.step, tr.head_id, tr.tile_id, tr.inner_tile_id);
    endfunction : count_key

    function string job_key();
        return $sformatf("job%0d", current_job_id);
    endfunction : job_key

    function string count_key_from_fields(
        ita_stream_kind_e kind,
        step_e step,
        int unsigned head_id,
        int unsigned tile_id,
        int unsigned inner_tile_id
    );
        return $sformatf("%s:%s:%s:h%0d:t%0d:i%0d",
            job_key(), stream_kind_label(kind), step.name(), head_id, tile_id, inner_tile_id);
    endfunction : count_key_from_fields

    function string segment_key(ita_stream_item tr);
        return segment_key_from_fields(tr.step, tr.head_id, tr.tile_id, tr.inner_tile_id);
    endfunction : segment_key

    function string segment_key_from_fields(
        step_e step,
        int unsigned head_id,
        int unsigned tile_id,
        int unsigned inner_tile_id
    );
        return $sformatf("%s:%s:h%0d:t%0d:i%0d", job_key(), step.name(), head_id, tile_id, inner_tile_id);
    endfunction : segment_key_from_fields

    function string step_key(step_e step);
        return $sformatf("%s:%s", job_key(), step.name());
    endfunction : step_key

    function string step_head_key(step_e step, int unsigned head_id);
        return $sformatf("%s:%s:h%0d", job_key(), step.name(), head_id);
    endfunction : step_head_key

    function string kind_step_head_key(ita_stream_kind_e kind, step_e step, int unsigned head_id);
        return $sformatf("%s:%s:%s:h%0d", job_key(), stream_kind_label(kind), step.name(), head_id);
    endfunction : kind_step_head_key

    function string beat_key(ita_stream_item tr);
        return $sformatf("%s:b%0d", count_key(tr), tr.beat_id);
    endfunction : beat_key

    function bit step_matches_layer(step_e step, layer_e layer);
        case (layer)
            Attention:
                return (step inside {Q, K, V, QK, AV, OW});
            Feedforward:
                return (step inside {F1, F2});
            Linear:
                return (step == MatMul);
            default:
                return 1'b0;
        endcase
    endfunction : step_matches_layer

    function void check_active_window_rule(ita_stream_item tr);
        if (!has_active_ctrl) begin
            scb_rule_error("ITA_SCB_WINDOW",
                $sformatf("Transaction observed before ctrl start: kind=%s step=%s head=%0d tile=%0d inner=%0d beat=%0d",
                    stream_kind_label(tr.kind), tr.step.name(), tr.head_id, tr.tile_id, tr.inner_tile_id, tr.beat_id));
            return;
        end

        if (!step_matches_layer(tr.step, active_layer)) begin
            scb_rule_error("ITA_SCB_WINDOW",
                $sformatf("Transaction step does not match active layer: job=%0d layer=%s kind=%s step=%s head=%0d tile=%0d inner=%0d beat=%0d",
                    current_job_id, active_layer.name(), stream_kind_label(tr.kind), tr.step.name(),
                    tr.head_id, tr.tile_id, tr.inner_tile_id, tr.beat_id));
        end
    endfunction : check_active_window_rule

    function bit should_check_beat_integrity(ita_stream_item tr);
        if (tr.kind == ITA_STREAM_HEAD_OUTPUT && (tr.step inside {QK, AV}))
            return 1'b0;
        return 1'b1;
    endfunction : should_check_beat_integrity

    function void record_beat_integrity(ita_stream_item tr);
        string cnt_key;
        string b_key;

        if (!should_check_beat_integrity(tr))
            return;

        cnt_key = count_key(tr);
        b_key = beat_key(tr);

        if (beat_seen.exists(b_key)) begin
            scb_rule_error("ITA_SCB_BEAT_DUP",
                $sformatf("Duplicate beat observed for %s", b_key));
            return;
        end
        beat_seen[b_key] = 1'b1;

        if (!max_beat_id_by_key.exists(cnt_key) || tr.beat_id > max_beat_id_by_key[cnt_key])
            max_beat_id_by_key[cnt_key] = tr.beat_id;

        if (has_last_beat_by_key.exists(cnt_key) && has_last_beat_by_key[cnt_key]) begin
            if (tr.beat_id != last_beat_id_by_key[cnt_key] + 1) begin
                scb_rule_error("ITA_SCB_BEAT_ORDER",
                    $sformatf("Beat discontinuity for %s: expected=%0d got=%0d",
                        cnt_key, last_beat_id_by_key[cnt_key] + 1, tr.beat_id));
            end
        end else if (tr.beat_id != 0) begin
            scb_rule_error("ITA_SCB_BEAT_ORDER",
                $sformatf("First beat for %s should be 0, got=%0d", cnt_key, tr.beat_id));
        end

        has_last_beat_by_key[cnt_key] = 1'b1;
        last_beat_id_by_key[cnt_key] = tr.beat_id;
    endfunction : record_beat_integrity

    function int unsigned expected_source_segments_for_step(step_e step);
        case (step)
            Q, K, V:
                return tile_s * tile_p * tile_e;
            QK:
                return tile_s * tile_s * tile_p;
            AV:
                return tile_s * tile_p * tile_s;
            OW:
                return tile_s * tile_e * tile_p;
            F1:
                return tile_s * tile_f * tile_e;
            F2:
                return tile_s * tile_e * tile_f;
            MatMul:
                return tile_s * tile_p * tile_e;
            default:
                return 0;
        endcase
    endfunction : expected_source_segments_for_step

    function int unsigned expected_output_segments_for_kind_step(ita_stream_kind_e kind, step_e step);
        case (kind)
            ITA_STREAM_HEAD_OUTPUT: begin
                case (step)
                    Q, K, V:
                        return tile_s * tile_p;
                    OW:
                        return tile_s * tile_e;
                    MatMul:
                        return tile_s * tile_p;
                    default:
                        return 0;
                endcase
            end
            ITA_STREAM_SUM_OUTPUT: begin
                if (step == OW)
                    return tile_s * tile_e;
                return 0;
            end
            ITA_STREAM_FF_OUTPUT: begin
                case (step)
                    F1:
                        return tile_s * tile_f;
                    F2:
                        return tile_s * tile_e;
                    default:
                        return 0;
                endcase
            end
            default:
                return 0;
        endcase
    endfunction : expected_output_segments_for_kind_step

    function void record_source_transaction(ita_stream_item tr);
        string seg_key;
        string cnt_key;
        string stp_key;
        string sh_key;
        bit is_new_segment;

        cnt_key = count_key(tr);
        stp_key = step_key(tr.step);
        seg_key = segment_key(tr);
        sh_key = step_head_key(tr.step, tr.head_id);
        is_new_segment = !source_segment_seen.exists(seg_key);

        if (!stream_count_by_key.exists(cnt_key))
            stream_count_by_key[cnt_key] = 0;
        stream_count_by_key[cnt_key]++;

        if (!source_total_by_step.exists(stp_key))
            source_total_by_step[stp_key] = 0;
        source_total_by_step[stp_key]++;

        source_segment_seen[seg_key] = 1;
        if (is_new_segment) begin
            if (!source_segment_count_by_step_head.exists(sh_key))
                source_segment_count_by_step_head[sh_key] = 0;
            source_segment_count_by_step_head[sh_key]++;
            source_step_by_step_head[sh_key] = tr.step;
            source_head_by_step_head[sh_key] = tr.head_id;
        end

        record_beat_integrity(tr);

        case (tr.kind)
            ITA_STREAM_HEAD_INPUT,
            ITA_STREAM_FF_INPUT: begin
                if (!input_count_by_segment.exists(seg_key))
                    input_count_by_segment[seg_key] = 0;
                input_count_by_segment[seg_key]++;
            end

            ITA_STREAM_HEAD_WEIGHT,
            ITA_STREAM_FF_WEIGHT: begin
                if (!weight_count_by_segment.exists(seg_key))
                    weight_count_by_segment[seg_key] = 0;
                weight_count_by_segment[seg_key]++;
            end

            ITA_STREAM_HEAD_BIAS,
            ITA_STREAM_FF_BIAS: begin
                if (!bias_count_by_segment.exists(seg_key))
                    bias_count_by_segment[seg_key] = 0;
                bias_count_by_segment[seg_key]++;
            end

            default: begin end
        endcase
    endfunction : record_source_transaction

    function void record_output_transaction(ita_stream_item tr);
        string cnt_key;
        string stp_key;
        string out_seg_key;
        string ksh_key;
        bit is_new_segment;

        cnt_key = count_key(tr);
        stp_key = step_key(tr.step);
        out_seg_key = cnt_key;
        ksh_key = kind_step_head_key(tr.kind, tr.step, tr.head_id);
        is_new_segment = !output_segment_seen.exists(out_seg_key);

        if (!output_count_by_key.exists(cnt_key))
            output_count_by_key[cnt_key] = 0;
        output_count_by_key[cnt_key]++;

        if (!output_total_by_step.exists(stp_key))
            output_total_by_step[stp_key] = 0;
        output_total_by_step[stp_key]++;

        output_segment_seen[out_seg_key] = 1;
        if (is_new_segment) begin
            if (!output_segment_count_by_kind_step_head.exists(ksh_key))
                output_segment_count_by_kind_step_head[ksh_key] = 0;
            output_segment_count_by_kind_step_head[ksh_key]++;
            output_kind_by_kind_step_head[ksh_key] = tr.kind;
            output_step_by_kind_step_head[ksh_key] = tr.step;
            output_head_by_kind_step_head[ksh_key] = tr.head_id;
        end

        record_beat_integrity(tr);
    endfunction : record_output_transaction

    function void scb_rule_error(string tag, string message);
        if (rule_error_count < max_rule_errors) begin
            `uvm_error(tag, message)
        end else if (rule_error_count == max_rule_errors) begin
            `uvm_warning("ITA_SCB_RULE_LIMIT",
                $sformatf("Further scoreboard rule errors suppressed after %0d messages", max_rule_errors))
        end
        rule_error_count++;
    endfunction : scb_rule_error

    function bit is_zero_bias(bias_t value);
        is_zero_bias = (value == '0);
    endfunction : is_zero_bias

    function bit is_nonlast_inner(int unsigned inner_tile_id, int unsigned inner_count);
        if (inner_count == 0) begin
            is_nonlast_inner = 1'b0;
        end else begin
            is_nonlast_inner = (inner_tile_id != (inner_count - 1));
        end
    endfunction : is_nonlast_inner

    function bit source_bias_must_be_zero(ita_stream_item tr);
        source_bias_must_be_zero = 1'b0;

        case (tr.step)
            Q, K, V:
                source_bias_must_be_zero = is_nonlast_inner(tr.inner_tile_id, tile_e);
            QK, AV:
                source_bias_must_be_zero = 1'b1;
            OW:
                source_bias_must_be_zero = is_nonlast_inner(tr.inner_tile_id, tile_p);
            F1:
                source_bias_must_be_zero = is_nonlast_inner(tr.inner_tile_id, tile_e);
            F2:
                source_bias_must_be_zero = is_nonlast_inner(tr.inner_tile_id, tile_f);
            default: begin end
        endcase
    endfunction : source_bias_must_be_zero

    function void check_source_bias_rule(ita_stream_item tr);
        if (tr.kind inside {ITA_STREAM_HEAD_BIAS, ITA_STREAM_FF_BIAS}) begin
            if (source_bias_must_be_zero(tr) && !is_zero_bias(tr.bias)) begin
                scb_rule_error("ITA_SCB_BIAS_ZERO",
                    $sformatf("Bias must be zero for kind=%s step=%s head=%0d tile=%0d inner=%0d beat=%0d value=0x%0h",
                        stream_kind_label(tr.kind), tr.step.name(), tr.head_id, tr.tile_id,
                        tr.inner_tile_id, tr.beat_id, tr.bias));
            end
        end
    endfunction : check_source_bias_rule

    function bit is_output_inner_legal(ita_stream_item tr);
        is_output_inner_legal = 1'b0;

        case (tr.step)
            Q, K, V:
                is_output_inner_legal = (tr.inner_tile_id == ((tile_e == 0) ? 0 : tile_e - 1));
            QK:
                is_output_inner_legal = (tr.tile_id < tile_s * tile_s &&
                    tr.inner_tile_id == ((tile_p == 0) ? 0 : tile_p - 1));
            AV:
                is_output_inner_legal = (tr.tile_id < tile_s * tile_p &&
                    tr.inner_tile_id == ((tile_s == 0) ? 0 : tile_s - 1));
            OW:
                is_output_inner_legal = (tr.tile_id < tile_s * tile_e &&
                    tr.inner_tile_id == ((tile_p == 0) ? 0 : tile_p - 1));
            F1:
                is_output_inner_legal = (tr.tile_id < tile_s * tile_f &&
                    tr.inner_tile_id == ((tile_e == 0) ? 0 : tile_e - 1));
            F2:
                is_output_inner_legal = (tr.tile_id < tile_s * tile_e &&
                    tr.inner_tile_id == ((tile_f == 0) ? 0 : tile_f - 1));
            MatMul:
                is_output_inner_legal = 1'b1;
            default: begin end
        endcase
    endfunction : is_output_inner_legal

    function void check_output_metadata_rule(ita_stream_item tr);
        if (!is_output_inner_legal(tr)) begin
            scb_rule_error("ITA_SCB_OUTPUT_TILE",
                $sformatf("Illegal output metadata kind=%s step=%s head=%0d tile=%0d inner=%0d beat=%0d tile_s/e/p/f=%0d/%0d/%0d/%0d",
                    stream_kind_label(tr.kind), tr.step.name(), tr.head_id, tr.tile_id,
                    tr.inner_tile_id, tr.beat_id, tile_s, tile_e, tile_p, tile_f));
        end
    endfunction : check_output_metadata_rule

    function void sanity_check_source(ita_stream_item tr);
        check_active_window_rule(tr);

        if (!(tr.kind inside {
                ITA_STREAM_HEAD_INPUT,
                ITA_STREAM_HEAD_WEIGHT,
                ITA_STREAM_HEAD_BIAS,
                ITA_STREAM_FF_INPUT,
                ITA_STREAM_FF_WEIGHT,
                ITA_STREAM_FF_BIAS
            }))
            `uvm_error("ITA_SCB_KIND", $sformatf("Unexpected source kind=%0d", tr.kind))

        if (tr.kind inside {ITA_STREAM_HEAD_INPUT, ITA_STREAM_HEAD_WEIGHT, ITA_STREAM_HEAD_BIAS} && tr.head_id >= 8)
            `uvm_error("ITA_SCB_HEAD", $sformatf("Illegal source head_id=%0d", tr.head_id))

        case (tr.kind)
            ITA_STREAM_HEAD_INPUT,
            ITA_STREAM_FF_INPUT:
                if ($isunknown(tr.inp))
                    `uvm_error("ITA_SCB_XZ", "Input payload contains X/Z")

            ITA_STREAM_HEAD_WEIGHT,
            ITA_STREAM_FF_WEIGHT:
                if ($isunknown(tr.weight))
                    `uvm_error("ITA_SCB_XZ", "Weight payload contains X/Z")

            ITA_STREAM_HEAD_BIAS,
            ITA_STREAM_FF_BIAS:
                if ($isunknown(tr.bias))
                    `uvm_error("ITA_SCB_XZ", "Bias payload contains X/Z")
        endcase

        check_source_bias_rule(tr);
    endfunction : sanity_check_source

    function void sanity_check_actual(ita_stream_item actual);
        check_active_window_rule(actual);

        if (!(actual.kind inside {ITA_STREAM_HEAD_OUTPUT, ITA_STREAM_FF_OUTPUT, ITA_STREAM_SUM_OUTPUT}))
            `uvm_error("ITA_SCB_KIND", $sformatf("Unexpected actual stream kind=%0d", actual.kind)) 
        
        if (actual.kind == ITA_STREAM_HEAD_OUTPUT && actual.head_id >= 8)
            `uvm_error("ITA_SCB_HEAD", $sformatf("Illegal head_id=%0d", actual.head_id))
        
        if (!(actual.step inside {Q, K, V, QK, AV, OW, F1, F2, MatMul}))
            `uvm_error("ITA_SCB_STEP", $sformatf("Illegal output step=%0d", actual.step))
        
        if ($isunknown(actual.oup))
            `uvm_error("ITA_SCB_XZ", "Actual output contains X/Z")

        check_output_metadata_rule(actual);
    endfunction : sanity_check_actual

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        report_transaction_summary();
        check_missing_beat_rules();
        check_source_count_rules();
        check_segment_count_rules();
        // Offline manifest compare owns full output order/count correctness.
        // The DUT debug metadata currently exposes local controller tile ids,
        // which is enough for online legality checks but not for reconstructing
        // the full QK/AV softmax-loop segment order.
    endfunction : report_phase

    function void check_missing_beat_rules();
        string cnt_key;
        string b_key;

        foreach (max_beat_id_by_key[cnt_key]) begin
            for (int unsigned beat = 0; beat <= max_beat_id_by_key[cnt_key]; beat++) begin
                b_key = $sformatf("%s:b%0d", cnt_key, beat);
                if (!beat_seen.exists(b_key)) begin
                    scb_rule_error("ITA_SCB_BEAT_MISSING",
                        $sformatf("Missing beat for %s", b_key));
                end
            end
        end
    endfunction : check_missing_beat_rules

    function void check_source_count_rules();
        string key;
        int unsigned input_n;
        int unsigned weight_n;
        int unsigned bias_n;

        foreach (source_segment_seen[key]) begin
            input_n = input_count_by_segment.exists(key) ? input_count_by_segment[key] : 0;
            weight_n = weight_count_by_segment.exists(key) ? weight_count_by_segment[key] : 0;
            bias_n = bias_count_by_segment.exists(key) ? bias_count_by_segment[key] : 0;

            if (!(input_n == weight_n && input_n == bias_n)) begin
                scb_rule_error("ITA_SCB_SRC_COUNT",
                    $sformatf("Source stream count mismatch for %s: input=%0d weight=%0d bias=%0d",
                        key, input_n, weight_n, bias_n));
            end
        end
    endfunction : check_source_count_rules

    function void check_segment_count_rules();
        string key;
        step_e step;
        ita_stream_kind_e kind;
        int unsigned head_id;
        int unsigned expected_n;
        int unsigned actual_n;

        foreach (source_segment_count_by_step_head[key]) begin
            step = source_step_by_step_head[key];
            head_id = source_head_by_step_head[key];
            expected_n = expected_source_segments_for_step(step);
            actual_n = source_segment_count_by_step_head[key];

            if (expected_n != 0 && actual_n != expected_n) begin
                scb_rule_error("ITA_SCB_SEGMENT",
                    $sformatf("Source segment count mismatch for %s head=%0d: expected=%0d actual=%0d tile_s/e/p/f=%0d/%0d/%0d/%0d",
                        step.name(), head_id, expected_n, actual_n, tile_s, tile_e, tile_p, tile_f));
            end
        end

        foreach (output_segment_count_by_kind_step_head[key]) begin
            kind = output_kind_by_kind_step_head[key];
            step = output_step_by_kind_step_head[key];
            head_id = output_head_by_kind_step_head[key];
            expected_n = expected_output_segments_for_kind_step(kind, step);
            actual_n = output_segment_count_by_kind_step_head[key];

            if (expected_n != 0 && actual_n != expected_n) begin
                scb_rule_error("ITA_SCB_SEGMENT",
                    $sformatf("Output segment count mismatch for kind=%s step=%s head=%0d: expected=%0d actual=%0d tile_s/e/p/f=%0d/%0d/%0d/%0d",
                        stream_kind_label(kind), step.name(), head_id, expected_n, actual_n,
                        tile_s, tile_e, tile_p, tile_f));
            end
        end
    endfunction : check_segment_count_rules

    function void report_transaction_summary();
        string key;
        int unsigned printed;

        `uvm_info("ITA_SCB_SUMMARY",
            $sformatf("source input=%0d weight=%0d bias=%0d output=%0d tile_s=%0d tile_e=%0d tile_p=%0d tile_f=%0d",
                input_count, weight_count, bias_count, actual_count,
                tile_s, tile_e, tile_p, tile_f),
            UVM_LOW)

        foreach (source_total_by_step[key]) begin
            `uvm_info("ITA_SCB_STEP",
                $sformatf("source step=%s count=%0d", key, source_total_by_step[key]),
                UVM_LOW)
        end

        foreach (output_total_by_step[key]) begin
            `uvm_info("ITA_SCB_STEP",
                $sformatf("output step=%s count=%0d", key, output_total_by_step[key]),
                UVM_LOW)
        end

        printed = 0;
        foreach (stream_count_by_key[key]) begin
            if (printed < 32) begin
                `uvm_info("ITA_SCB_STREAM_COUNT",
                    $sformatf("%s count=%0d", key, stream_count_by_key[key]),
                    UVM_LOW)
            end
            printed++;
        end
        if (printed > 32) begin
            `uvm_info("ITA_SCB_STREAM_COUNT",
                $sformatf("... %0d additional source count entries omitted", printed - 32),
                UVM_LOW)
        end

        printed = 0;
        foreach (output_count_by_key[key]) begin
            if (printed < 32) begin
                `uvm_info("ITA_SCB_OUTPUT_COUNT",
                    $sformatf("%s count=%0d", key, output_count_by_key[key]),
                    UVM_LOW)
            end
            printed++;
        end
        if (printed > 32) begin
            `uvm_info("ITA_SCB_OUTPUT_COUNT",
                $sformatf("... %0d additional output count entries omitted", printed - 32),
                UVM_LOW)
        end
    endfunction : report_transaction_summary

endclass : ita_mha8_scoreboard

`endif // ITA_MHA8_SCOREBOARD_SVH

`ifndef ITA_MHA8_SCOREBOARD_SVH
`define ITA_MHA8_SCOREBOARD_SVH

class ita_mha8_scoreboard extends uvm_component;
    `uvm_component_utils(ita_mha8_scoreboard)

    uvm_analysis_export #(ita_stream_item) source_export;
    uvm_analysis_export #(ita_stream_item) output_export;

    uvm_tlm_analysis_fifo #(ita_stream_item) source_fifo;
    uvm_tlm_analysis_fifo #(ita_stream_item) output_fifo;

    // uvm_tlm_analysis_fifo #(ita_stream_item) expected_fifo;
    // uvm_tlm_analysis_fifo #(ita_stream_item) actual_fifo;
    // Stage 8: decide whether smoke scoreboard needs expected_fifo or only actual monitor input.

    int unsigned input_count;
    int unsigned weight_count;
    int unsigned bias_count;

    int unsigned actual_count;
    int unsigned expected_count;
    int unsigned compare_count;

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
    int unsigned output_order_seen[string];
    int unsigned output_order_segment_index[string];
    int unsigned output_order_last_tile[string];
    int unsigned output_order_last_inner[string];
    int unsigned output_order_last_beat[string];
    int unsigned rule_error_count;
    int unsigned max_rule_errors;

    function new(string name = "ita_mha8_scoreboard", uvm_component parent = null);
        super.new(name, parent);

        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        rule_error_count = 0;
        max_rule_errors = 128;

        source_export = new("source_export", this);
        output_export = new("output_export", this);

        source_fifo = new("source_fifo", this);
        output_fifo = new("output_fifo", this);
        // expected_fifo = new("expected_fifo", this);
        // actual_fifo = new("actual_fifo", this);
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
        source_export.connect(source_fifo.analysis_export);
        output_export.connect(output_fifo.analysis_export);
    endfunction : connect_phase

    task run_phase(uvm_phase phase);
        // Stage 8: implement smoke checks for count, X/Z, timeout, and valid-ready protocol.
        fork
            process_source_fifo();
            process_output_fifo();
        join
        // ita_stream_item expected;
        // ita_stream_item actual;

        // forever begin
        //     actual_fifo.get(actual);
        //     actual_count++;
        //     sanity_check_actual(actual);

        //     if (expected_fifo.get(expected)) begin
        //         expected_count++;
        //         compare_metadata(expected, actual);
        //     end
        // end
        // Stage 10: numeric expected/actual compare is post-sim manifest flow, not this smoke scoreboard.
        // Future optional: reintroduce expected_fifo for online metadata/golden checks after S11 ref-model work.
    endtask : run_phase

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

    function string count_key_from_fields(
        ita_stream_kind_e kind,
        step_e step,
        int unsigned head_id,
        int unsigned tile_id,
        int unsigned inner_tile_id
    );
        return $sformatf("%s:%s:h%0d:t%0d:i%0d",
            stream_kind_label(kind), step.name(), head_id, tile_id, inner_tile_id);
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
        return $sformatf("%s:h%0d:t%0d:i%0d", step.name(), head_id, tile_id, inner_tile_id);
    endfunction : segment_key_from_fields

    function string step_key(step_e step);
        return step.name();
    endfunction : step_key

    function void record_source_transaction(ita_stream_item tr);
        string seg_key;
        string cnt_key;
        string stp_key;

        cnt_key = count_key(tr);
        stp_key = step_key(tr.step);
        seg_key = segment_key(tr);

        if (!stream_count_by_key.exists(cnt_key))
            stream_count_by_key[cnt_key] = 0;
        stream_count_by_key[cnt_key]++;

        if (!source_total_by_step.exists(stp_key))
            source_total_by_step[stp_key] = 0;
        source_total_by_step[stp_key]++;

        source_segment_seen[seg_key] = 1;

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

        cnt_key = count_key(tr);
        stp_key = step_key(tr.step);

        if (!output_count_by_key.exists(cnt_key))
            output_count_by_key[cnt_key] = 0;
        output_count_by_key[cnt_key]++;

        if (!output_total_by_step.exists(stp_key))
            output_total_by_step[stp_key] = 0;
        output_total_by_step[stp_key]++;

        check_output_order_rule(tr);
    endfunction : record_output_transaction

    function string output_order_key(ita_stream_item tr);
        output_order_key = $sformatf("%s:%s:h%0d",
            stream_kind_label(tr.kind), tr.step.name(), tr.head_id);
    endfunction : output_order_key

    function bit is_scheduled_output_step(step_e step);
        is_scheduled_output_step = 1'b0;

        case (step)
            Q, K, V, QK, AV, OW, F1, F2:
                is_scheduled_output_step = 1'b1;
            default: begin end
        endcase
    endfunction : is_scheduled_output_step

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
                is_output_inner_legal = (tr.tile_id < tile_s * tile_s && tr.inner_tile_id < tile_p);
            AV:
                is_output_inner_legal = (tr.tile_id < tile_s * tile_p && tr.inner_tile_id < tile_s);
            OW:
                is_output_inner_legal = (tr.tile_id < tile_s * tile_e && tr.inner_tile_id < tile_p);
            F1:
                is_output_inner_legal = (tr.tile_id < tile_s * tile_f && tr.inner_tile_id < tile_e);
            F2:
                is_output_inner_legal = (tr.tile_id < tile_s * tile_e && tr.inner_tile_id < tile_f);
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

    function void check_output_order_rule(ita_stream_item tr);
        string key;
        int unsigned expected_tile_id;
        int unsigned expected_inner_tile_id;
        int unsigned next_segment_index;
        int unsigned expected_segments;

        if (!(tr.kind inside {ITA_STREAM_HEAD_OUTPUT, ITA_STREAM_SUM_OUTPUT, ITA_STREAM_FF_OUTPUT}))
            return;

        if (!is_scheduled_output_step(tr.step))
            return;

        key = output_order_key(tr);
        expected_segments = expected_output_segment_count(tr.step);

        if (expected_segments == 0)
            return;

        if (!output_order_seen.exists(key)) begin
            expected_output_segment(tr.step, 0, expected_tile_id, expected_inner_tile_id);

            if (tr.tile_id != expected_tile_id || tr.inner_tile_id != expected_inner_tile_id || tr.beat_id != 0) begin
                scb_rule_error("ITA_SCB_OUTPUT_ORDER",
                    $sformatf("First output order mismatch for %s: expected tile=%0d inner=%0d beat=0 got tile=%0d inner=%0d beat=%0d",
                        key, expected_tile_id, expected_inner_tile_id, tr.tile_id, tr.inner_tile_id, tr.beat_id));
            end

            output_order_seen[key] = 1;
            output_order_segment_index[key] = 0;
            output_order_last_tile[key] = tr.tile_id;
            output_order_last_inner[key] = tr.inner_tile_id;
            output_order_last_beat[key] = tr.beat_id;
            return;
        end

        if (tr.tile_id == output_order_last_tile[key] &&
            tr.inner_tile_id == output_order_last_inner[key]) begin
            if (tr.beat_id != output_order_last_beat[key] + 1) begin
                scb_rule_error("ITA_SCB_OUTPUT_ORDER",
                    $sformatf("Output beat order mismatch for %s tile=%0d inner=%0d: expected beat=%0d got beat=%0d",
                        key, tr.tile_id, tr.inner_tile_id, output_order_last_beat[key] + 1, tr.beat_id));
            end
        end else begin
            next_segment_index = output_order_segment_index[key] + 1;

            if (next_segment_index >= expected_segments) begin
                scb_rule_error("ITA_SCB_OUTPUT_ORDER",
                    $sformatf("Unexpected extra output segment for %s: got tile=%0d inner=%0d beat=%0d after segment_index=%0d expected_segments=%0d",
                        key, tr.tile_id, tr.inner_tile_id, tr.beat_id,
                        output_order_segment_index[key], expected_segments));
            end else begin
                expected_output_segment(tr.step, next_segment_index, expected_tile_id, expected_inner_tile_id);

                if (tr.tile_id != expected_tile_id || tr.inner_tile_id != expected_inner_tile_id || tr.beat_id != 0) begin
                    scb_rule_error("ITA_SCB_OUTPUT_ORDER",
                        $sformatf("Output segment order mismatch for %s segment_index=%0d: expected tile=%0d inner=%0d beat=0 got tile=%0d inner=%0d beat=%0d",
                            key, next_segment_index, expected_tile_id, expected_inner_tile_id,
                            tr.tile_id, tr.inner_tile_id, tr.beat_id));
                end

                output_order_segment_index[key] = next_segment_index;
            end
        end

        output_order_last_tile[key] = tr.tile_id;
        output_order_last_inner[key] = tr.inner_tile_id;
        output_order_last_beat[key] = tr.beat_id;
    endfunction : check_output_order_rule

    function void sanity_check_source(ita_stream_item tr);
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
        check_source_count_rules();
        check_output_count_rules();
    endfunction : report_phase

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

    function int unsigned expected_output_segment_count(step_e step);
        expected_output_segment_count = 0;

        case (step)
            Q, K, V:
                expected_output_segment_count = tile_s * tile_p;
            QK:
                expected_output_segment_count = tile_s * tile_s * tile_p;
            AV:
                expected_output_segment_count = tile_s * tile_p * tile_s;
            OW:
                expected_output_segment_count = tile_s * tile_e * tile_p;
            F1:
                expected_output_segment_count = tile_s * tile_f * tile_e;
            F2:
                expected_output_segment_count = tile_s * tile_e * tile_f;
            default: begin end
        endcase
    endfunction : expected_output_segment_count

    function void expected_output_segment(
        step_e step,
        int unsigned segment_index,
        output int unsigned tile_id,
        output int unsigned inner_tile_id
    );
        int unsigned softmax_tile;
        int unsigned rem;

        tile_id = 0;
        inner_tile_id = 0;

        case (step)
            Q, K, V: begin
                tile_id = segment_index;
                inner_tile_id = (tile_e == 0) ? 0 : tile_e - 1;
            end
            QK: begin
                if (tile_s == 0 || tile_p == 0)
                    return;
                softmax_tile = segment_index / (tile_s * tile_p);
                rem = segment_index % (tile_s * tile_p);
                tile_id = softmax_tile * tile_s + (rem / tile_p);
                inner_tile_id = rem % tile_p;
            end
            AV: begin
                if (tile_p == 0 || tile_s == 0)
                    return;
                softmax_tile = segment_index / (tile_p * tile_s);
                rem = segment_index % (tile_p * tile_s);
                tile_id = softmax_tile * tile_p + (rem / tile_s);
                inner_tile_id = rem % tile_s;
            end
            OW: begin
                if (tile_p == 0)
                    return;
                tile_id = segment_index / tile_p;
                inner_tile_id = segment_index % tile_p;
            end
            F1: begin
                if (tile_e == 0)
                    return;
                tile_id = segment_index / tile_e;
                inner_tile_id = segment_index % tile_e;
            end
            F2: begin
                if (tile_f == 0)
                    return;
                tile_id = segment_index / tile_f;
                inner_tile_id = segment_index % tile_f;
            end
            default: begin end
        endcase
    endfunction : expected_output_segment

    function void check_one_output_step(
        ita_stream_kind_e kind,
        step_e step,
        int unsigned head_id
    );
        int unsigned expected_segments;
        int unsigned first_count;
        int unsigned tile_id;
        int unsigned inner_tile_id;
        int unsigned count;
        string key;

        expected_segments = expected_output_segment_count(step);
        first_count = 0;

        for (int unsigned i = 0; i < expected_segments; i++) begin
            expected_output_segment(step, i, tile_id, inner_tile_id);
            key = count_key_from_fields(kind, step, head_id, tile_id, inner_tile_id);

            if (!output_count_by_key.exists(key)) begin
                scb_rule_error("ITA_SCB_OUTPUT_COUNT",
                    $sformatf("Missing output segment %s", key));
            end else begin
                count = output_count_by_key[key];
                if (first_count == 0) begin
                    first_count = count;
                end else if (count != first_count) begin
                    scb_rule_error("ITA_SCB_OUTPUT_COUNT",
                        $sformatf("Non-uniform output beat count for %s: expected_uniform=%0d got=%0d",
                            key, first_count, count));
                end
            end
        end
    endfunction : check_one_output_step

    function void check_head_output_step_if_active(step_e step);
        if (!source_total_by_step.exists(step_key(step)) && !output_total_by_step.exists(step_key(step)))
            return;

        for (int unsigned h = 0; h < 8; h++) begin
            check_one_output_step(ITA_STREAM_HEAD_OUTPUT, step, h);
        end
    endfunction : check_head_output_step_if_active

    function void check_ff_output_step_if_active(step_e step);
        if (!source_total_by_step.exists(step_key(step)) && !output_total_by_step.exists(step_key(step)))
            return;

        check_one_output_step(ITA_STREAM_FF_OUTPUT, step, 0);
    endfunction : check_ff_output_step_if_active

    function void check_sum_output_if_active();
        if (!source_total_by_step.exists("OW") && !output_total_by_step.exists("OW"))
            return;

        check_one_output_step(ITA_STREAM_SUM_OUTPUT, OW, 0);
    endfunction : check_sum_output_if_active

    function void check_output_count_rules();
        check_head_output_step_if_active(Q);
        check_head_output_step_if_active(K);
        check_head_output_step_if_active(V);
        check_head_output_step_if_active(QK);
        check_head_output_step_if_active(AV);
        check_head_output_step_if_active(OW);
        check_sum_output_if_active();
        check_ff_output_step_if_active(F1);
        check_ff_output_step_if_active(F2);
    endfunction : check_output_count_rules

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

    // function void compare_metadata(ita_stream_item expected, ita_stream_item actual);
    //     compare_count++;

    //     if (expected.head_id != actual.head_id)
    //         `uvm_error("ITA_SCB_HEAD", $sformatf("Head mismatch: expected = %0d, actual = %0d", expected.head_id, actual.head_id))
        
    //     if (expected.step != actual.step)
    //         `uvm_error("ITA_SCB_STEP", $sformatf("Step mismatch: expected = %0d, actual = %0d", expected.head_id, actual.head_id))
        
    //     if (expected.beat_id != actual.beat_id)
    //         `uvm_info("ITA_SCB_BEAT", $sformatf("Beat mismatch: expected = %0d, actual = %0d", expected.head_id, actual.head_id))
    // endfunction : compare_metadata

endclass : ita_mha8_scoreboard

`endif // ITA_MHA8_SCOREBOARD_SVH

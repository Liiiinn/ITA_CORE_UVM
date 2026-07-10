`ifndef ITA_MHA8_VSEQUENCE_SVH
`define ITA_MHA8_VSEQUENCE_SVH

class ita_mha8_vsequence extends uvm_sequence;
    `uvm_object_utils(ita_mha8_vsequence)
    `uvm_declare_p_sequencer(ita_mha8_vsequencer)

    ita_mha8_core_item core;
    int unsigned lockstep_idle_gap_min = 0;
    int unsigned lockstep_idle_gap_max = 0;
    int unsigned source_gap_max = 0;
    int unsigned input_source_gap_max = 0;
    int unsigned weight_source_gap_max = 0;
    int unsigned bias_source_gap_max = 0;
    bit source_skew_lockstep = 1'b1;
    bit sink_bp_enable = 1'b0;
    int unsigned ready_low_min = 0;
    int unsigned ready_low_max = 0;
    int unsigned ready_high_min = 1;
    int unsigned ready_high_max = 1;
    bit stop_head_output_ready = 1'b0;

    function new(string name = "ita_mha8_vsequence");
        super.new(name);
    endfunction : new

    virtual task body();
        if (core == null)
            core = ita_mha8_core_item::type_id::create("core");

        void'($value$plusargs("ITA_LOCKSTEP_IDLE_GAP_MIN=%d", lockstep_idle_gap_min));
        void'($value$plusargs("ITA_LOCKSTEP_IDLE_GAP_MAX=%d", lockstep_idle_gap_max));
        void'($value$plusargs("ITA_SOURCE_GAP_MAX=%d", source_gap_max));
        void'($value$plusargs("ITA_INPUT_SOURCE_GAP_MAX=%d", input_source_gap_max));
        void'($value$plusargs("ITA_WEIGHT_SOURCE_GAP_MAX=%d", weight_source_gap_max));
        void'($value$plusargs("ITA_BIAS_SOURCE_GAP_MAX=%d", bias_source_gap_max));
        void'($value$plusargs("ITA_SOURCE_SKEW_LOCKSTEP=%d", source_skew_lockstep));
        load_sink_backpressure_plusargs();
        if (lockstep_idle_gap_max < lockstep_idle_gap_min)
            lockstep_idle_gap_max = lockstep_idle_gap_min;

        fork
            drive_head_output_ready_bundle();
            begin
                fork
                    send_attention_phase();
                    wait_attention_sum_complete();
                join

                if (has_ff_steps()) begin
                    fork
                        send_feedforward_phase();
                        wait_feedforward_complete();
                    join
                end

                stop_head_output_ready = 1'b1;
            end
        join_any
        disable fork;
    endtask : body

    function void load_sink_backpressure_plusargs();
        int unsigned tmp;

        tmp = sink_bp_enable;
        if ($value$plusargs("ITA_SINK_BP_ENABLE=%d", tmp))
            sink_bp_enable = (tmp != 0);
        void'($value$plusargs("ITA_READY_LOW_MIN=%d", ready_low_min));
        void'($value$plusargs("ITA_READY_LOW_MAX=%d", ready_low_max));
        void'($value$plusargs("ITA_READY_HIGH_MIN=%d", ready_high_min));
        void'($value$plusargs("ITA_READY_HIGH_MAX=%d", ready_high_max));

        if (ready_low_max < ready_low_min)
            ready_low_max = ready_low_min;
        if (ready_high_min == 0)
            ready_high_min = 1;
        if (ready_high_max < ready_high_min)
            ready_high_max = ready_high_min;
    endfunction : load_sink_backpressure_plusargs

    function int unsigned ready_random_range(int unsigned min_value, int unsigned max_value);
        if (max_value <= min_value)
            return min_value;
        return $urandom_range(max_value, min_value);
    endfunction : ready_random_range

    task drive_head_output_ready_bundle();
        int unsigned high_cycles;
        int unsigned low_cycles;

        p_sequencer.vif.per_head_ready_i <= '0;
        wait (p_sequencer.vif.rst_ni === 1'b1);

        while (!stop_head_output_ready) begin
            high_cycles = sink_bp_enable ? ready_random_range(ready_high_min, ready_high_max) : 1;
            repeat (high_cycles) begin
                @(posedge p_sequencer.vif.clk_i);
                if (stop_head_output_ready)
                    break;
                p_sequencer.vif.per_head_ready_i <= '1;
            end

            low_cycles = (sink_bp_enable && ready_low_max != 0) ? ready_random_range(ready_low_min, ready_low_max) : 0;
            repeat (low_cycles) begin
                @(posedge p_sequencer.vif.clk_i);
                if (stop_head_output_ready)
                    break;
                p_sequencer.vif.per_head_ready_i <= '0;
            end
        end

        p_sequencer.vif.per_head_ready_i <= '0;
    endtask : drive_head_output_ready_bundle

    task send_attention_phase();
        ita_ctrl_single_seq ctrl_seq;

        ctrl_seq = ita_ctrl_single_seq::type_id::create("ctrl_seq");
        ctrl_seq.ctrl = make_ctrl_item(core, Attention, first_attention_step(), Identity, 1'b1);
        ctrl_seq.start(p_sequencer.ctrl_sqr);

        foreach (core.payload_schedule[i]) begin
            ita_mha8_step_payload payload;

            payload = core.payload_schedule[i];

            if (!is_attention_step(payload.step))
                continue;

            if (payload.drive_head_streams)
                send_step_payload(payload);
        end
    endtask

    task send_feedforward_phase();
        bit sent_f1_ctrl;
        bit sent_f2_ctrl_update;
        bit waited_f1_outputs;

        sent_f1_ctrl = 1'b0;
        sent_f2_ctrl_update = 1'b0;
        waited_f1_outputs = 1'b0;

        foreach (core.payload_schedule[i]) begin
            ita_mha8_step_payload payload;

            payload = core.payload_schedule[i];

            if (!is_ff_step(payload.step))
                continue;

            if (payload.step == F1 && !sent_f1_ctrl) begin
                send_ctrl_item("ff_f1_ctrl_seq", make_ctrl_item(core, Feedforward, F1, core.activation, 1'b1));
                sent_f1_ctrl = 1'b1;
            end

            if (payload.step == F2 && !sent_f2_ctrl_update) begin
                if (!sent_f1_ctrl)
                    send_ctrl_item("ff_f1_ctrl_seq", make_ctrl_item(core, Feedforward, F1, core.activation, 1'b1));
                else if (!waited_f1_outputs) begin
                    wait_ff_step_output_complete(F1);
                    waited_f1_outputs = 1'b1;
                end
                send_ctrl_item("ff_f2_ctrl_update_seq", make_ctrl_item(core, Feedforward, F2, Identity, 1'b0));
                sent_f1_ctrl = 1'b1;
                sent_f2_ctrl_update = 1'b1;
            end

            if (payload.drive_ff_streams) begin
                if (source_skew_enabled())
                    send_ff_payload(payload);
                else
                    send_ff_payload_reference_model(payload);
            end
        end
    endtask

    task wait_ff_step_output_complete(step_e step);
        int unsigned target_tile;
        int unsigned target_inner;
        int unsigned target_beat;
        int unsigned idle_cycles;

        if (p_sequencer.vif == null)
            `uvm_fatal("VSEQ", "Virtual sequencer vif is not set; cannot wait for FF step output completion")

        case (step)
            F1: begin
                if (core.tile_s == 0 || core.tile_f == 0 || core.tile_e == 0)
                    return;
                target_tile = core.tile_s * core.tile_f - 1;
                target_inner = core.tile_e - 1;
            end
            F2: begin
                if (core.tile_s == 0 || core.tile_e == 0 || core.tile_f == 0)
                    return;
                target_tile = core.tile_s * core.tile_e - 1;
                target_inner = core.tile_f - 1;
            end
            default:
                return;
        endcase

        target_beat = M * M / N - 1;
        idle_cycles = 0;

        forever begin
            @(posedge p_sequencer.vif.clk_i);

            if (!p_sequencer.vif.rst_ni) begin
                idle_cycles = 0;
                continue;
            end

            if (p_sequencer.vif.ff_valid_o && p_sequencer.vif.ff_ready_i) begin
                idle_cycles = 0;
                if (p_sequencer.vif.ff_step_o == step &&
                    p_sequencer.vif.ff_tile_id_dbg == target_tile &&
                    p_sequencer.vif.ff_inner_id_dbg == target_inner &&
                    p_sequencer.vif.ff_beat_id_dbg == target_beat) begin
                    return;
                end
            end else begin
                idle_cycles++;
                if (idle_cycles > 1000000) begin
                    `uvm_fatal("VSEQ",
                        $sformatf("Timeout waiting for %s FF output completion: target tile=%0d inner=%0d beat=%0d",
                            step.name(), target_tile, target_inner, target_beat))
                end
            end
        end
    endtask : wait_ff_step_output_complete

    task send_ctrl_item(string seq_name, ita_ctrl_item ctrl);
        ita_ctrl_single_seq ctrl_seq;

        ctrl_seq = ita_ctrl_single_seq::type_id::create(seq_name);
        ctrl_seq.ctrl = ctrl;
        ctrl_seq.start(p_sequencer.ctrl_sqr);
    endtask : send_ctrl_item

    function bit is_attention_step(step_e step);
        return step inside {Q, K, V, QK, AV, OW};
    endfunction : is_attention_step

    function bit is_ff_step(step_e step);
        return step inside {F1, F2};
    endfunction : is_ff_step

    function bit has_ff_steps();
        foreach (core.step_order[i]) begin
            if (is_ff_step(core.step_order[i]))
                return 1'b1;
        end
        return 1'b0;
    endfunction : has_ff_steps

    function step_e first_attention_step();
        foreach (core.step_order[i]) begin
            if (is_attention_step(core.step_order[i]))
                return core.step_order[i];
        end
        `uvm_fatal("VSEQ", "No attention step is available for the Attention ctrl phase")
        return Idle;
    endfunction : first_attention_step

    function step_e first_ff_step();
        foreach (core.step_order[i]) begin
            if (is_ff_step(core.step_order[i]))
                return core.step_order[i];
        end
        `uvm_fatal("VSEQ", "No feed-forward step is available for the Feedforward ctrl phase")
        return Idle;
    endfunction : first_ff_step

    function int unsigned expected_sum_output_beats();
        int unsigned beats;
        int unsigned output_beats_per_segment;

        beats = 0;
        output_beats_per_segment = M * M / N;
        foreach (core.payload_schedule[i]) begin
            ita_mha8_step_payload payload;

            payload = core.payload_schedule[i];
            if (payload.expect_sum_output && core.tile_p != 0 &&
                payload.inner_tile_id == core.tile_p - 1) begin
                beats += output_beats_per_segment;
            end
        end

        return beats;
    endfunction : expected_sum_output_beats

    task wait_attention_sum_complete();
        int unsigned expected_beats;
        int unsigned seen_beats;
        int unsigned idle_cycles;

        expected_beats = expected_sum_output_beats();
        if (expected_beats == 0)
            return;

        if (p_sequencer.vif == null)
            `uvm_fatal("VSEQ", "Virtual sequencer vif is not set; cannot wait for sum output completion")

        seen_beats = 0;
        idle_cycles = 0;

        while (seen_beats < expected_beats) begin
            @(posedge p_sequencer.vif.clk_i);

            if (!p_sequencer.vif.rst_ni) begin
                idle_cycles = 0;
                continue;
            end

            if (p_sequencer.vif.sum_valid_o && p_sequencer.vif.sum_ready_i) begin
                seen_beats++;
                idle_cycles = 0;
            end else begin
                idle_cycles++;
                if (idle_cycles > 1000000) begin
                    `uvm_fatal("VSEQ",
                        $sformatf("Timeout waiting for OW sum output completion: seen=%0d expected=%0d",
                            seen_beats, expected_beats))
                end
            end
        end
    endtask : wait_attention_sum_complete

    function bit ff_output_segment(ita_mha8_step_payload payload);
        if (!payload.expect_ff_output)
            return 1'b0;

        case (payload.step)
            F1: return core.tile_e != 0 && payload.inner_tile_id == core.tile_e - 1;
            F2: return core.tile_f != 0 && payload.inner_tile_id == core.tile_f - 1;
            default: return 1'b0;
        endcase
    endfunction : ff_output_segment

    function int unsigned expected_ff_output_beats();
        int unsigned beats;
        int unsigned output_beats_per_segment;

        beats = 0;
        output_beats_per_segment = M * M / N;
        foreach (core.payload_schedule[i]) begin
            ita_mha8_step_payload payload;

            payload = core.payload_schedule[i];
            if (ff_output_segment(payload))
                beats += output_beats_per_segment;
        end

        return beats;
    endfunction : expected_ff_output_beats

    task wait_feedforward_complete();
        int unsigned expected_beats;
        int unsigned seen_beats;
        int unsigned idle_cycles;

        expected_beats = expected_ff_output_beats();
        if (expected_beats == 0)
            return;

        if (p_sequencer.vif == null)
            `uvm_fatal("VSEQ", "Virtual sequencer vif is not set; cannot wait for FF output completion")

        seen_beats = 0;
        idle_cycles = 0;

        while (seen_beats < expected_beats) begin
            @(posedge p_sequencer.vif.clk_i);

            if (!p_sequencer.vif.rst_ni) begin
                idle_cycles = 0;
                continue;
            end

            if (p_sequencer.vif.ff_valid_o && p_sequencer.vif.ff_ready_i) begin
                seen_beats++;
                idle_cycles = 0;
            end else begin
                idle_cycles++;
                if (idle_cycles > 1000000) begin
                    `uvm_fatal("VSEQ",
                        $sformatf("Timeout waiting for FF output completion: seen=%0d expected=%0d",
                            seen_beats, expected_beats))
                end
            end
        end
    endtask : wait_feedforward_complete

    task send_head_streams(ita_mha8_step_payload payload, int unsigned head_id);
        int unsigned beats;

        beats = payload.input_payload_by_head[head_id].size();
        if (payload.weight_payload_by_head[head_id].size() != beats ||
            payload.bias_payload_by_head[head_id].size() != beats) begin
            `uvm_fatal("VSEQ",
                $sformatf("Lockstep source size mismatch for %s head%0d: input=%0d weight=%0d bias=%0d",
                    payload.step.name(),
                    head_id,
                    payload.input_payload_by_head[head_id].size(),
                    payload.weight_payload_by_head[head_id].size(),
                    payload.bias_payload_by_head[head_id].size()))
        end

        for (int unsigned beat = 0; beat < beats; beat++) begin
            wait_lockstep_idle_gap();
            if (source_skew_enabled()) begin
                fork
                    send_head_stream_beat(payload, head_id, ITA_STREAM_HEAD_WEIGHT, beat, source_skew_lockstep);
                    send_head_stream_beat(payload, head_id, ITA_STREAM_HEAD_INPUT, beat, source_skew_lockstep);
                    send_head_stream_beat(payload, head_id, ITA_STREAM_HEAD_BIAS, beat, source_skew_lockstep);
                join
            end else begin
                drive_head_lockstep_beat(payload, head_id, beat);
            end
        end
    endtask : send_head_streams

    function bit source_skew_enabled();
        return (source_gap_max != 0 ||
                input_source_gap_max != 0 ||
                weight_source_gap_max != 0 ||
                bias_source_gap_max != 0);
    endfunction : source_skew_enabled

    task wait_lockstep_idle_gap();
        int unsigned gap_cycles;

        if (lockstep_idle_gap_max == 0)
            return;

        gap_cycles = $urandom_range(lockstep_idle_gap_max, lockstep_idle_gap_min);
        repeat (gap_cycles) begin
            @(posedge p_sequencer.vif.clk_i);
        end
    endtask : wait_lockstep_idle_gap

    task send_head_stream_beat(
        ita_mha8_step_payload payload,
        int unsigned head_id,
        ita_stream_kind_e kind,
        int unsigned beat,
        bit is_lockstep = 1'b1
    );
        ita_stream_single_seq stream_seq;

        stream_seq = ita_stream_single_seq::type_id::create($sformatf("%s_seq_%s_h%0d_b%0d", kind.name(), payload.step.name(), head_id, beat));
        stream_seq.stream = make_stream_item(payload, kind, head_id, 0, beat, is_lockstep);

        case (kind)
            ITA_STREAM_HEAD_INPUT:  stream_seq.start(p_sequencer.inp_sqr[head_id]);
            ITA_STREAM_HEAD_WEIGHT: stream_seq.start(p_sequencer.weight_sqr[head_id]);
            ITA_STREAM_HEAD_BIAS:   stream_seq.start(p_sequencer.bias_sqr[head_id]);
            default:
                `uvm_fatal("VSEQ", $sformatf("Unsupported head source kind %s", kind.name()))
        endcase
    endtask : send_head_stream_beat

    task drive_head_lockstep_beat(
        ita_mha8_step_payload payload,
        int unsigned head_id,
        int unsigned beat
    );
        ita_stream_item inp_tr;
        ita_stream_item weight_tr;
        ita_stream_item bias_tr;
        int unsigned wait_cycles;

        inp_tr = make_stream_item(payload, ITA_STREAM_HEAD_INPUT, head_id, 0, beat, 1'b1);
        weight_tr = make_stream_item(payload, ITA_STREAM_HEAD_WEIGHT, head_id, 0, beat, 1'b1);
        bias_tr = make_stream_item(payload, ITA_STREAM_HEAD_BIAS, head_id, 0, beat, 1'b1);

        @(posedge p_sequencer.vif.clk_i);
        p_sequencer.vif.inp_i[head_id] <= inp_tr.inp;
        p_sequencer.vif.inp_weight_i[head_id] <= weight_tr.weight;
        p_sequencer.vif.inp_bias_i[head_id] <= bias_tr.bias;
        p_sequencer.vif.inp_valid_i[head_id] <= 1'b1;
        p_sequencer.vif.inp_weight_valid_i[head_id] <= 1'b1;
        p_sequencer.vif.inp_bias_valid_i[head_id] <= 1'b1;
        p_sequencer.vif.inp_step_dbg[head_id] <= payload.step;
        p_sequencer.vif.inp_weight_step_dbg[head_id] <= payload.step;
        p_sequencer.vif.inp_bias_step_dbg[head_id] <= payload.step;
        p_sequencer.vif.inp_tile_id_dbg[head_id] <= payload.tile_id;
        p_sequencer.vif.inp_weight_tile_id_dbg[head_id] <= payload.tile_id;
        p_sequencer.vif.inp_bias_tile_id_dbg[head_id] <= payload.tile_id;
        p_sequencer.vif.inp_inner_id_dbg[head_id] <= payload.inner_tile_id;
        p_sequencer.vif.inp_weight_inner_id_dbg[head_id] <= payload.inner_tile_id;
        p_sequencer.vif.inp_bias_inner_id_dbg[head_id] <= payload.inner_tile_id;
        p_sequencer.vif.inp_beat_id_dbg[head_id] <= beat;
        p_sequencer.vif.inp_weight_beat_id_dbg[head_id] <= beat;
        p_sequencer.vif.inp_bias_beat_id_dbg[head_id] <= beat;
        p_sequencer.vif.inp_lockstep_dbg[head_id] <= 1'b1;
        p_sequencer.vif.inp_weight_lockstep_dbg[head_id] <= 1'b1;
        p_sequencer.vif.inp_bias_lockstep_dbg[head_id] <= 1'b1;

        wait_cycles = 0;
        do begin
            @(posedge p_sequencer.vif.clk_i);
            wait_cycles++;
            if (wait_cycles > 10000)
                `uvm_fatal("VSEQ", $sformatf("Timeout waiting for head%0d lockstep source ready", head_id))
        end while (!(p_sequencer.vif.inp_ready_o[head_id] &&
                     p_sequencer.vif.inp_weight_ready_o[head_id] &&
                     p_sequencer.vif.inp_bias_ready_o[head_id]));

        p_sequencer.vif.inp_valid_i[head_id] <= 1'b0;
        p_sequencer.vif.inp_weight_valid_i[head_id] <= 1'b0;
        p_sequencer.vif.inp_bias_valid_i[head_id] <= 1'b0;
    endtask : drive_head_lockstep_beat

    task send_weight_stream(ita_mha8_step_payload payload, int unsigned head_id, bit is_lockstep = 1'b1);
        ita_stream_single_seq weight_seq;

        for (int unsigned beat = 0; beat < payload.weight_payload_by_head[head_id].size(); beat++) begin
            weight_seq = ita_stream_single_seq::type_id::create($sformatf("weight_seq_%s_h%0d_b%0d", payload.step.name(), head_id, beat));
            weight_seq.stream = make_stream_item(payload, ITA_STREAM_HEAD_WEIGHT, head_id, 0, beat, is_lockstep);
            weight_seq.start(p_sequencer.weight_sqr[head_id]);
        end
    endtask : send_weight_stream

    task send_input_stream(ita_mha8_step_payload payload, int unsigned head_id, bit is_lockstep = 1'b1);
        ita_stream_single_seq inp_seq;

        for (int unsigned beat = 0; beat < payload.input_payload_by_head[head_id].size(); beat++) begin
            inp_seq = ita_stream_single_seq::type_id::create($sformatf("input_seq_%s_h%0d_b%0d", payload.step.name(), head_id, beat));
            inp_seq.stream = make_stream_item(payload, ITA_STREAM_HEAD_INPUT, head_id, 0, beat, is_lockstep);
            inp_seq.start(p_sequencer.inp_sqr[head_id]);
        end
    endtask : send_input_stream

    task send_bias_stream(ita_mha8_step_payload payload, int unsigned head_id, bit is_lockstep = 1'b1);
        ita_stream_single_seq bias_seq;

        for (int unsigned beat = 0; beat < payload.bias_payload_by_head[head_id].size(); beat++) begin
            bias_seq = ita_stream_single_seq::type_id::create($sformatf("bias_seq_%s_h%0d_b%0d", payload.step.name(), head_id, beat));
            bias_seq.stream = make_stream_item(payload, ITA_STREAM_HEAD_BIAS, head_id, 0, beat, is_lockstep);
            bias_seq.start(p_sequencer.bias_sqr[head_id]);
        end
    endtask : send_bias_stream

    // FF streams are global; head_id is unused and kept as 0 for common item metadata.
    task send_ff_input_stream(ita_mha8_step_payload payload);
        ita_stream_single_seq inp_seq;

        for (int unsigned beat = 0; beat < payload.ff_input_payload.size(); beat ++) begin
            inp_seq = ita_stream_single_seq::type_id::create($sformatf("ff_input_seq_%s_b%0d", payload.step.name(), beat));
            inp_seq.stream = make_stream_item(payload, ITA_STREAM_FF_INPUT, 0, 0, beat, 1'b1);
            inp_seq.start(p_sequencer.ff_inp_sqr);
        end
    endtask : send_ff_input_stream

    task send_ff_weight_stream(ita_mha8_step_payload payload, bit is_lockstep = 1'b1);
        ita_stream_single_seq weight_seq;

        for (int unsigned beat = 0; beat < payload.ff_weight_payload.size(); beat ++) begin
            weight_seq = ita_stream_single_seq::type_id::create($sformatf("ff_weight_seq_%s_b%0d", payload.step.name(), beat));
            weight_seq.stream = make_stream_item(payload, ITA_STREAM_FF_WEIGHT, 0, 0, beat, is_lockstep);
            weight_seq.start(p_sequencer.ff_weight_sqr);
        end
    endtask : send_ff_weight_stream

    task send_ff_bias_stream(ita_mha8_step_payload payload);
        ita_stream_single_seq bias_seq;

        for (int unsigned beat = 0; beat < payload.ff_bias_payload.size(); beat ++) begin
            bias_seq = ita_stream_single_seq::type_id::create($sformatf("ff_bias_seq_%s_b%0d", payload.step.name(), beat));
            bias_seq.stream = make_stream_item(payload, ITA_STREAM_FF_BIAS, 0, 0, beat, 1'b1);
            bias_seq.start(p_sequencer.ff_bias_sqr);
        end
    endtask : send_ff_bias_stream

    function ita_ctrl_item make_ctrl_item(
        ita_mha8_core_item core,
        layer_e layer_value,
        step_e ctrl_step,
        activation_e activation_value,
        bit start_value
    );
        ita_ctrl_item ctrl;
        ctrl = ita_ctrl_item::type_id::create("ctrl");

        ctrl.ctrl.layer = layer_value;
        ctrl.ctrl.activation = activation_value;
        ctrl.ctrl.tile_s = core.tile_s;
        ctrl.ctrl.tile_e = core.tile_e;
        ctrl.ctrl.tile_p = core.tile_p;
        ctrl.ctrl.tile_f = core.tile_f;
        ctrl.ctrl.start = start_value;
        ctrl.ctrl.gelu_b = core.gelu_b;
        ctrl.ctrl.gelu_c = core.gelu_c;
        ctrl.ctrl.activation_requant_mult  = 8'd1;
        ctrl.ctrl.activation_requant_shift = 8'd0;
        ctrl.ctrl.activation_requant_add   = '0;

        if (core.has_requant_config) begin
            for (int unsigned h = 0; h < 8; h++) begin
                ctrl.head_eps_mult[h]    = core.head_eps_mult[h];
                ctrl.head_right_shift[h] = core.head_right_shift[h];
                ctrl.head_add[h]         = core.head_add[h];
            end
            ctrl.sum_eps_mult    = core.sum_eps_mult;
            ctrl.sum_right_shift = core.sum_right_shift;
            ctrl.sum_add         = core.sum_add;
            ctrl.ff_eps_mult     = core.ff_eps_mult;
            ctrl.ff_right_shift  = core.ff_right_shift;
            ctrl.ff_add          = core.ff_add;

            if (layer_value == Feedforward && activation_value != Identity) begin
                ctrl.ctrl.activation_requant_mult  = core.activation_requant_mult;
                ctrl.ctrl.activation_requant_shift = core.activation_requant_shift;
                ctrl.ctrl.activation_requant_add   = core.activation_requant_add;
            end
        end else begin
            ctrl.set_all_heads_identity_requant_for_step(ctrl_step);
            ctrl.set_ff_identity_requant_for_step(ctrl_step);
            ctrl.sum_eps_mult    = 8'd1;
            ctrl.sum_right_shift = 8'd0;
            ctrl.sum_add         = '0;
        end

        ctrl.ctrl.eps_mult    = ctrl.ff_eps_mult;
        ctrl.ctrl.right_shift = ctrl.ff_right_shift;
        ctrl.ctrl.add         = ctrl.ff_add;

        return ctrl;
    endfunction : make_ctrl_item

    function ita_stream_item make_stream_item(
        ita_mha8_step_payload payload,
        ita_stream_kind_e kind,
        int unsigned head_id,
        int unsigned inner_tile_id,
        int unsigned beat_id,
        bit is_lockstep
    );
        ita_stream_item tr;
        tr = ita_stream_item::type_id::create($sformatf("tr_%s_h%0d_b%0d", kind.name(), head_id, beat_id));

        tr.kind = kind;
        tr.head_id = head_id;
        tr.tile_id = payload.tile_id;
        tr.inner_tile_id = payload.inner_tile_id;
        tr.beat_id = beat_id;
        tr.is_lockstep = is_lockstep;
        tr.step = payload.step;

        case(kind)
            ITA_STREAM_HEAD_INPUT:
                if (payload.input_payload_by_head[head_id].size() > beat_id)
                    tr.inp = payload.input_payload_by_head[head_id][beat_id];
                else
                    tr.inp = '0;
            ITA_STREAM_HEAD_WEIGHT:
                if (payload.weight_payload_by_head[head_id].size() > beat_id)
                    tr.weight = payload.weight_payload_by_head[head_id][beat_id];
                else
                    tr.weight = '0;
            ITA_STREAM_HEAD_BIAS:
                if (payload.bias_payload_by_head[head_id].size() > beat_id)
                    tr.bias = payload.bias_payload_by_head[head_id][beat_id];
                else
                    tr.bias = '0;
            ITA_STREAM_FF_INPUT:
                if (payload.ff_input_payload.size() > beat_id)
                    tr.inp = payload.ff_input_payload[beat_id];
                else
                    tr.inp = '0;
            ITA_STREAM_FF_WEIGHT:
                if (payload.ff_weight_payload.size() > beat_id)
                    tr.weight = payload.ff_weight_payload[beat_id];
                else
                    tr.weight = '0;
            ITA_STREAM_FF_BIAS:
                if (payload.ff_bias_payload.size() > beat_id)
                    tr.bias = payload.ff_bias_payload[beat_id];
                else
                    tr.bias = '0;
            default:
                `uvm_warning(get_type_name(), $sformatf("Unhandled stream kind: %s", kind.name()))
        endcase

        return tr;
    endfunction : make_stream_item

    task send_step_payload(ita_mha8_step_payload payload);
        if (!source_skew_enabled()) begin
            send_step_payload_reference_model(payload);
            return;
        end

        for (int unsigned h = 0; h < 8; h++) begin
            automatic int unsigned head_id = h;
            fork
                send_head_streams(payload, head_id);
            join_none
        end
        wait fork;
    endtask

    task send_step_payload_reference_model(ita_mha8_step_payload payload);
        for (int unsigned h = 0; h < 8; h++) begin
            automatic int unsigned head_id = h;
            fork
                send_head_input_bias_streams(payload, head_id);
                send_weight_stream(payload, head_id, 1'b0);
            join_none
        end
        wait fork;
    endtask : send_step_payload_reference_model

    task send_head_input_bias_streams(ita_mha8_step_payload payload, int unsigned head_id);
        int unsigned beats;

        beats = payload.input_payload_by_head[head_id].size();
        if (payload.bias_payload_by_head[head_id].size() != beats) begin
            `uvm_fatal("VSEQ",
                $sformatf("Head input/bias size mismatch for %s head%0d: input=%0d bias=%0d",
                    payload.step.name(),
                    head_id,
                    payload.input_payload_by_head[head_id].size(),
                    payload.bias_payload_by_head[head_id].size()))
        end

        for (int unsigned beat = 0; beat < beats; beat++) begin
            wait_lockstep_idle_gap();
            fork
                send_head_stream_beat(payload, head_id, ITA_STREAM_HEAD_INPUT, beat, 1'b0);
                send_head_stream_beat(payload, head_id, ITA_STREAM_HEAD_BIAS, beat, 1'b0);
            join
        end
    endtask : send_head_input_bias_streams

    task send_step_payload_head_bundle(ita_mha8_step_payload payload);
        int unsigned beats;

        beats = payload.input_payload_by_head[0].size();
        for (int unsigned h = 0; h < 8; h++) begin
            if (payload.input_payload_by_head[h].size() != beats ||
                payload.weight_payload_by_head[h].size() != beats ||
                payload.bias_payload_by_head[h].size() != beats) begin
                `uvm_fatal("VSEQ",
                    $sformatf("Head bundle source size mismatch for %s head%0d: input=%0d weight=%0d bias=%0d expected=%0d",
                        payload.step.name(),
                        h,
                        payload.input_payload_by_head[h].size(),
                        payload.weight_payload_by_head[h].size(),
                        payload.bias_payload_by_head[h].size(),
                        beats))
            end
        end

        for (int unsigned beat = 0; beat < beats; beat++) begin
            wait_lockstep_idle_gap();
            for (int unsigned h = 0; h < 8; h++) begin
                automatic int unsigned head_id = h;
                fork
                    drive_head_lockstep_beat(payload, head_id, beat);
                join_none
            end
            wait fork;
        end
    endtask : send_step_payload_head_bundle

    task send_ff_payload(ita_mha8_step_payload payload);
        int unsigned beats;

        beats = payload.ff_input_payload.size();
        if (payload.ff_weight_payload.size() != beats ||
            payload.ff_bias_payload.size() != beats) begin
            `uvm_fatal("VSEQ",
                $sformatf("Lockstep FF source size mismatch for %s: input=%0d weight=%0d bias=%0d",
                    payload.step.name(),
                    payload.ff_input_payload.size(),
                    payload.ff_weight_payload.size(),
                    payload.ff_bias_payload.size()))
        end

        for (int unsigned beat = 0; beat < beats; beat++) begin
            wait_lockstep_idle_gap();
            if (source_skew_enabled()) begin
                fork
                    send_ff_stream_beat(payload, ITA_STREAM_FF_INPUT, beat, source_skew_lockstep);
                    send_ff_stream_beat(payload, ITA_STREAM_FF_WEIGHT, beat, source_skew_lockstep);
                    send_ff_stream_beat(payload, ITA_STREAM_FF_BIAS, beat, source_skew_lockstep);
                join
            end else begin
                `uvm_fatal("VSEQ", "Internal error: send_ff_payload reference path should not enter beat lockstep drive")
            end
        end
    endtask : send_ff_payload

    task send_ff_payload_reference_model(ita_mha8_step_payload payload);
        fork
            send_ff_input_bias_streams(payload);
            send_ff_weight_stream(payload, 1'b0);
        join
    endtask : send_ff_payload_reference_model

    task send_ff_input_bias_streams(ita_mha8_step_payload payload);
        int unsigned beats;

        beats = payload.ff_input_payload.size();
        if (payload.ff_bias_payload.size() != beats) begin
            `uvm_fatal("VSEQ",
                $sformatf("FF input/bias size mismatch for %s: input=%0d bias=%0d",
                    payload.step.name(),
                    payload.ff_input_payload.size(),
                    payload.ff_bias_payload.size()))
        end

        for (int unsigned beat = 0; beat < beats; beat++) begin
            wait_lockstep_idle_gap();
            fork
                send_ff_stream_beat(payload, ITA_STREAM_FF_INPUT, beat, 1'b0);
                send_ff_stream_beat(payload, ITA_STREAM_FF_BIAS, beat, 1'b0);
            join
        end
    endtask : send_ff_input_bias_streams

    task send_ff_stream_beat(
        ita_mha8_step_payload payload,
        ita_stream_kind_e kind,
        int unsigned beat,
        bit is_lockstep = 1'b1
    );
        ita_stream_single_seq stream_seq;

        stream_seq = ita_stream_single_seq::type_id::create($sformatf("%s_seq_%s_b%0d", kind.name(), payload.step.name(), beat));
        stream_seq.stream = make_stream_item(payload, kind, 0, 0, beat, is_lockstep);

        case (kind)
            ITA_STREAM_FF_INPUT:  stream_seq.start(p_sequencer.ff_inp_sqr);
            ITA_STREAM_FF_WEIGHT: stream_seq.start(p_sequencer.ff_weight_sqr);
            ITA_STREAM_FF_BIAS:   stream_seq.start(p_sequencer.ff_bias_sqr);
            default:
                `uvm_fatal("VSEQ", $sformatf("Unsupported FF source kind %s", kind.name()))
        endcase
    endtask : send_ff_stream_beat

    task drive_ff_lockstep_beat(ita_mha8_step_payload payload, int unsigned beat);
        ita_stream_item inp_tr;
        ita_stream_item weight_tr;
        ita_stream_item bias_tr;
        int unsigned wait_cycles;

        inp_tr = make_stream_item(payload, ITA_STREAM_FF_INPUT, 0, 0, beat, 1'b1);
        weight_tr = make_stream_item(payload, ITA_STREAM_FF_WEIGHT, 0, 0, beat, 1'b1);
        bias_tr = make_stream_item(payload, ITA_STREAM_FF_BIAS, 0, 0, beat, 1'b1);

        @(posedge p_sequencer.vif.clk_i);
        p_sequencer.vif.ff_inp_i <= inp_tr.inp;
        p_sequencer.vif.ff_inp_weight_i <= weight_tr.weight;
        p_sequencer.vif.ff_inp_bias_i <= bias_tr.bias;
        p_sequencer.vif.ff_inp_valid_i <= 1'b1;
        p_sequencer.vif.ff_inp_weight_valid_i <= 1'b1;
        p_sequencer.vif.ff_inp_bias_valid_i <= 1'b1;
        p_sequencer.vif.ff_inp_step_dbg <= payload.step;
        p_sequencer.vif.ff_inp_weight_step_dbg <= payload.step;
        p_sequencer.vif.ff_inp_bias_step_dbg <= payload.step;
        p_sequencer.vif.ff_inp_tile_id_dbg <= payload.tile_id;
        p_sequencer.vif.ff_inp_weight_tile_id_dbg <= payload.tile_id;
        p_sequencer.vif.ff_inp_bias_tile_id_dbg <= payload.tile_id;
        p_sequencer.vif.ff_inp_inner_id_dbg <= payload.inner_tile_id;
        p_sequencer.vif.ff_inp_weight_inner_id_dbg <= payload.inner_tile_id;
        p_sequencer.vif.ff_inp_bias_inner_id_dbg <= payload.inner_tile_id;
        p_sequencer.vif.ff_inp_beat_id_dbg <= beat;
        p_sequencer.vif.ff_inp_weight_beat_id_dbg <= beat;
        p_sequencer.vif.ff_inp_bias_beat_id_dbg <= beat;
        p_sequencer.vif.ff_inp_lockstep_dbg <= 1'b1;
        p_sequencer.vif.ff_inp_weight_lockstep_dbg <= 1'b1;
        p_sequencer.vif.ff_inp_bias_lockstep_dbg <= 1'b1;

        wait_cycles = 0;
        do begin
            @(posedge p_sequencer.vif.clk_i);
            wait_cycles++;
            if (wait_cycles > 10000)
                `uvm_fatal("VSEQ", "Timeout waiting for FF lockstep source ready")
        end while (!(p_sequencer.vif.ff_inp_ready_o &&
                     p_sequencer.vif.ff_inp_weight_ready_o &&
                     p_sequencer.vif.ff_inp_bias_ready_o));

        p_sequencer.vif.ff_inp_valid_i <= 1'b0;
        p_sequencer.vif.ff_inp_weight_valid_i <= 1'b0;
        p_sequencer.vif.ff_inp_bias_valid_i <= 1'b0;
    endtask : drive_ff_lockstep_beat

endclass : ita_mha8_vsequence
`endif // ITA_MHA8_VSEQUENCE_SVH

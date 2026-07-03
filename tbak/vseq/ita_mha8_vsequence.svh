`ifndef ITA_MHA8_VSEQUENCE_SVH
`define ITA_MHA8_VSEQUENCE_SVH

class ita_mha8_vsequence extends uvm_sequence;
    `uvm_object_utils(ita_mha8_vsequence)
    `uvm_declare_p_sequencer(ita_mha8_vsequencer)

    ita_mha8_core_item core;

    function new(string name = "ita_mha8_vsequence");
        super.new(name);
    endfunction : new

    virtual task body();
        if (core == null)
            core = ita_mha8_core_item::type_id::create("core");

        if (has_ff_steps()) begin
            fork
                send_attention_phase();
                wait_attention_sum_complete();
            join
            send_feedforward_phase();
        end else begin
            send_attention_phase();
        end
    endtask : body

    task send_attention_phase();
        ita_ctrl_single_seq ctrl_seq;

        ctrl_seq = ita_ctrl_single_seq::type_id::create("ctrl_seq");
        ctrl_seq.ctrl = make_ctrl_item(core, Attention, first_attention_step());
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
        ita_ctrl_single_seq ctrl_seq;

        ctrl_seq = ita_ctrl_single_seq::type_id::create("ff_ctrl_seq");
        ctrl_seq.ctrl = make_ctrl_item(core, Feedforward, first_ff_step());
        ctrl_seq.start(p_sequencer.ctrl_sqr);

        foreach (core.payload_schedule[i]) begin
            ita_mha8_step_payload payload;

            payload = core.payload_schedule[i];

            if (!is_ff_step(payload.step))
                continue;

            if (payload.drive_ff_streams)
                send_ff_payload(payload);
        end
    endtask

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
        foreach (core.step_order[i]) begin
            ita_mha8_step_payload payload;

            payload = core.get_payload(core.step_order[i]);
            if (payload.expect_sum_output) begin
                if (core.tile_p == 0)
                    return payload.input_payload_by_head[0].size();
                return payload.input_payload_by_head[0].size() / core.tile_p;
            end
        end

        return 0;
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

    task send_head_streams(ita_mha8_step_payload payload, int unsigned head_id);
        fork
            send_weight_stream(payload, head_id);
            send_input_stream(payload, head_id);
            send_bias_stream(payload, head_id);
        join
    endtask : send_head_streams

    task send_weight_stream(ita_mha8_step_payload payload, int unsigned head_id);
        ita_stream_single_seq weight_seq;

        for (int unsigned beat = 0; beat < payload.weight_payload_by_head[head_id].size(); beat++) begin
            weight_seq = ita_stream_single_seq::type_id::create($sformatf("weight_seq_%s_h%0d_b%0d", payload.step.name(), head_id, beat));
            weight_seq.stream = make_stream_item(payload, ITA_STREAM_HEAD_WEIGHT, head_id, 0, beat, 1'b1);
            weight_seq.start(p_sequencer.weight_sqr[head_id]);
        end
    endtask : send_weight_stream

    task send_input_stream(ita_mha8_step_payload payload, int unsigned head_id);
        ita_stream_single_seq inp_seq;

        for (int unsigned beat = 0; beat < payload.input_payload_by_head[head_id].size(); beat++) begin
            inp_seq = ita_stream_single_seq::type_id::create($sformatf("input_seq_%s_h%0d_b%0d", payload.step.name(), head_id, beat));
            inp_seq.stream = make_stream_item(payload, ITA_STREAM_HEAD_INPUT, head_id, 0, beat, 1'b1);
            inp_seq.start(p_sequencer.inp_sqr[head_id]);
        end
    endtask : send_input_stream

    task send_bias_stream(ita_mha8_step_payload payload, int unsigned head_id);
        ita_stream_single_seq bias_seq;

        for (int unsigned beat = 0; beat < payload.bias_payload_by_head[head_id].size(); beat++) begin
            bias_seq = ita_stream_single_seq::type_id::create($sformatf("bias_seq_%s_h%0d_b%0d", payload.step.name(), head_id, beat));
            bias_seq.stream = make_stream_item(payload, ITA_STREAM_HEAD_BIAS, head_id, 0, beat, 1'b1);
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

    task send_ff_weight_stream(ita_mha8_step_payload payload);
        ita_stream_single_seq weight_seq;

        for (int unsigned beat = 0; beat < payload.ff_weight_payload.size(); beat ++) begin
            weight_seq = ita_stream_single_seq::type_id::create($sformatf("ff_weight_seq_%s_b%0d", payload.step.name(), beat));
            weight_seq.stream = make_stream_item(payload, ITA_STREAM_FF_WEIGHT, 0, 0, beat, 1'b1);
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
        step_e ctrl_step
    );
        ita_ctrl_item ctrl;
        int unsigned activation_requant_idx;
        ctrl = ita_ctrl_item::type_id::create("ctrl");

        ctrl.ctrl.layer = layer_value;
        ctrl.ctrl.activation = core.activation;
        ctrl.ctrl.tile_s = core.tile_s;
        ctrl.ctrl.tile_e = core.tile_e;
        ctrl.ctrl.tile_p = core.tile_p;
        ctrl.ctrl.tile_f = core.tile_f;
        ctrl.ctrl.start = 1'b1;
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

            if (layer_value == Feedforward && core.activation != Identity) begin
                activation_requant_idx = ctrl.requant_index_for_step(F1);
                ctrl.ctrl.activation_requant_mult  = core.ff_eps_mult[activation_requant_idx];
                ctrl.ctrl.activation_requant_shift = core.ff_right_shift[activation_requant_idx];
                ctrl.ctrl.activation_requant_add   = core.ff_add[activation_requant_idx];
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
        for (int unsigned h = 0; h < 8; h++) begin
            automatic int unsigned head_id = h;
            fork
                send_head_streams(payload, head_id);
            join_none
        end
        wait fork;
    endtask

    task send_ff_payload(ita_mha8_step_payload payload);
        fork
            send_ff_input_stream(payload);
            send_ff_weight_stream(payload);
            send_ff_bias_stream(payload);
        join
    endtask : send_ff_payload

endclass : ita_mha8_vsequence
`endif // ITA_MHA8_VSEQUENCE_SVH

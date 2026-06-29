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
        ita_ctrl_single_seq ctrl_seq;
        step_e directed_step;
        int unsigned heads;

        if (core == null)
            core = ita_mha8_core_item::type_id::create("core");

        directed_step = core.stream_step;
        if (directed_step == Idle)
            directed_step = (core.layer == Linear) ? MatMul : Q;
        heads = core.active_heads();

        ctrl_seq = ita_ctrl_single_seq::type_id::create("ctrl_seq");
        ctrl_seq.ctrl = make_ctrl_item(core);
        ctrl_seq.start(p_sequencer.ctrl_sqr);

        for (int unsigned h = 0; h < heads; h++) begin
            automatic int unsigned head_id = h;
            fork
                send_head_streams(head_id, directed_step);
            join_none
        end
        wait fork;
    endtask : body

    task send_head_streams(int unsigned head_id, step_e directed_step);
        fork
            send_weight_stream(head_id, directed_step);
            send_input_stream(head_id, directed_step);
            send_bias_stream(head_id, directed_step);
        join
    endtask : send_head_streams

    task send_weight_stream(int unsigned head_id, step_e directed_step);
        ita_stream_single_seq weight_seq;

        for (int unsigned beat = 0; beat < core.weight_payload_by_head[head_id].size(); beat++) begin
            weight_seq = ita_stream_single_seq::type_id::create($sformatf("weight_seq_h%0d_b%0d", head_id, beat));
            weight_seq.stream = make_stream_item(core, ITA_STREAM_HEAD_WEIGHT, head_id, 0, beat, 1'b1, directed_step);
            weight_seq.start(p_sequencer.weight_sqr[head_id]);
        end
    endtask : send_weight_stream

    task send_input_stream(int unsigned head_id, step_e directed_step);
        ita_stream_single_seq inp_seq;

        for (int unsigned beat = 0; beat < core.input_payload_by_head[head_id].size(); beat++) begin
            inp_seq = ita_stream_single_seq::type_id::create($sformatf("inp_seq_h%0d_b%0d", head_id, beat));
            inp_seq.stream = make_stream_item(core, ITA_STREAM_HEAD_INPUT, head_id, 0, beat, 1'b1, directed_step);
            inp_seq.start(p_sequencer.inp_sqr[head_id]);
        end
    endtask : send_input_stream

    task send_bias_stream(int unsigned head_id, step_e directed_step);
        ita_stream_single_seq bias_seq;

        for (int unsigned beat = 0; beat < core.bias_payload_by_head[head_id].size(); beat++) begin
            bias_seq = ita_stream_single_seq::type_id::create($sformatf("bias_seq_h%0d_b%0d", head_id, beat));
            bias_seq.stream = make_stream_item(core, ITA_STREAM_HEAD_BIAS, head_id, 0, beat, 1'b1, directed_step);
            bias_seq.start(p_sequencer.bias_sqr[head_id]);
        end
    endtask : send_bias_stream

    function ita_ctrl_item make_ctrl_item(ita_mha8_core_item core);
        ita_ctrl_item ctrl;
        step_e ctrl_step;
        ctrl = ita_ctrl_item::type_id::create("ctrl");

        ctrl_step = core.stream_step;
        if (ctrl_step == Idle)
            ctrl_step = (core.layer == Linear) ? MatMul : Q;

        ctrl.ctrl.layer = core.layer;
        ctrl.ctrl.activation = core.activation;
        ctrl.ctrl.tile_s = core.tile_s;
        ctrl.ctrl.tile_e = core.tile_e;
        ctrl.ctrl.tile_p = core.tile_p;
        ctrl.ctrl.tile_f = core.tile_f;
        ctrl.ctrl.start = 1'b1;

        if (core.has_requant_config) begin
            for (int unsigned h = 0; h < 8; h++) begin
                ctrl.head_eps_mult[h]    = core.head_eps_mult[h];
                ctrl.head_right_shift[h] = core.head_right_shift[h];
                ctrl.head_add[h]         = core.head_add[h];
            end
        end else begin
            ctrl.set_all_heads_identity_requant_for_step(ctrl_step);
        end

        return ctrl;
    endfunction : make_ctrl_item

    function ita_stream_item make_stream_item(
        ita_mha8_core_item core,
        ita_stream_kind_e kind,
        int unsigned head_id,
        int unsigned inner_tile_id,
        int unsigned beat_id,
        bit is_lockstep,
        step_e step
    );
        ita_stream_item tr;
        tr = ita_stream_item::type_id::create($sformatf("tr_h%0d_b%0d", head_id, beat_id));

        tr.kind = kind;
        tr.head_id = head_id;
        tr.tile_id = 0;
        tr.inner_tile_id = inner_tile_id;
        tr.beat_id = beat_id;
        tr.is_lockstep = is_lockstep;
        tr.step = step;

        case(kind)
            ITA_STREAM_HEAD_INPUT:
                if (core.input_payload_by_head[head_id].size() > beat_id)
                    tr.inp = core.input_payload_by_head[head_id][beat_id];
                else
                    tr.inp = '0;
            ITA_STREAM_HEAD_WEIGHT:
                if (core.weight_payload_by_head[head_id].size() > beat_id)
                    tr.weight = core.weight_payload_by_head[head_id][beat_id];
                else
                    tr.weight = '0;
            ITA_STREAM_HEAD_BIAS:
                if (core.bias_payload_by_head[head_id].size() > beat_id)
                    tr.bias = core.bias_payload_by_head[head_id][beat_id];
                else
                    tr.bias = '0;
            default:
                `uvm_warning(get_type_name(), $sformatf("Unhandled stream kind: %s", kind.name()))
        endcase

        return tr;
    endfunction : make_stream_item

endclass : ita_mha8_vsequence
`endif // ITA_MHA8_VSEQUENCE_SVH

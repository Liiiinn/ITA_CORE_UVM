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
        ita_stream_single_seq inp_seq;
        ita_stream_single_seq weight_seq;
        ita_stream_single_seq bias_seq;

        step_e directed_step;
        directed_step = (core.layer == Linear) ? MatMul : Q;

        if (core == null)
            core = ita_mha8_core_item::type_id::create("core");
        
        ctrl_seq = ita_ctrl_single_seq::type_id::create("ctrl_seq");
        ctrl_seq.ctrl = make_ctrl_item(core);
        ctrl_seq.start(p_sequencer.ctrl_sqr);

        // for (int unsigned beat = 0; beat < core.input_payload.size(); beat ++) begin
        //     inp_seq = ita_stream_single_seq::type_id::create($sformatf("inp_seq_%0d", beat));
        //     inp_seq.stream = make_stream_item(core, ITA_STREAM_HEAD_INPUT, 0, beat, 1'b1, directed_step);
        //     inp_seq.start(p_sequencer.inp_sqr);
        // end

        // for (int unsigned beat = 0; beat < core.weight_payload.size(); beat ++) begin
        //     weight_seq = ita_stream_single_seq::type_id::create($sformatf("weight_seq_%0d", beat));
        //     weight_seq.stream = make_stream_item(core, ITA_STREAM_HEAD_WEIGHT, 0, beat, 1'b1, directed_step);
        //     weight_seq.start(p_sequencer.weight_sqr);
        // end

        // for (int unsigned beat = 0; beat < core.bias_payload.size(); beat ++) begin
        //     bias_seq = ita_stream_single_seq::type_id::create($sformatf("bias_seq_%0d", beat));
        //     bias_seq.stream = make_stream_item(core, ITA_STREAM_HEAD_BIAS, 0, beat, 1'b1, directed_step);
        //     bias_seq.start(p_sequencer.bias_sqr);
        // end

        for (int unsigned beat = 0; beat < core.weight_payload.size(); beat++) begin
            weight_seq = ita_stream_single_seq::type_id::create($sformatf("weight_seq_%0d", beat));
            weight_seq.stream = make_stream_item(core, ITA_STREAM_HEAD_WEIGHT, 0, beat, 1'b1, directed_step);
            weight_seq.start(p_sequencer.weight_sqr);
        end

        fork
            begin
                inp_seq = ita_stream_single_seq::type_id::create("inp_seq_0");
                inp_seq.stream = make_stream_item(core, ITA_STREAM_HEAD_INPUT, 0, 0, 1'b1, directed_step);
                inp_seq.start(p_sequencer.inp_sqr);
            end
            begin
                bias_seq = ita_stream_single_seq::type_id::create("bias_seq_0");
                bias_seq.stream = make_stream_item(core, ITA_STREAM_HEAD_BIAS, 0, 0, 1'b1, directed_step);
                bias_seq.start(p_sequencer.bias_sqr);
            end
        join

    endtask : body

    function ita_ctrl_item make_ctrl_item(ita_mha8_core_item core);
        ita_ctrl_item ctrl;
        ctrl = ita_ctrl_item::type_id::create("ctrl");

        ctrl.ctrl.layer = core.layer;
        ctrl.ctrl.activation = core.activation;
        ctrl.ctrl.tile_s = core.tile_s;
        ctrl.ctrl.tile_e = core.tile_e;
        ctrl.ctrl.tile_p = core.tile_p;
        ctrl.ctrl.tile_f = core.tile_f;
        ctrl.ctrl.start = 1'b1;
        if (core.layer == Linear) begin
            ctrl.set_linear_head0_identity_requant();
        end

        return ctrl;
    endfunction

    function ita_stream_item make_stream_item(
        ita_mha8_core_item core,
        ita_stream_kind_e kind,
        int unsigned inner_tile_id,
        int unsigned beat_id,
        bit is_lockstep,
        step_e step
    );
        ita_stream_item tr;
        tr = ita_stream_item::type_id::create("tr");

        tr.kind = kind;
        tr.head_id = core.target_head_id;
        tr.tile_id = 0;
        tr.inner_tile_id = inner_tile_id;
        tr.beat_id = beat_id;
        tr.is_lockstep = is_lockstep;
        tr.step = step;

        case(kind)
            ITA_STREAM_HEAD_INPUT: 
                if (core.input_payload.size() > beat_id)
                    tr.inp = core.input_payload[beat_id];
                else
                    tr.inp = '0;
            ITA_STREAM_HEAD_WEIGHT: 
                if (core.weight_payload.size() > beat_id)
                    tr.weight = core.weight_payload[beat_id];
                else
                    tr.weight = '0;
            ITA_STREAM_HEAD_BIAS:
                if (core.bias_payload.size() > beat_id)
                    tr.bias = core.bias_payload[beat_id];
                else
                    tr.bias = '0;
            default:
                `uvm_warning(get_type_name(), $sformatf("Unhandles stream kind: %s", kind.name()))
        endcase

        return tr;
    endfunction


endclass : ita_mha8_vsequence
`endif // ITA_MHA8_VSEQUENCE_SVH

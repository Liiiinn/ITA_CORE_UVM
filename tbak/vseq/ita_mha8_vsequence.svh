`ifndef ITA_MHA8_VSEQUENCE_SVH
`define ITA_MHA8_VSEQUENCE_SVH

class ita_mha8_vsequence extends uvm_sequence;
    `uvm_object_utils(ita_mha8_vsequence)
    `uvm_declare_p_sequencer(ita_mha8_vsequencer)
    
    ita_mha8_core_item core;

    function new(string name = "ita_mha8_vsequence");
        super.new();
    endfunction : new

    virtual task body();
        ita_ctrl_single_seq ctrl_seq;
        ita_stream_single_seq inp_seq;
        ita_stream_single_seq weight_seq;
        ita_stream_single_seq bias_seq;

        if (core == null)
            core = ita_mha8_core_item::type_id::create("core");
        
        ctrl_seq = ita_mha8_base_seq::type_id::create("ctrl_seq");


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
            ITA_STREAM_HEAD_WEIGHT: tr.weight = core.weight_payload[beat_id];
            ITA_STREAM_HEAD_BIAS: tr.bias = core.bias_payload[beat_id];
            default:
                `uvm_warning(get_type_name(), $sformatf("Unhandles stream kind: %s", kind.name()));
        endcase

        return tr;
    endfunction


endclass : ita_mha8_vsequence
`endif // ITA_MHA8_VSEQUENCE_SVH
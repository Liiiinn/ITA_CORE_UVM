`ifndef ITA_MHA8_BASE_SEQ_SVH
`define ITA_MHA8_BASE_SEQ_SVH

class ita_mha8_base_seq extends uvm_sequence #(ita_ctrl_item);
    `uvm_object_utils(ita_mha8_base_seq)

    function new(string name = "ita_mha8_base_seq");
        super.new(name);
    endfunction : new

    task body();
        ita_ctrl_item ctrl;

        ctrl = ita_ctrl_item::type_id::create("ctrl");
        start_item(ctrl);
        ctrl.ctrl.start = 1'b0;
        ctrl.ctrl.layer = Attention;
        ctrl.ctrl.activation = Identity;
        ctrl.ctrl.tile_s = 1;
        ctrl.ctrl.tile_e = 1;
        ctrl.ctrl.tile_p = 1;
        ctrl.ctrl.tile_f = 1;
        finish_item(ctrl);
    endtask : body

endclass : ita_mha8_base_seq

class ita_mha8_stream_smoke_seq extends uvm_sequence #(ita_stream_item);
    `uvm_object_utils(ita_mha8_stream_smoke_seq)

    ita_stream_kind_e kind = ITA_STREAM_HEAD_INPUT;
    int unsigned head_id = 0;
    step_e step = Q;
    int unsigned tile_id = 0;
    int unsigned inner_tile_id = 0;
    int unsigned beat_id = 0;

    function new(string name = "ita_mha8_stream_smoke_seq");
        super.new(name);
    endfunction : new

    task body();
        ita_stream_item tr;

        tr = ita_stream_item::type_id::create("tr");
        start_item(tr);
        tr.kind = kind;
        tr.head_id = head_id;
        tr.step = step;
        tr.tile_id = tile_id;
        tr.inner_tile_id = inner_tile_id;
        tr.beat_id = beat_id;
        tr.is_lockstep = 1'b1;
        tr.inp = '0;
        tr.weight = '0;
        tr.bias = '0;
        finish_item(tr);
    endtask : body

endclass : ita_mha8_stream_smoke_seq

`endif // ITA_MHA8_BASE_SEQ_SVH

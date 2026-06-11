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

`endif // ITA_MHA8_BASE_SEQ_SVH

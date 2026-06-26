`ifndef ITA_CTRL_ITEM_SVH
`define ITA_CTRL_ITEM_SVH

class ita_ctrl_item extends uvm_sequence_item;
    `uvm_object_utils(ita_ctrl_item)

    ctrl_t ctrl;

    requant_const_array_t head_eps_mult    [8];
    requant_const_array_t head_right_shift [8];
    requant_array_t       head_add         [8];
    // Stage 2: initialize head0 requant defaults first; keep the per-head shape for Stage 11.

    function new(string name = "ita_ctrl_item");
        super.new(name);
        ctrl = '0;
        // Stage 2: set ctrl.layer, ctrl.activation, tile_s/e/p/f, and ctrl.start in the sequence or item helper.
        ctrl.layer = Attention;
        ctrl.activation = Identity;
        ctrl.tile_s = 1;
        ctrl.tile_e = 1;
        ctrl.tile_p = 1;
        ctrl.tile_f = 1;

        for (int unsigned h = 0; h < 8; h++) begin
            head_eps_mult[h]    = '0;
            head_right_shift[h] = '0;
            head_add[h]         = '0;
        end
    endfunction : new

    function void set_linear_head0_identity_requant();
        // MatMul is not listed in ita_requantization_controller and falls back to index 0.
        head_eps_mult[0]       = '0;
        head_right_shift[0]    = '0;
        head_add[0]            = '0;
        head_eps_mult[0][0]    = 8'd1;
        head_right_shift[0][0] = 8'd0;
        head_add[0][0]         = 8'sd0;
    endfunction : set_linear_head0_identity_requant

endclass : ita_ctrl_item

`endif // ITA_CTRL_ITEM_SVH

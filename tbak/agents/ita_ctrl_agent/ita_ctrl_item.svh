`ifndef ITA_CTRL_ITEM_SVH
`define ITA_CTRL_ITEM_SVH

class ita_ctrl_item extends uvm_sequence_item;
    `uvm_object_utils(ita_ctrl_item)

    ctrl_t                ctrl;
    // TODO Stage 2: use DUT ctrl_t directly for shared MHA8 ctrl; do not redefine a UVM-only ctrl struct.

    requant_const_array_t head_eps_mult    [8];
    requant_const_array_t head_right_shift [8];
    requant_array_t       head_add         [8];
    // TODO Stage 2: keep requant fields per-head; initialize head0 first, then heads 1-7 in Stage 11.

    function new(string name = "ita_ctrl_item");
        super.new(name);
        ctrl = '0;
        ctrl.layer = Attention;
        ctrl.activation = Identity;
        ctrl.tile_s = 1;
        ctrl.tile_e = 1;
        ctrl.tile_p = 1;
        ctrl.tile_f = 1;
        // TODO Stage 2: choose minimal shared ctrl defaults for the first ctrl smoke test.

        for (int unsigned h = 0; h < 8; h++) begin
            head_eps_mult[h]    = '0;
            head_right_shift[h] = '0;
            head_add[h]         = '0;
        end
    endfunction : new

endclass : ita_ctrl_item

`endif // ITA_CTRL_ITEM_SVH

`ifndef ITA_CTRL_ITEM_SVH
`define ITA_CTRL_ITEM_SVH

class ita_ctrl_item extends uvm_sequence_item;
    `uvm_object_utils(ita_ctrl_item)

    ctrl_t ctrl;

    requant_const_array_t head_eps_mult    [8];
    requant_const_array_t head_right_shift [8];
    requant_array_t       head_add         [8];
    requant_const_t       sum_eps_mult;
    requant_const_t       sum_right_shift;
    requant_t             sum_add;
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
        sum_eps_mult    = '0;
        sum_right_shift = '0;
        sum_add         = '0;
    endfunction : new

    function int unsigned requant_index_for_step(step_e step);
        case (step)
            Q:       return 0;
            K:       return 1;
            V:       return 2;
            QK:      return 3;
            AV:      return 4;
            OW:      return 5;
            F1:      return 6;
            F2:      return 7;
            MatMul:  return 0;
            default: return 0;
        endcase
    endfunction : requant_index_for_step

    function void set_head_identity_requant_for_step(int unsigned head_id, step_e step);
        int unsigned idx;

        if (head_id >= 8) begin
            `uvm_error("CTRL_ITEM", $sformatf("Illegal head_id for requant config: %0d", head_id))
            return;
        end

        idx = requant_index_for_step(step);
        head_eps_mult[head_id]       = '0;
        head_right_shift[head_id]    = '0;
        head_add[head_id]            = '0;
        head_eps_mult[head_id][idx]    = 8'd1;
        head_right_shift[head_id][idx] = 8'd0;
        head_add[head_id][idx]         = 8'sd0;
    endfunction : set_head_identity_requant_for_step

    function void set_all_heads_identity_requant_for_step(step_e step);
        for (int unsigned h = 0; h < 8; h++) begin
            set_head_identity_requant_for_step(h, step);
        end
    endfunction : set_all_heads_identity_requant_for_step

    function void set_linear_head_identity_requant(int unsigned head_id);
        // MatMul is not listed in ita_requantization_controller and falls back to index 0.
        set_head_identity_requant_for_step(head_id, MatMul);
    endfunction : set_linear_head_identity_requant

    function void set_linear_head0_identity_requant();
        set_linear_head_identity_requant(0);
    endfunction : set_linear_head0_identity_requant

    function void set_linear_all_heads_identity_requant();
        for (int unsigned h = 0; h < 8; h++) begin
            set_linear_head_identity_requant(h);
        end
    endfunction : set_linear_all_heads_identity_requant

endclass : ita_ctrl_item

`endif // ITA_CTRL_ITEM_SVH

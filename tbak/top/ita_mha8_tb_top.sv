module ita_mha8_tb_top;
    import uvm_pkg::*;
    import ita_package::*;
    import ita_ctrl_agent_pkg::*;
    import ita_stream_agent_pkg::*;
    import ita_mha8_common_pkg::*;
    import ita_mha8_env_pkg::*;
    import ita_mha8_test_pkg::*;
    `include "uvm_macros.svh"

    logic clk;

    ita_mha8_if #(
        .NumHeads(8)
    ) vif (
        .clk_i(clk)
    );

    ita_mha8 #(
        .NumHeads(8)
    ) dut (
        .clk_i                (vif.clk_i),
        .rst_ni               (vif.rst_ni),
        .ctrl_i               (vif.ctrl_i),
        .head_eps_mult_i      (vif.head_eps_mult_i),
        .head_right_shift_i   (vif.head_right_shift_i),
        .head_add_i           (vif.head_add_i),
        .sum_eps_mult_i       (vif.sum_eps_mult_i),
        .sum_right_shift_i    (vif.sum_right_shift_i),
        .sum_add_i            (vif.sum_add_i),
        .inp_valid_i          (vif.inp_valid_i),
        .inp_ready_o          (vif.inp_ready_o),
        .inp_weight_valid_i   (vif.inp_weight_valid_i),
        .inp_weight_ready_o   (vif.inp_weight_ready_o),
        .inp_bias_valid_i     (vif.inp_bias_valid_i),
        .inp_bias_ready_o     (vif.inp_bias_ready_o),
        .inp_i                (vif.inp_i),
        .inp_weight_i         (vif.inp_weight_i),
        .inp_bias_i           (vif.inp_bias_i),
        .per_head_valid_o     (vif.per_head_valid_o),
        .per_head_ready_i     (vif.per_head_ready_i),
        .per_head_busy_o      (vif.per_head_busy_o),
        .per_head_oup_o       (vif.per_head_oup_o),
        .per_head_step_o      (vif.per_head_step_o),
        .per_head_tile_id_dbg_o(vif.per_head_tile_id_dbg),
        .per_head_inner_id_dbg_o(vif.per_head_inner_id_dbg),
        .per_head_beat_id_dbg_o(vif.per_head_beat_id_dbg),
        .sum_valid_o          (vif.sum_valid_o),
        .sum_ready_i          (vif.sum_ready_i),
        .sum_oup_o            (vif.sum_oup_o),
        .sum_tile_id_dbg_o    (vif.sum_tile_id_dbg),
        .sum_inner_id_dbg_o   (vif.sum_inner_id_dbg),
        .sum_beat_id_dbg_o    (vif.sum_beat_id_dbg),
        .ff_inp_valid_i       (vif.ff_inp_valid_i),
        .ff_inp_ready_o       (vif.ff_inp_ready_o),
        .ff_inp_weight_valid_i(vif.ff_inp_weight_valid_i),
        .ff_inp_weight_ready_o(vif.ff_inp_weight_ready_o),
        .ff_inp_bias_valid_i  (vif.ff_inp_bias_valid_i),
        .ff_inp_bias_ready_o  (vif.ff_inp_bias_ready_o),
        .ff_inp_i             (vif.ff_inp_i),
        .ff_inp_weight_i      (vif.ff_inp_weight_i),
        .ff_inp_bias_i        (vif.ff_inp_bias_i),
        .ff_valid_o           (vif.ff_valid_o),
        .ff_ready_i           (vif.ff_ready_i),
        .ff_busy_o            (vif.ff_busy_o),
        .ff_oup_o             (vif.ff_oup_o),
        .ff_step_o            (vif.ff_step_o),
        .ff_tile_id_dbg_o     (vif.ff_tile_id_dbg),
        .ff_inner_id_dbg_o    (vif.ff_inner_id_dbg),
        .ff_beat_id_dbg_o     (vif.ff_beat_id_dbg),
        .phase_mismatch_o     (vif.phase_mismatch_o)
    );

    assign vif.per_head_ready_dbg = dut.head_ready;

    initial begin
        clk = 1'b0;
        forever begin
            #5ns clk = ~clk;
        end
    end

    initial begin
        vif.rst_ni = 1'b0;
        repeat (8) begin
            @(posedge clk);
        end
        vif.rst_ni = 1'b1;
    end

    initial begin
        uvm_config_db#(virtual ita_mha8_if)::set(null, "uvm_test_top", "vif", vif);
        run_test();
    end

endmodule : ita_mha8_tb_top

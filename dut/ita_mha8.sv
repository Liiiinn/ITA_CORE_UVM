// Copyright 2026
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

/**
    Native parallel 8-head ITA core wrapper.

    This module keeps the existing `ita` block as a single-head tile engine and
    instantiates one independent engine per head. The control word is broadcast;
    data streams remain per-head so a verification environment can drive and
    observe each head independently.
*/

module ita_mha8
    import ita_package::*;
#(
    parameter int unsigned NumHeads = 8
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    input  ctrl_t                   ctrl_i,
    input  requant_const_array_t    head_eps_mult_i    [NumHeads],
    input  requant_const_array_t    head_right_shift_i [NumHeads],
    input  requant_array_t          head_add_i         [NumHeads],
    input  requant_const_t          sum_eps_mult_i,
    input  requant_const_t          sum_right_shift_i,
    input  requant_t                sum_add_i,

    input  logic [NumHeads-1:0]     inp_valid_i,
    output logic [NumHeads-1:0]     inp_ready_o,
    input  logic [NumHeads-1:0]     inp_weight_valid_i,
    output logic [NumHeads-1:0]     inp_weight_ready_o,
    input  logic [NumHeads-1:0]     inp_bias_valid_i,
    output logic [NumHeads-1:0]     inp_bias_ready_o,

    input  inp_t                    inp_i        [NumHeads],
    input  inp_weight_t             inp_weight_i [NumHeads],
    input  bias_t                   inp_bias_i   [NumHeads],

    output logic [NumHeads-1:0]     per_head_valid_o,
    input  logic [NumHeads-1:0]     per_head_ready_i,
    output logic [NumHeads-1:0]     per_head_busy_o,
    output requant_oup_t            per_head_oup_o  [NumHeads],
    output step_e                   per_head_step_o [NumHeads],
    output counter_t                per_head_tile_id_dbg_o  [NumHeads],
    output counter_t                per_head_inner_id_dbg_o [NumHeads],
    output counter_t                per_head_beat_id_dbg_o  [NumHeads],

    output logic                    sum_valid_o,
    input  logic                    sum_ready_i,
    output requant_oup_t            sum_oup_o,
    output counter_t                sum_tile_id_dbg_o,
    output counter_t                sum_inner_id_dbg_o,
    output counter_t                sum_beat_id_dbg_o,
    input  logic                    ff_inp_valid_i,
    output logic                    ff_inp_ready_o,
    input  logic                    ff_inp_weight_valid_i,
    output logic                    ff_inp_weight_ready_o,
    input  logic                    ff_inp_bias_valid_i,
    output logic                    ff_inp_bias_ready_o,
    input  inp_t                    ff_inp_i,
    input  inp_weight_t             ff_inp_weight_i,
    input  bias_t                   ff_inp_bias_i,
    output logic                    ff_valid_o,
    input  logic                    ff_ready_i,
    output logic                    ff_busy_o,
    output requant_oup_t            ff_oup_o,
    output step_e                   ff_step_o,
    output counter_t                ff_tile_id_dbg_o,
    output counter_t                ff_inner_id_dbg_o,
    output counter_t                ff_beat_id_dbg_o,
    output logic                    phase_mismatch_o
);

    logic [NumHeads-1:0]  head_ready;
    logic                 all_head_valid;
    logic                 all_head_ow;
    logic                 all_per_head_ready;
    logic                 sum_ready;
    logic                 sum_valid;
    logic                 sum_valid_to_sum;
    ctrl_t                head_ctrl [NumHeads];
    ctrl_t                ff_ctrl;

    assign all_head_valid = &per_head_valid_o;
    assign all_per_head_ready = &per_head_ready_i;

    always_comb begin
        for (int unsigned h = 0; h < NumHeads; h++) begin
            head_ctrl[h]             = ctrl_i;
            head_ctrl[h].start       = ctrl_i.start && (ctrl_i.layer != Feedforward);
            head_ctrl[h].eps_mult    = head_eps_mult_i[h];
            head_ctrl[h].right_shift = head_right_shift_i[h];
            head_ctrl[h].add         = head_add_i[h];
        end
        ff_ctrl       = ctrl_i;
        ff_ctrl.start = ctrl_i.start && (ctrl_i.layer == Feedforward);
    end

    always_comb begin
        phase_mismatch_o = 1'b0;
        all_head_ow      = all_head_valid;

        for (int unsigned h = 0; h < NumHeads; h++) begin
            if (per_head_valid_o[h] && per_head_step_o[h] != OW) begin
                all_head_ow = 1'b0;
            end
            if (all_head_valid && per_head_step_o[h] != per_head_step_o[0]) begin
                phase_mismatch_o = 1'b1;
            end
        end
    end

    assign sum_valid = all_head_valid && all_head_ow && !phase_mismatch_o;
    assign sum_valid_to_sum = sum_valid && all_per_head_ready;

    always_comb begin
        for (int unsigned h = 0; h < NumHeads; h++) begin
            if (per_head_valid_o[h] && per_head_step_o[h] == OW) begin
                head_ready[h] = sum_valid_to_sum && sum_ready;
            end else begin
                head_ready[h] = per_head_ready_i[h];
            end

            if (phase_mismatch_o) begin
                head_ready[h] = 1'b0;
            end
        end
    end

    for (genvar h = 0; h < NumHeads; h++) begin : gen_head
        ita i_ita_head (
            .clk_i             (clk_i                 ),
            .rst_ni            (rst_ni                ),
            .ctrl_i            (head_ctrl[h]          ),
            .inp_valid_i       (inp_valid_i[h]        ),
            .inp_ready_o       (inp_ready_o[h]        ),
            .inp_weight_valid_i(inp_weight_valid_i[h] ),
            .inp_weight_ready_o(inp_weight_ready_o[h] ),
            .inp_bias_valid_i  (inp_bias_valid_i[h]   ),
            .inp_bias_ready_o  (inp_bias_ready_o[h]   ),
            .valid_o           (per_head_valid_o[h]   ),
            .ready_i           (head_ready[h]         ),
            .busy_o            (per_head_busy_o[h]    ),
            .inp_i             (inp_i[h]              ),
            .inp_weight_i      (inp_weight_i[h]       ),
            .inp_bias_i        (inp_bias_i[h]         ),
            .oup_o             (per_head_oup_o[h]     ),
            .oup_step_o        (per_head_step_o[h]    ),
            .oup_tile_id_dbg_o (per_head_tile_id_dbg_o[h] ),
            .oup_inner_id_dbg_o(per_head_inner_id_dbg_o[h]),
            .oup_beat_id_dbg_o (per_head_beat_id_dbg_o[h] )
        );
    end

    ita_head_sum #(
        .NumHeads(NumHeads)
    ) i_head_sum (
        .clk_i        (clk_i               ),
        .rst_ni       (rst_ni              ),
        .valid_i      (sum_valid_to_sum    ),
        .ready_o      (sum_ready           ),
        .head_oup_i   (per_head_oup_o      ),
        .eps_mult_i   (sum_eps_mult_i      ),
        .right_shift_i(sum_right_shift_i   ),
        .add_i        (sum_add_i           ),
        .tile_id_dbg_i(per_head_tile_id_dbg_o[0] ),
        .inner_id_dbg_i(per_head_inner_id_dbg_o[0]),
        .beat_id_dbg_i(per_head_beat_id_dbg_o[0] ),
        .valid_o      (sum_valid_o         ),
        .ready_i      (sum_ready_i         ),
        .oup_o        (sum_oup_o           ),
        .tile_id_dbg_o(sum_tile_id_dbg_o   ),
        .inner_id_dbg_o(sum_inner_id_dbg_o ),
        .beat_id_dbg_o(sum_beat_id_dbg_o   )
    );

    ita i_ffn (
        .clk_i             (clk_i                 ),
        .rst_ni            (rst_ni                ),
        .ctrl_i            (ff_ctrl               ),
        .inp_valid_i       (ff_inp_valid_i        ),
        .inp_ready_o       (ff_inp_ready_o        ),
        .inp_weight_valid_i(ff_inp_weight_valid_i ),
        .inp_weight_ready_o(ff_inp_weight_ready_o ),
        .inp_bias_valid_i  (ff_inp_bias_valid_i   ),
        .inp_bias_ready_o  (ff_inp_bias_ready_o   ),
        .valid_o           (ff_valid_o            ),
        .ready_i           (ff_ready_i            ),
        .busy_o            (ff_busy_o             ),
        .inp_i             (ff_inp_i              ),
        .inp_weight_i      (ff_inp_weight_i       ),
        .inp_bias_i        (ff_inp_bias_i         ),
        .oup_o             (ff_oup_o              ),
        .oup_step_o        (ff_step_o             ),
        .oup_tile_id_dbg_o (ff_tile_id_dbg_o      ),
        .oup_inner_id_dbg_o(ff_inner_id_dbg_o     ),
        .oup_beat_id_dbg_o (ff_beat_id_dbg_o      )
    );

    // pragma translate_off
    always_ff @(posedge clk_i) begin
        if (rst_ni && phase_mismatch_o) begin
            $error("[ITA_MHA8] Per-head output phase mismatch detected.");
        end
    end
    // pragma translate_on

endmodule

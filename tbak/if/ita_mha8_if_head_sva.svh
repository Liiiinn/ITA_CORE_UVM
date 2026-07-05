`ifndef ITA_MHA8_IF_HEAD_SVA_SVH
`define ITA_MHA8_IF_HEAD_SVA_SVH

generate
    for (genvar h = 0; h < NumHeads; h ++) begin : gen_head_assertion
    
        property stream_ctrl_known;
            @(posedge clk_i) disable iff (!rst_ni)
                !$isunknown({
                    inp_valid_i[h],
                    inp_weight_valid_i[h],
                    inp_bias_valid_i[h],
                    per_head_ready_i[h]
                });
        endproperty : stream_ctrl_known

        property inp_ready_known_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_valid_i[h] |-> !$isunknown(inp_ready_o[h]);
        endproperty : inp_ready_known_when_valid

        property weight_ready_known_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_weight_valid_i[h] |-> !$isunknown(inp_weight_ready_o[h]);
        endproperty : weight_ready_known_when_valid

        property bias_ready_known_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_bias_valid_i[h] |-> !$isunknown(inp_bias_ready_o[h]);
        endproperty : bias_ready_known_when_valid

        property head_valid_known_when_ready;
            @(posedge clk_i) disable iff (!rst_ni)
                per_head_ready_i[h] && per_head_busy_o[h] |-> !$isunknown(per_head_valid_o[h]);
        endproperty : head_valid_known_when_ready

        property inp_payload_known_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_valid_i[h] |-> !$isunknown(inp_i[h]);
        endproperty : inp_payload_known_when_valid

        property weight_payload_known_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_weight_valid_i[h] |-> !$isunknown(inp_weight_i[h]);
        endproperty : weight_payload_known_when_valid

        property bias_payload_known_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_bias_valid_i[h] |-> !$isunknown(inp_bias_i[h]);
        endproperty : bias_payload_known_when_valid

        property head_output_known_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                per_head_valid_o[h] |-> !$isunknown(per_head_oup_o[h]) && !$isunknown(per_head_step_o[h]);
        endproperty : head_output_known_when_valid

        property inp_stable_until_ready;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_valid_i[h] && !inp_ready_o[h]
                |=> inp_valid_i[h] && $stable(inp_i[h]);
        endproperty : inp_stable_until_ready

        property weight_stable_until_ready;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_weight_valid_i[h] && !inp_weight_ready_o[h]
                |=> inp_weight_valid_i[h] && $stable(inp_weight_i[h]);
        endproperty : weight_stable_until_ready

        property bias_stable_until_ready;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_bias_valid_i[h] && !inp_bias_ready_o[h]
                |=> inp_bias_valid_i[h] && $stable(inp_bias_i[h]);
        endproperty : bias_stable_until_ready

        property head_output_stable_until_ready;
            @(posedge clk_i) disable iff (!rst_ni)
                per_head_valid_o[h] && !per_head_ready_i[h]
                |=> per_head_valid_o[h] && $stable(per_head_oup_o[h]) && $stable(per_head_step_o[h]);
        endproperty
        
        property inp_dbg_known_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_valid_i[h] |-> !$isunknown({
                    inp_step_dbg[h],
                    inp_tile_id_dbg[h],
                    inp_inner_id_dbg[h],
                    inp_beat_id_dbg[h],
                    inp_lockstep_dbg[h]
                });
        endproperty : inp_dbg_known_when_valid

        property weight_dbg_known_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_weight_valid_i[h] |-> !$isunknown({
                    inp_weight_step_dbg[h],
                    inp_weight_tile_id_dbg[h],
                    inp_weight_inner_id_dbg[h],
                    inp_weight_beat_id_dbg[h],
                    inp_weight_lockstep_dbg[h]
                });
        endproperty : weight_dbg_known_when_valid

        property bias_dbg_known_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_bias_valid_i[h] |-> !$isunknown({
                    inp_bias_step_dbg[h],
                    inp_bias_tile_id_dbg[h],
                    inp_bias_inner_id_dbg[h],
                    inp_bias_beat_id_dbg[h],
                    inp_bias_lockstep_dbg[h]
                });
        endproperty : bias_dbg_known_when_valid

        property head_output_dbg_known_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                per_head_valid_o[h] |-> !$isunknown({
                    per_head_oup_o[h],
                    per_head_step_o[h],
                    per_head_tile_id_dbg[h],
                    per_head_inner_id_dbg[h],
                    per_head_beat_id_dbg[h]
                });
        endproperty : head_output_dbg_known_when_valid

        property inp_dbg_stable_until_ready;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_valid_i[h] && !inp_ready_o[h]
                |=> inp_valid_i[h] && $stable({
                    inp_step_dbg[h],
                    inp_tile_id_dbg[h],
                    inp_inner_id_dbg[h],
                    inp_beat_id_dbg[h],
                    inp_lockstep_dbg[h]
                });
        endproperty : inp_dbg_stable_until_ready

        property weight_dbg_stable_until_ready;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_weight_valid_i[h] && !inp_weight_ready_o[h]
                |=> inp_weight_valid_i[h] && $stable({
                    inp_weight_step_dbg[h],
                    inp_weight_tile_id_dbg[h],
                    inp_weight_inner_id_dbg[h],
                    inp_weight_beat_id_dbg[h],
                    inp_weight_lockstep_dbg[h]
                });
        endproperty : weight_dbg_stable_until_ready

        property bias_dbg_stable_until_ready;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_bias_valid_i[h] && !inp_bias_ready_o[h]
                |=> inp_bias_valid_i[h] && $stable({
                    inp_bias_step_dbg[h],
                    inp_bias_tile_id_dbg[h],
                    inp_bias_inner_id_dbg[h],
                    inp_bias_beat_id_dbg[h],
                    inp_bias_lockstep_dbg[h]
                });
        endproperty : bias_dbg_stable_until_ready

        property head_output_dbg_stable_until_ready;
            @(posedge clk_i) disable iff (!rst_ni)
                per_head_valid_o[h] && !per_head_ready_i[h]
                |=> per_head_valid_o[h] && $stable({
                    per_head_step_o[h],
                    per_head_tile_id_dbg[h],
                    per_head_inner_id_dbg[h],
                    per_head_beat_id_dbg[h]
                });
        endproperty : head_output_dbg_stable_until_ready

        property head_requant_known_when_ctrl_start;
            @(posedge clk_i) disable iff (!rst_ni)
                ctrl_i.start |-> !$isunknown({
                    head_eps_mult_i[h],
                    head_right_shift_i[h],
                    head_add_i[h]
                });
        endproperty : head_requant_known_when_ctrl_start

        property head_index_in_mha8_range;
            @(posedge clk_i) disable iff (!rst_ni)
                h < 8;
        endproperty : head_index_in_mha8_range

        property inp_step_legal_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_valid_i[h] |-> inp_step_dbg[h] inside {Q, K, V, QK, AV, OW, MatMul};
        endproperty : inp_step_legal_when_valid

        property weight_step_legal_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_weight_valid_i[h] |-> inp_weight_step_dbg[h] inside {Q, K, V, QK, AV, OW, MatMul};
        endproperty : weight_step_legal_when_valid

        property bias_step_legal_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_bias_valid_i[h] |-> inp_bias_step_dbg[h] inside {Q, K, V, QK, AV, OW, MatMul};
        endproperty : bias_step_legal_when_valid

        property head_legal_source_valid_lockstep_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                assert_legal_lockstep_input &&
                (inp_lockstep_dbg[h] || inp_weight_lockstep_dbg[h] || inp_bias_lockstep_dbg[h]) &&
                inp_valid_i[h] && inp_weight_valid_i[h] && inp_bias_valid_i[h];
        endproperty : head_legal_source_valid_lockstep_seen

        property head_output_step_legal_when_valid;
            @(posedge clk_i) disable iff (!rst_ni)
                per_head_valid_o[h] |-> per_head_step_o[h] inside {Q, K, V, QK, AV, OW, MatMul};
        endproperty : head_output_step_legal_when_valid

        property head_output_last_inner_legal;
            @(posedge clk_i) disable iff (!rst_ni)
                per_head_valid_o[h] && (per_head_step_o[h] inside {Q, K, V})
                |-> (sva_tile_e_q != 0 && per_head_inner_id_dbg[h] == sva_tile_e_q - 1);
        endproperty : head_output_last_inner_legal

        property head_ow_output_last_inner_legal;
            @(posedge clk_i) disable iff (!rst_ni)
                per_head_valid_o[h] && per_head_step_o[h] == OW
                |-> (sva_tile_p_q != 0 && per_head_inner_id_dbg[h] == sva_tile_p_q - 1);
        endproperty : head_ow_output_last_inner_legal

        property inp_no_stall_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_valid_i[h] && inp_ready_o[h];
        endproperty : inp_no_stall_seen

        property inp_backpressure_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_valid_i[h] && !inp_ready_o[h];
        endproperty : inp_backpressure_seen

        property inp_short_backpressure_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                (inp_valid_i[h] && !inp_ready_o[h]) ##1 (inp_valid_i[h] && inp_ready_o[h]);
        endproperty : inp_short_backpressure_seen

        property inp_long_backpressure_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                (inp_valid_i[h] && !inp_ready_o[h])[*4];
        endproperty : inp_long_backpressure_seen

        property weight_no_stall_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_weight_valid_i[h] && inp_weight_ready_o[h];
        endproperty : weight_no_stall_seen

        property weight_backpressure_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_weight_valid_i[h] && !inp_weight_ready_o[h];
        endproperty : weight_backpressure_seen

        property weight_short_backpressure_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                (inp_weight_valid_i[h] && !inp_weight_ready_o[h]) ##1 (inp_weight_valid_i[h] && inp_weight_ready_o[h]);
        endproperty : weight_short_backpressure_seen

        property weight_long_backpressure_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                (inp_weight_valid_i[h] && !inp_weight_ready_o[h])[*4];
        endproperty : weight_long_backpressure_seen

        property bias_no_stall_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_bias_valid_i[h] && inp_bias_ready_o[h];
        endproperty : bias_no_stall_seen

        property bias_backpressure_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                inp_bias_valid_i[h] && !inp_bias_ready_o[h];
        endproperty : bias_backpressure_seen

        property bias_short_backpressure_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                (inp_bias_valid_i[h] && !inp_bias_ready_o[h]) ##1 (inp_bias_valid_i[h] && inp_bias_ready_o[h]);
        endproperty : bias_short_backpressure_seen

        property bias_long_backpressure_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                (inp_bias_valid_i[h] && !inp_bias_ready_o[h])[*4];
        endproperty : bias_long_backpressure_seen

        property head_output_no_stall_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                per_head_valid_o[h] && per_head_ready_i[h];
        endproperty : head_output_no_stall_seen

        property head_output_backpressure_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                per_head_valid_o[h] && !per_head_ready_i[h];
        endproperty : head_output_backpressure_seen

        property head_output_short_backpressure_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                (per_head_valid_o[h] && !per_head_ready_i[h]) ##1 (per_head_valid_o[h] && per_head_ready_i[h]);
        endproperty : head_output_short_backpressure_seen

        property head_output_long_backpressure_seen;
            @(posedge clk_i) disable iff (!rst_ni)
                (per_head_valid_o[h] && !per_head_ready_i[h])[*4];
        endproperty : head_output_long_backpressure_seen

        inp_payload_known_when_valid_a: assert property(inp_payload_known_when_valid);
        weight_payload_known_when_valid_a: assert property(weight_payload_known_when_valid);
        bias_payload_known_when_valid_a: assert property(bias_payload_known_when_valid);
        head_output_known_when_valid_a: assert property(head_output_known_when_valid);
        stream_ctrl_known_a: assert property(stream_ctrl_known);
        inp_ready_known_when_valid_a: assert property(inp_ready_known_when_valid);
        weight_ready_known_when_valid_a: assert property(weight_ready_known_when_valid);
        bias_ready_known_when_valid_a: assert property(bias_ready_known_when_valid);
        head_valid_known_when_ready_a: assert property(head_valid_known_when_ready);
        inp_stable_until_a: assert property(inp_stable_until_ready);
        weight_stable_until_a: assert property(weight_stable_until_ready);
        bias_stable_until_a: assert property(bias_stable_until_ready);
        head_output_stable_until_ready_a: assert property(head_output_stable_until_ready);
        inp_dbg_known_when_valid_a: assert property(inp_dbg_known_when_valid);
        weight_dbg_known_when_valid_a: assert property(weight_dbg_known_when_valid);
        bias_dbg_known_when_valid_a: assert property(bias_dbg_known_when_valid);
        head_output_dbg_known_when_valid_a: assert property(head_output_dbg_known_when_valid);
        inp_dbg_stable_until_ready_a: assert property(inp_dbg_stable_until_ready);
        weight_dbg_stable_until_ready_a: assert property(weight_dbg_stable_until_ready);
        bias_dbg_stable_until_ready_a: assert property(bias_dbg_stable_until_ready);
        head_output_dbg_stable_until_ready_a: assert property(head_output_dbg_stable_until_ready);
        head_requant_known_when_ctrl_start_a: assert property(head_requant_known_when_ctrl_start);
        head_index_in_mha8_range_a: assert property(head_index_in_mha8_range);
        inp_step_legal_when_valid_a: assert property(inp_step_legal_when_valid);
        weight_step_legal_when_valid_a: assert property(weight_step_legal_when_valid);
        bias_step_legal_when_valid_a: assert property(bias_step_legal_when_valid);
        head_legal_source_valid_lockstep_seen_c: cover property(head_legal_source_valid_lockstep_seen);
        head_output_step_legal_when_valid_a: assert property(head_output_step_legal_when_valid);
        head_output_last_inner_legal_a: assert property(head_output_last_inner_legal);
        head_ow_output_last_inner_legal_a: assert property(head_ow_output_last_inner_legal);
        inp_no_stall_seen_c: cover property(inp_no_stall_seen);
        inp_backpressure_seen_c: cover property(inp_backpressure_seen);
        inp_short_backpressure_seen_c: cover property(inp_short_backpressure_seen);
        inp_long_backpressure_seen_c: cover property(inp_long_backpressure_seen);
        weight_no_stall_seen_c: cover property(weight_no_stall_seen);
        weight_backpressure_seen_c: cover property(weight_backpressure_seen);
        weight_short_backpressure_seen_c: cover property(weight_short_backpressure_seen);
        weight_long_backpressure_seen_c: cover property(weight_long_backpressure_seen);
        bias_no_stall_seen_c: cover property(bias_no_stall_seen);
        bias_backpressure_seen_c: cover property(bias_backpressure_seen);
        bias_short_backpressure_seen_c: cover property(bias_short_backpressure_seen);
        bias_long_backpressure_seen_c: cover property(bias_long_backpressure_seen);
        head_output_no_stall_seen_c: cover property(head_output_no_stall_seen);
        head_output_backpressure_seen_c: cover property(head_output_backpressure_seen);
        head_output_short_backpressure_seen_c: cover property(head_output_short_backpressure_seen);
        head_output_long_backpressure_seen_c: cover property(head_output_long_backpressure_seen);
    end
endgenerate

`endif // ITA_MHA8_IF_HEAD_SVA_SVH

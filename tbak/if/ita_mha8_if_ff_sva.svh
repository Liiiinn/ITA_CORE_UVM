`ifndef ITA_MHA8_IF_FF_SVA_SVH
`define ITA_MHA8_IF_FF_SVA_SVH

property ff_stream_ctrl_known;
    @(posedge clk_i) disable iff (!rst_ni)
        !$isunknown({
            ff_inp_valid_i,
            ff_inp_weight_valid_i,
            ff_inp_bias_valid_i,
            ff_ready_i
        });
endproperty : ff_stream_ctrl_known

property ff_inp_ready_known_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_valid_i |-> !$isunknown(ff_inp_ready_o);
endproperty : ff_inp_ready_known_when_valid

property ff_weight_ready_known_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_weight_valid_i |-> !$isunknown(ff_inp_weight_ready_o);
endproperty : ff_weight_ready_known_when_valid

property ff_bias_ready_known_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_bias_valid_i |-> !$isunknown(ff_inp_bias_ready_o);
endproperty : ff_bias_ready_known_when_valid

property ff_valid_known_when_ready;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_ready_i && ff_busy_o |-> !$isunknown(ff_valid_o);
endproperty : ff_valid_known_when_ready

property ff_inp_payload_known_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_valid_i |-> !$isunknown(ff_inp_i);
endproperty : ff_inp_payload_known_when_valid

property ff_weight_payload_known_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_weight_valid_i |-> !$isunknown(ff_inp_weight_i);
endproperty : ff_weight_payload_known_when_valid

property ff_bias_payload_known_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_bias_valid_i |-> !$isunknown(ff_inp_bias_i);
endproperty : ff_bias_payload_known_when_valid

property ff_output_known_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_valid_o |-> !$isunknown({
            ff_oup_o,
            ff_step_o,
            ff_tile_id_dbg,
            ff_inner_id_dbg,
            ff_beat_id_dbg
        });
endproperty : ff_output_known_when_valid

property ff_inp_dbg_known_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_valid_i |-> !$isunknown({
            ff_inp_step_dbg,
            ff_inp_tile_id_dbg,
            ff_inp_inner_id_dbg,
            ff_inp_beat_id_dbg,
            ff_inp_lockstep_dbg
        });
endproperty : ff_inp_dbg_known_when_valid

property ff_weight_dbg_known_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_weight_valid_i |-> !$isunknown({
            ff_inp_weight_step_dbg,
            ff_inp_weight_tile_id_dbg,
            ff_inp_weight_inner_id_dbg,
            ff_inp_weight_beat_id_dbg,
            ff_inp_weight_lockstep_dbg
        });
endproperty : ff_weight_dbg_known_when_valid

property ff_bias_dbg_known_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_bias_valid_i |-> !$isunknown({
            ff_inp_bias_step_dbg,
            ff_inp_bias_tile_id_dbg,
            ff_inp_bias_inner_id_dbg,
            ff_inp_bias_beat_id_dbg,
            ff_inp_bias_lockstep_dbg
        });
endproperty : ff_bias_dbg_known_when_valid

property ff_inp_stable_until_ready;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_valid_i && !ff_inp_ready_o
        |=> ff_inp_valid_i && $stable(ff_inp_i);
endproperty : ff_inp_stable_until_ready

property ff_weight_stable_until_ready;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_weight_valid_i && !ff_inp_weight_ready_o
        |=> ff_inp_weight_valid_i && $stable(ff_inp_weight_i);
endproperty : ff_weight_stable_until_ready

property ff_bias_stable_until_ready;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_bias_valid_i && !ff_inp_bias_ready_o
        |=> ff_inp_bias_valid_i && $stable(ff_inp_bias_i);
endproperty : ff_bias_stable_until_ready

property ff_output_stable_until_ready;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_valid_o && !ff_ready_i
        |=> ff_valid_o && $stable({
            ff_oup_o,
            ff_step_o,
            ff_tile_id_dbg,
            ff_inner_id_dbg,
            ff_beat_id_dbg
        });
endproperty : ff_output_stable_until_ready

property ff_inp_dbg_stable_until_ready;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_valid_i && !ff_inp_ready_o
        |=> ff_inp_valid_i && $stable({
            ff_inp_step_dbg,
            ff_inp_tile_id_dbg,
            ff_inp_inner_id_dbg,
            ff_inp_beat_id_dbg,
            ff_inp_lockstep_dbg
        });
endproperty : ff_inp_dbg_stable_until_ready

property ff_weight_dbg_stable_until_ready;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_weight_valid_i && !ff_inp_weight_ready_o
        |=> ff_inp_weight_valid_i && $stable({
            ff_inp_weight_step_dbg,
            ff_inp_weight_tile_id_dbg,
            ff_inp_weight_inner_id_dbg,
            ff_inp_weight_beat_id_dbg,
            ff_inp_weight_lockstep_dbg
        });
endproperty : ff_weight_dbg_stable_until_ready

property ff_bias_dbg_stable_until_ready;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_bias_valid_i && !ff_inp_bias_ready_o
        |=> ff_inp_bias_valid_i && $stable({
            ff_inp_bias_step_dbg,
            ff_inp_bias_tile_id_dbg,
            ff_inp_bias_inner_id_dbg,
            ff_inp_bias_beat_id_dbg,
            ff_inp_bias_lockstep_dbg
        });
endproperty : ff_bias_dbg_stable_until_ready

property ff_inp_step_legal_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_valid_i |-> ff_inp_step_dbg inside {F1, F2};
endproperty : ff_inp_step_legal_when_valid

property ff_weight_step_legal_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_weight_valid_i |-> ff_inp_weight_step_dbg inside {F1, F2};
endproperty : ff_weight_step_legal_when_valid

property ff_bias_step_legal_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_bias_valid_i |-> ff_inp_bias_step_dbg inside {F1, F2};
endproperty : ff_bias_step_legal_when_valid

property ff_output_step_legal_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_valid_o |-> ff_step_o inside {F1, F2};
endproperty : ff_output_step_legal_when_valid

property ff_f1_output_last_inner_legal;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_valid_o && ff_step_o == F1
        |-> (sva_tile_e_q != 0 && ff_inner_id_dbg == sva_tile_e_q - 1);
endproperty : ff_f1_output_last_inner_legal

property ff_f2_output_last_inner_legal;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_valid_o && ff_step_o == F2
        |-> (sva_tile_f_q != 0 && ff_inner_id_dbg == sva_tile_f_q - 1);
endproperty : ff_f2_output_last_inner_legal

property ff_inp_no_stall_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_valid_i && ff_inp_ready_o;
endproperty : ff_inp_no_stall_seen

property ff_inp_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_valid_i && !ff_inp_ready_o;
endproperty : ff_inp_backpressure_seen

property ff_inp_short_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        (ff_inp_valid_i && !ff_inp_ready_o) ##1 (ff_inp_valid_i && ff_inp_ready_o);
endproperty : ff_inp_short_backpressure_seen

property ff_inp_long_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        (ff_inp_valid_i && !ff_inp_ready_o)[*4];
endproperty : ff_inp_long_backpressure_seen

property ff_weight_no_stall_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_weight_valid_i && ff_inp_weight_ready_o;
endproperty : ff_weight_no_stall_seen

property ff_weight_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_weight_valid_i && !ff_inp_weight_ready_o;
endproperty : ff_weight_backpressure_seen

property ff_weight_short_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        (ff_inp_weight_valid_i && !ff_inp_weight_ready_o) ##1 (ff_inp_weight_valid_i && ff_inp_weight_ready_o);
endproperty : ff_weight_short_backpressure_seen

property ff_weight_long_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        (ff_inp_weight_valid_i && !ff_inp_weight_ready_o)[*4];
endproperty : ff_weight_long_backpressure_seen

property ff_bias_no_stall_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_bias_valid_i && ff_inp_bias_ready_o;
endproperty : ff_bias_no_stall_seen

property ff_bias_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_inp_bias_valid_i && !ff_inp_bias_ready_o;
endproperty : ff_bias_backpressure_seen

property ff_bias_short_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        (ff_inp_bias_valid_i && !ff_inp_bias_ready_o) ##1 (ff_inp_bias_valid_i && ff_inp_bias_ready_o);
endproperty : ff_bias_short_backpressure_seen

property ff_bias_long_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        (ff_inp_bias_valid_i && !ff_inp_bias_ready_o)[*4];
endproperty : ff_bias_long_backpressure_seen

property ff_output_no_stall_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_valid_o && ff_ready_i;
endproperty : ff_output_no_stall_seen

property ff_output_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        ff_valid_o && !ff_ready_i;
endproperty : ff_output_backpressure_seen

property ff_output_short_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        (ff_valid_o && !ff_ready_i) ##1 (ff_valid_o && ff_ready_i);
endproperty : ff_output_short_backpressure_seen

property ff_output_long_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        (ff_valid_o && !ff_ready_i)[*4];
endproperty : ff_output_long_backpressure_seen

ff_stream_ctrl_known_a: assert property(ff_stream_ctrl_known);
ff_inp_ready_known_when_valid_a: assert property(ff_inp_ready_known_when_valid);
ff_weight_ready_known_when_valid_a: assert property(ff_weight_ready_known_when_valid);
ff_bias_ready_known_when_valid_a: assert property(ff_bias_ready_known_when_valid);
ff_valid_known_when_ready_a: assert property(ff_valid_known_when_ready);
ff_inp_payload_known_when_valid_a: assert property(ff_inp_payload_known_when_valid);
ff_weight_payload_known_when_valid_a: assert property(ff_weight_payload_known_when_valid);
ff_bias_payload_known_when_valid_a: assert property(ff_bias_payload_known_when_valid);
ff_output_known_when_valid_a: assert property(ff_output_known_when_valid);
ff_inp_dbg_known_when_valid_a: assert property(ff_inp_dbg_known_when_valid);
ff_weight_dbg_known_when_valid_a: assert property(ff_weight_dbg_known_when_valid);
ff_bias_dbg_known_when_valid_a: assert property(ff_bias_dbg_known_when_valid);
ff_inp_stable_until_ready_a: assert property(ff_inp_stable_until_ready);
ff_weight_stable_until_ready_a: assert property(ff_weight_stable_until_ready);
ff_bias_stable_until_ready_a: assert property(ff_bias_stable_until_ready);
ff_output_stable_until_ready_a: assert property(ff_output_stable_until_ready);
ff_inp_dbg_stable_until_ready_a: assert property(ff_inp_dbg_stable_until_ready);
ff_weight_dbg_stable_until_ready_a: assert property(ff_weight_dbg_stable_until_ready);
ff_bias_dbg_stable_until_ready_a: assert property(ff_bias_dbg_stable_until_ready);
ff_inp_step_legal_when_valid_a: assert property(ff_inp_step_legal_when_valid);
ff_weight_step_legal_when_valid_a: assert property(ff_weight_step_legal_when_valid);
ff_bias_step_legal_when_valid_a: assert property(ff_bias_step_legal_when_valid);
ff_output_step_legal_when_valid_a: assert property(ff_output_step_legal_when_valid);
ff_f1_output_last_inner_legal_a: assert property(ff_f1_output_last_inner_legal);
ff_f2_output_last_inner_legal_a: assert property(ff_f2_output_last_inner_legal);
ff_inp_no_stall_seen_c: cover property(ff_inp_no_stall_seen);
ff_inp_backpressure_seen_c: cover property(ff_inp_backpressure_seen);
ff_inp_short_backpressure_seen_c: cover property(ff_inp_short_backpressure_seen);
ff_inp_long_backpressure_seen_c: cover property(ff_inp_long_backpressure_seen);
ff_weight_no_stall_seen_c: cover property(ff_weight_no_stall_seen);
ff_weight_backpressure_seen_c: cover property(ff_weight_backpressure_seen);
ff_weight_short_backpressure_seen_c: cover property(ff_weight_short_backpressure_seen);
ff_weight_long_backpressure_seen_c: cover property(ff_weight_long_backpressure_seen);
ff_bias_no_stall_seen_c: cover property(ff_bias_no_stall_seen);
ff_bias_backpressure_seen_c: cover property(ff_bias_backpressure_seen);
ff_bias_short_backpressure_seen_c: cover property(ff_bias_short_backpressure_seen);
ff_bias_long_backpressure_seen_c: cover property(ff_bias_long_backpressure_seen);
ff_output_no_stall_seen_c: cover property(ff_output_no_stall_seen);
ff_output_backpressure_seen_c: cover property(ff_output_backpressure_seen);
ff_output_short_backpressure_seen_c: cover property(ff_output_short_backpressure_seen);
ff_output_long_backpressure_seen_c: cover property(ff_output_long_backpressure_seen);

`endif // ITA_MHA8_IF_FF_SVA_SVH
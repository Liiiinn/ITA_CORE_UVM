`ifndef ITA_MHA8_IF_SUM_SVA_SVH
`define ITA_MHA8_IF_SUM_SVA_SVH

property sum_ctrl_known;
    @(posedge clk_i) disable iff (!rst_ni)
        !$isunknown(sum_ready_i);
endproperty : sum_ctrl_known

property sum_valid_known_when_ready;
    @(posedge clk_i) disable iff (!rst_ni)
        sum_ready_i && sva_tile_s_q != 0 |-> !$isunknown(sum_valid_o);
endproperty : sum_valid_known_when_ready

property sum_output_known_when_valid;
    @(posedge clk_i) disable iff (!rst_ni)
        sum_valid_o |-> !$isunknown({
            sum_oup_o,
            sum_tile_id_dbg,
            sum_inner_id_dbg,
            sum_beat_id_dbg
        });
endproperty : sum_output_known_when_valid

property sum_output_stable_until_ready;
    @(posedge clk_i) disable iff (!rst_ni)
        sum_valid_o && !sum_ready_i
        |=> sum_valid_o && $stable({
            sum_oup_o,
            sum_tile_id_dbg,
            sum_inner_id_dbg,
            sum_beat_id_dbg
        });
endproperty : sum_output_stable_until_ready

property sum_output_last_inner_legal;
    @(posedge clk_i) disable iff (!rst_ni)
        sum_valid_o |-> (sva_tile_p_q != 0 && sum_inner_id_dbg == sva_tile_p_q - 1);
endproperty : sum_output_last_inner_legal

property sum_no_stall_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        sum_valid_o && sum_ready_i;
endproperty : sum_no_stall_seen

property sum_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        sum_valid_o && !sum_ready_i;
endproperty : sum_backpressure_seen

property sum_short_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        (sum_valid_o && !sum_ready_i) ##1 (sum_valid_o && sum_ready_i);
endproperty : sum_short_backpressure_seen

property sum_long_backpressure_seen;
    @(posedge clk_i) disable iff (!rst_ni)
        (sum_valid_o && !sum_ready_i)[*4];
endproperty : sum_long_backpressure_seen

sum_ctrl_known_a: assert property(sum_ctrl_known);
sum_valid_known_when_ready_a: assert property(sum_valid_known_when_ready);
sum_output_known_when_valid_a: assert property(sum_output_known_when_valid);
sum_output_stable_until_ready_a: assert property(sum_output_stable_until_ready);
sum_output_last_inner_legal_a: assert property(sum_output_last_inner_legal);
sum_no_stall_seen_c: cover property(sum_no_stall_seen);
sum_backpressure_seen_c: cover property(sum_backpressure_seen);
sum_short_backpressure_seen_c: cover property(sum_short_backpressure_seen);
sum_long_backpressure_seen_c: cover property(sum_long_backpressure_seen);

`endif // ITA_MHA8_IF_SUM_SVA_SVH
interface ita_mha8_if
    import ita_package::*;
#(
    parameter int unsigned NumHeads = 8
) (
    input logic clk_i
);

    logic                    rst_ni;
    ctrl_t                   ctrl_i;
    // Stage 8: add ctrl_i.start X/Z and one-cycle pulse assertions after ctrl_driver implements the pulse.

    requant_const_array_t    head_eps_mult_i    [NumHeads];
    requant_const_array_t    head_right_shift_i [NumHeads];
    requant_array_t          head_add_i         [NumHeads];
    requant_const_t          sum_eps_mult_i;
    requant_const_t          sum_right_shift_i;
    requant_t                sum_add_i;
    // TODO Stage 8: add head0 requant X/Z assertions while ctrl_i.start is asserted.

    logic [NumHeads-1:0]     inp_valid_i;
    logic [NumHeads-1:0]     inp_ready_o;
    logic [NumHeads-1:0]     inp_weight_valid_i;
    logic [NumHeads-1:0]     inp_weight_ready_o;
    logic [NumHeads-1:0]     inp_bias_valid_i;
    logic [NumHeads-1:0]     inp_bias_ready_o;
    // Stage 8: add valid-ready stability assertions for head0 input/weight/bias streams.

    inp_t                    inp_i        [NumHeads];
    inp_weight_t             inp_weight_i [NumHeads];
    bias_t                   inp_bias_i   [NumHeads];
    // Stage 8: add head0 payload stability assertions while valid is high and ready is low.

    step_e                   inp_step_dbg           [NumHeads];
    step_e                   inp_weight_step_dbg    [NumHeads];
    step_e                   inp_bias_step_dbg      [NumHeads];
    int unsigned             inp_tile_id_dbg        [NumHeads];
    int unsigned             inp_weight_tile_id_dbg [NumHeads];
    int unsigned             inp_bias_tile_id_dbg   [NumHeads];
    int unsigned             inp_inner_id_dbg       [NumHeads];
    int unsigned             inp_weight_inner_id_dbg[NumHeads];
    int unsigned             inp_bias_inner_id_dbg  [NumHeads];
    int unsigned             inp_beat_id_dbg        [NumHeads];
    int unsigned             inp_weight_beat_id_dbg [NumHeads];
    int unsigned             inp_bias_beat_id_dbg   [NumHeads];
    logic                    inp_lockstep_dbg       [NumHeads];
    logic                    inp_weight_lockstep_dbg[NumHeads];
    logic                    inp_bias_lockstep_dbg  [NumHeads];
    // TODO Stage 7-8: consume debug metadata in logger/scoreboard after monitor sampling is implemented.

    logic [NumHeads-1:0]     per_head_valid_o;
    logic [NumHeads-1:0]     per_head_ready_i;
    logic [NumHeads-1:0]     per_head_busy_o;
    requant_oup_t            per_head_oup_o  [NumHeads];
    step_e                   per_head_step_o [NumHeads];
    counter_t                per_head_tile_id_dbg  [NumHeads];
    counter_t                per_head_inner_id_dbg [NumHeads];
    counter_t                per_head_beat_id_dbg  [NumHeads];
    // Stage 8: add head0 output backpressure stability assertion after output ready driving exists.

    logic                    sum_valid_o;
    logic                    sum_ready_i;
    requant_oup_t            sum_oup_o;
    counter_t                sum_tile_id_dbg;
    counter_t                sum_inner_id_dbg;
    counter_t                sum_beat_id_dbg;
    // Stage 11: add sum output assertions and monitor hooks after heads 0-7 are enabled.

    logic                    ff_inp_valid_i;
    logic                    ff_inp_ready_o;
    logic                    ff_inp_weight_valid_i;
    logic                    ff_inp_weight_ready_o;
    logic                    ff_inp_bias_valid_i;
    logic                    ff_inp_bias_ready_o;
    inp_t                    ff_inp_i;
    inp_weight_t             ff_inp_weight_i;
    bias_t                   ff_inp_bias_i;
    step_e                   ff_inp_step_dbg;
    step_e                   ff_inp_weight_step_dbg;
    step_e                   ff_inp_bias_step_dbg;
    int unsigned             ff_inp_tile_id_dbg;
    int unsigned             ff_inp_weight_tile_id_dbg;
    int unsigned             ff_inp_bias_tile_id_dbg;
    int unsigned             ff_inp_inner_id_dbg;
    int unsigned             ff_inp_weight_inner_id_dbg;
    int unsigned             ff_inp_bias_inner_id_dbg;
    int unsigned             ff_inp_beat_id_dbg;
    int unsigned             ff_inp_weight_beat_id_dbg;
    int unsigned             ff_inp_bias_beat_id_dbg;
    logic                    ff_inp_lockstep_dbg;
    logic                    ff_inp_weight_lockstep_dbg;
    logic                    ff_inp_bias_lockstep_dbg;

    logic                    ff_valid_o;
    logic                    ff_ready_i;
    logic                    ff_busy_o;
    requant_oup_t            ff_oup_o;
    step_e                   ff_step_o;
    counter_t                ff_tile_id_dbg;
    counter_t                ff_inner_id_dbg;
    counter_t                ff_beat_id_dbg;
    logic                    phase_mismatch_o;
    // Stage 11: add feed-forward stream assertions after the FF path is added to active tests.

    tile_t                   sva_tile_s_q;
    tile_t                   sva_tile_e_q;
    tile_t                   sva_tile_p_q;
    tile_t                   sva_tile_f_q;

    // TODO S13_ONLINE_SVA: expand protocol assertions for all head/FF/sum streams.
    // TODO S13_ONLINE_SVA: assert valid && !ready keeps valid high and payload/debug metadata stable.
    // TODO S13_ONLINE_SVA: assert ctrl_i.start, layer, activation, tile fields, requant fields, and payloads are never X/Z when active.
    // TODO S13_ONLINE_SVA: assert reset leaves driver-owned pins, ready signals, and debug metadata in legal idle states.
    // TODO S13_ONLINE_SVA: assert ctrl start/done/active-window timing once job lifecycle signals are exposed.
    // TODO S13_ONLINE_COV: add assertion/cover hooks for no-stall, short-stall, long-stall, and valid && !ready backpressure cases.

    // TODO ·: initialize or tie off driver-owned pins needed for an idle smoke shell.
    initial begin
        rst_ni = 0;
        ctrl_i = '0;
        sum_eps_mult_i = '0;
        sum_right_shift_i = '0;
        sum_add_i = '0;
        inp_valid_i = '0;
        inp_weight_valid_i = '0;
        inp_bias_valid_i = '0;
        per_head_ready_i = '0;
        sum_ready_i = '0;
        ff_ready_i = '0;

        for (int unsigned h = 0; h < NumHeads; h++) begin
            head_eps_mult_i[h]    = '0;
            head_right_shift_i[h] = '0;
            head_add_i[h]         = '0;
            inp_i[h]              = '0;
            inp_weight_i[h]       = '0;
            inp_bias_i[h]         = '0;
            inp_step_dbg[h]       = Idle;
            inp_weight_step_dbg[h] = Idle;
            inp_bias_step_dbg[h]  = Idle;
            inp_tile_id_dbg[h]    = 0;
            inp_weight_tile_id_dbg[h] = 0;
            inp_bias_tile_id_dbg[h] = 0;
            inp_inner_id_dbg[h]   = 0;
            inp_weight_inner_id_dbg[h] = 0;
            inp_bias_inner_id_dbg[h] = 0;
            inp_beat_id_dbg[h]    = 0;
            inp_weight_beat_id_dbg[h] = 0;
            inp_bias_beat_id_dbg[h] = 0;
            inp_lockstep_dbg[h]   = 1'b0;
            inp_weight_lockstep_dbg[h] = 1'b0;
            inp_bias_lockstep_dbg[h] = 1'b0;
        end

        ff_inp_valid_i = 0;
        ff_inp_weight_valid_i = 0;
        ff_inp_bias_valid_i = 0;
        ff_inp_i        = '0;
        ff_inp_weight_i = '0;
        ff_inp_bias_i   = '0;
        ff_inp_step_dbg = Idle;
        ff_inp_weight_step_dbg = Idle;
        ff_inp_bias_step_dbg = Idle;
        ff_inp_tile_id_dbg = 0;
        ff_inp_weight_tile_id_dbg = 0;
        ff_inp_bias_tile_id_dbg = 0;
        ff_inp_inner_id_dbg = 0;
        ff_inp_weight_inner_id_dbg = 0;
        ff_inp_bias_inner_id_dbg = 0;
        ff_inp_beat_id_dbg = 0;
        ff_inp_weight_beat_id_dbg = 0;
        ff_inp_bias_beat_id_dbg = 0;
        ff_inp_lockstep_dbg = 1'b0;
        ff_inp_weight_lockstep_dbg = 1'b0;
        ff_inp_bias_lockstep_dbg = 1'b0;
    end
    // Stage 8: implement early assertion blocks for X/Z, timeout, valid-ready, and backpressure.

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            sva_tile_s_q <= '0;
            sva_tile_e_q <= '0;
            sva_tile_p_q <= '0;
            sva_tile_f_q <= '0;
        end else if (ctrl_i.start && !$isunknown({
            ctrl_i.tile_s,
            ctrl_i.tile_e,
            ctrl_i.tile_p,
            ctrl_i.tile_f
        })) begin
            sva_tile_s_q <= ctrl_i.tile_s;
            sva_tile_e_q <= ctrl_i.tile_e;
            sva_tile_p_q <= ctrl_i.tile_p;
            sva_tile_f_q <= ctrl_i.tile_f;
        end
    end

    generate
        for (genvar h = 0; h < NumHeads; h ++) begin : gen_head_assertion
        
            property stream_ctrl_known;
                @(posedge clk_i) disable iff (!rst_ni)
                    !$isunknown({
                        inp_valid_i[h],
                        inp_ready_o[h],
                        inp_weight_valid_i[h],
                        inp_weight_ready_o[h],
                        inp_bias_valid_i[h],
                        inp_bias_ready_o[h],
                        per_head_valid_o[h],
                        per_head_ready_i[h]
                    });
            endproperty : stream_ctrl_known

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

            inp_payload_known_when_valid_a: assert property(inp_payload_known_when_valid);
            weight_payload_known_when_valid_a: assert property(weight_payload_known_when_valid);
            bias_payload_known_when_valid_a: assert property(bias_payload_known_when_valid);
            head_output_known_when_valid_a: assert property(head_output_known_when_valid);
            stream_ctrl_known_a: assert property(stream_ctrl_known);
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
            head_output_step_legal_when_valid_a: assert property(head_output_step_legal_when_valid);
            head_output_last_inner_legal_a: assert property(head_output_last_inner_legal);
            head_ow_output_last_inner_legal_a: assert property(head_ow_output_last_inner_legal);
        end
    endgenerate

    property sum_ctrl_known;
        @(posedge clk_i) disable iff (!rst_ni)
            !$isunknown({sum_valid_o, sum_ready_i});
    endproperty : sum_ctrl_known

    property sum_output_known_when_valid;
        @(posedge clk_i) disable iff (!rst_ni)
            sum_valid_o |-> !$isunknown({
                sum_oup_o,
                sum_step_dbg,
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
                sum_step_dbg,
                sum_tile_id_dbg,
                sum_inner_id_dbg,
                sum_beat_id_dbg
            });
    endproperty : sum_output_stable_until_ready

    property sum_output_last_inner_legal;
        @(posedge clk_i) disable iff (!rst_ni)
            sum_valid_o |-> (sva_tile_p_q != 0 && sum_inner_id_dbg == sva_tile_p_q - 1);
    endproperty : sum_output_last_inner_legal

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
            ff_ready_i |-> !$isunknown(ff_valid_o);
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

    property ctrl_start_known;
        @(posedge clk_i) disable iff (!rst_ni)
            !$isunknown(ctrl_i.start);
    endproperty : ctrl_start_known

    property ctrl_known;
        @(posedge clk_i) disable iff (!rst_ni)
            ctrl_i.start |-> !$isunknown({
                ctrl_i.layer,
                ctrl_i.activation,
                ctrl_i.tile_s,
                ctrl_i.tile_e,
                ctrl_i.tile_p,
                ctrl_i.tile_f
            });
    endproperty : ctrl_known

    property ctrl_requant_known;
        @(posedge clk_i) disable iff (!rst_ni)
            ctrl_i.start |-> !$isunknown({
                ctrl_i.eps_mult,
                ctrl_i.right_shift,
                ctrl_i.add,
                ctrl_i.activation_requant_mult,
                ctrl_i.activation_requant_shift,
                ctrl_i.activation_requant_add,
                sum_eps_mult_i,
                sum_right_shift_i,
                sum_add_i
            });
    endproperty : ctrl_requant_known

    property ctrl_tile_nonzero;
        @(posedge clk_i) disable iff (!rst_ni)
            ctrl_i.start |-> (
                ctrl_i.tile_s != 0 &&
                ctrl_i.tile_e != 0 &&
                ctrl_i.tile_p != 0 &&
                ctrl_i.tile_f != 0
            );
    endproperty : ctrl_tile_nonzero

    property ctrl_layer_legal;
        @(posedge clk_i) disable iff (!rst_ni)
            ctrl_i.start |-> ctrl_i.layer inside {Attention, Feedforward, Linear, SingleAttention};
    endproperty : ctrl_layer_legal

    property ctrl_activation_legal;
        @(posedge clk_i) disable iff (!rst_ni)
            ctrl_i.start |-> ctrl_i.activation inside {Identity, Gelu, Relu};
    endproperty : ctrl_activation_legal

    property ctrl_start_pulse;
        @(posedge clk_i) disable iff (!rst_ni)
            ctrl_i.start |=> !ctrl_i.start;
    endproperty : ctrl_start_pulse

    property driver_owned_idle_during_reset;
        @(posedge clk_i)
            !rst_ni |-> (
                inp_valid_i == '0 &&
                inp_weight_valid_i == '0 &&
                inp_bias_valid_i == '0 &&
                ff_inp_valid_i == 1'b0 &&
                ff_inp_weight_valid_i == 1'b0 &&
                ff_inp_bias_valid_i == 1'b0 &&
                !$isunknown({
                    per_head_ready_i,
                    sum_ready_i,
                    ff_ready_i
                })
            );
    endproperty : driver_owned_idle_during_reset

    sum_ctrl_known_a: assert property(sum_ctrl_known);
    sum_output_known_when_valid_a: assert property(sum_output_known_when_valid);
    sum_output_stable_until_ready_a: assert property(sum_output_stable_until_ready);
    sum_output_last_inner_legal_a: assert property(sum_output_last_inner_legal);

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

    ctrl_start_known_a: assert property(ctrl_start_known);
    ctrl_known_a: assert property(ctrl_known);
    ctrl_requant_known_a: assert property(ctrl_requant_known);
    ctrl_tile_nonzero_a: assert property(ctrl_tile_nonzero);
    ctrl_layer_legal_a: assert property(ctrl_layer_legal);
    ctrl_activation_legal_a: assert property(ctrl_activation_legal);
    ctrl_start_pulse_a: assert property(ctrl_start_pulse);
    driver_owned_idle_during_reset_a: assert property(driver_owned_idle_during_reset);

endinterface : ita_mha8_if

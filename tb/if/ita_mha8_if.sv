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
    logic [NumHeads-1:0]     per_head_ready_dbg;
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
    bit                      native_vr_violation_seen;
    // Stage 11: add feed-forward stream assertions after the FF path is added to active tests.

    tile_t                   sva_tile_s_q;
    tile_t                   sva_tile_e_q;
    tile_t                   sva_tile_p_q;
    tile_t                   sva_tile_f_q;

    // S13_ONLINE_SVA: expand protocol assertions for all head/FF/sum streams.
    // S13_ONLINE_SVA: assert valid && !ready keeps valid high and payload/debug metadata stable.
    // S13_ONLINE_SVA: assert ctrl_i.start, layer, activation, tile fields, requant fields, and payloads are never X/Z when active.
    // S13_ONLINE_SVA: assert reset leaves driver-owned pins, ready signals, and debug metadata in legal idle states.
    // S13_ONLINE_SVA: assert ctrl start/done/active-window timing once job lifecycle signals are exposed.
    // TODO S13_ONLINE_COV: add assertion/cover hooks for no-stall, short-stall, long-stall, and valid && !ready backpressure cases.

    // TODO ·: initialize or tie off driver-owned pins needed for an idle smoke shell.
    initial begin
        rst_ni = 0;
        native_vr_violation_seen = 1'b0;
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

    always @(negedge rst_ni) begin
        native_vr_violation_seen = 1'b0;
    end

    function void report_native_vr_violation(string channel);
        native_vr_violation_seen = 1'b1;
        $error("[ITA_NATIVE_VR] %s changed valid, payload, or metadata before ready", channel);
    endfunction : report_native_vr_violation

    `include "ita_mha8_if_head_sva.svh"
    `include "ita_mha8_if_sum_sva.svh"
    `include "ita_mha8_if_ff_sva.svh"
    `include "ita_mha8_if_ctrl_sva.svh"
    
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

endinterface : ita_mha8_if

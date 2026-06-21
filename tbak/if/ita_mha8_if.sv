interface ita_mha8_if
    import ita_package::*;
#(
    parameter int unsigned NumHeads = 8
) (
    input logic clk_i
);

    logic                    rst_ni;
    ctrl_t                   ctrl_i;
    // TODO Stage 2: add shared MHA8 ctrl helpers/assertions here; ctrl_i is broadcast to all heads.

    requant_const_array_t    head_eps_mult_i    [NumHeads];
    requant_const_array_t    head_right_shift_i [NumHeads];
    requant_array_t          head_add_i         [NumHeads];
    // TODO Stage 2: add per-head requant defaults here; initialize only head 0 before full MHA8 expansion.

    logic [NumHeads-1:0]     inp_valid_i;
    logic [NumHeads-1:0]     inp_ready_o;
    logic [NumHeads-1:0]     inp_weight_valid_i;
    logic [NumHeads-1:0]     inp_weight_ready_o;
    logic [NumHeads-1:0]     inp_bias_valid_i;
    logic [NumHeads-1:0]     inp_bias_ready_o;
    // TODO Stage 3-4: add valid-ready stability assertions for head0 input/weight/bias first.

    inp_t                    inp_i        [NumHeads];
    inp_weight_t             inp_weight_i [NumHeads];
    bias_t                   inp_bias_i   [NumHeads];
    // TODO Stage 8: add X/Z checks on handshaked source payloads after head0 streams are active.

    step_e                   inp_step_dbg          [NumHeads];
    step_e                   inp_weight_step_dbg   [NumHeads];
    step_e                   inp_bias_step_dbg     [NumHeads];
    int unsigned             inp_tile_id_dbg       [NumHeads];
    int unsigned             inp_weight_tile_id_dbg[NumHeads];
    int unsigned             inp_bias_tile_id_dbg  [NumHeads];
    int unsigned             inp_inner_id_dbg      [NumHeads];
    int unsigned             inp_weight_inner_id_dbg[NumHeads];
    int unsigned             inp_bias_inner_id_dbg [NumHeads];
    int unsigned             inp_beat_id_dbg       [NumHeads];
    int unsigned             inp_weight_beat_id_dbg[NumHeads];
    int unsigned             inp_bias_beat_id_dbg  [NumHeads];
    logic                    inp_lockstep_dbg      [NumHeads];
    logic                    inp_weight_lockstep_dbg[NumHeads];
    logic                    inp_bias_lockstep_dbg [NumHeads];
    // TODO Stage 7-8: use debug metadata for logger and smoke scoreboard attribution.

    logic [NumHeads-1:0]     per_head_valid_o;
    logic [NumHeads-1:0]     per_head_ready_i;
    logic [NumHeads-1:0]     per_head_busy_o;
    requant_oup_t            per_head_oup_o  [NumHeads];
    step_e                   per_head_step_o [NumHeads];
    // TODO Stage 5: add head0 output ready/valid observation and output-stable-under-backpressure assertions.

    logic                    sum_valid_o;
    logic                    sum_ready_i;
    requant_oup_t            sum_oup_o;
    // TODO Stage 11: add sum output monitor/checker after all per-head outputs are stable.

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
    logic                    phase_mismatch_o;
    // TODO Stage 11: add feed-forward agents and phase_mismatch_o checks after MHA head flow is proven.

    initial begin
        rst_ni                = 1'b0;
        ctrl_i                = '0;
        inp_valid_i           = '0;
        inp_weight_valid_i    = '0;
        inp_bias_valid_i      = '0;
        per_head_ready_i      = '0;
        sum_ready_i           = 1'b0;
        ff_inp_valid_i        = 1'b0;
        ff_inp_weight_valid_i = 1'b0;
        ff_inp_bias_valid_i   = 1'b0;
        ff_ready_i            = 1'b0;
        // TODO Stage 1: keep non-driven heads, sum, and feed-forward tied off during baseline smoke.

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
            // TODO Stage 11: keep interface shape unchanged when enabling heads 1-7 through env config.
        end

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
        // TODO Stage 11: replace feed-forward tie-offs with active stimulus only in Feedforward tests.
    end

endinterface : ita_mha8_if

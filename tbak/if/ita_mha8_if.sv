interface ita_mha8_if
    import ita_package::*;
#(
    parameter int unsigned NumHeads = 8
) (
    input logic clk_i
);

    logic                    rst_ni;
    ctrl_t                   ctrl_i;
    // TODO Stage 8: add ctrl_i.start X/Z and one-cycle pulse assertions after ctrl_driver implements the pulse.

    requant_const_array_t    head_eps_mult_i    [NumHeads];
    requant_const_array_t    head_right_shift_i [NumHeads];
    requant_array_t          head_add_i         [NumHeads];
    // TODO Stage 8: add head0 requant X/Z assertions while ctrl_i.start is asserted.

    logic [NumHeads-1:0]     inp_valid_i;
    logic [NumHeads-1:0]     inp_ready_o;
    logic [NumHeads-1:0]     inp_weight_valid_i;
    logic [NumHeads-1:0]     inp_weight_ready_o;
    logic [NumHeads-1:0]     inp_bias_valid_i;
    logic [NumHeads-1:0]     inp_bias_ready_o;
    // TODO Stage 3-4: add valid-ready stability assertions for head0 input/weight/bias streams.

    inp_t                    inp_i        [NumHeads];
    inp_weight_t             inp_weight_i [NumHeads];
    bias_t                   inp_bias_i   [NumHeads];
    // TODO Stage 3-4: add head0 payload stability assertions while valid is high and ready is low.

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
    // TODO Stage 5: add head0 output backpressure stability assertion after output ready driving exists.

    logic                    sum_valid_o;
    logic                    sum_ready_i;
    requant_oup_t            sum_oup_o;
    // TODO Stage 11: add sum output assertions and monitor hooks after heads 0-7 are enabled.

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
    // TODO Stage 11: add feed-forward stream assertions after the FF path is added to active tests.

    // TODO ·: initialize or tie off driver-owned pins needed for an idle smoke shell.
    initial begin
        rst_ni = 0;
        ctrl_i = '0;
        inp_valid_i = '0;
        inp_weight_valid_i = '0;
        inp_bias_valid_i = '0;
        per_head_ready_i = '0;
        sum_ready_i = '0;

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
    // TODO Stage 8: implement early assertion blocks for X/Z, timeout, valid-ready, and backpressure.

endinterface : ita_mha8_if

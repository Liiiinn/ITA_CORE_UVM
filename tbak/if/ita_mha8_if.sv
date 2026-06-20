interface ita_mha8_if
    import ita_package::*;
#(
    parameter int unsigned NumHeads = 8
) (
    input logic clk_i
);

    // TODO Stage 1: keep all ita_mha8 DUT ports visible while the learning TB focuses on head 0.
    // TODO Stage 2: add basic valid-ready protocol assertions for input/weight/bias/output streams.
    // TODO Stage 3: add X/Z assertions on handshaked control and payload signals.
    // TODO Stage 4: add output payload stability assertions while backpressured.
    // TODO Stage 5: add explicit verification entry points for sum and feed-forward ports.
    logic                    rst_ni;
    ctrl_t                   ctrl_i;
    requant_const_array_t    head_eps_mult_i    [NumHeads];
    requant_const_array_t    head_right_shift_i [NumHeads];
    requant_array_t          head_add_i         [NumHeads];

    logic [NumHeads-1:0]     inp_valid_i;
    logic [NumHeads-1:0]     inp_ready_o;
    logic [NumHeads-1:0]     inp_weight_valid_i;
    logic [NumHeads-1:0]     inp_weight_ready_o;
    logic [NumHeads-1:0]     inp_bias_valid_i;
    logic [NumHeads-1:0]     inp_bias_ready_o;

    inp_t                    inp_i        [NumHeads];
    inp_weight_t             inp_weight_i [NumHeads];
    bias_t                   inp_bias_i   [NumHeads];

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

    logic [NumHeads-1:0]     per_head_valid_o;
    logic [NumHeads-1:0]     per_head_ready_i;
    logic [NumHeads-1:0]     per_head_busy_o;
    requant_oup_t            per_head_oup_o  [NumHeads];
    step_e                   per_head_step_o [NumHeads];

    logic                    sum_valid_o;
    logic                    sum_ready_i;
    requant_oup_t            sum_oup_o;

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

endinterface : ita_mha8_if



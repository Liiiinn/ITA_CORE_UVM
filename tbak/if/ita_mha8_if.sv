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
    step_e                   sum_step_dbg;
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

            inp_payload_known_when_valid_a: assert property(inp_payload_known_when_valid);
            weight_payload_known_when_valid_a: assert property(weight_payload_known_when_valid);
            bias_payload_known_when_valid_a: assert property(bias_payload_known_when_valid);
            head_output_known_when_valid_a: assert property(head_output_known_when_valid);
            stream_ctrl_known_a: assert property(stream_ctrl_known);
            inp_stable_until_a: assert property(inp_stable_until_ready);
            weight_stable_until_a: assert property(weight_stable_until_ready);
            bias_stable_until_a: assert property(bias_stable_until_ready);
            head_output_stable_until_ready_a: assert property(head_output_stable_until_ready);
        end
    endgenerate

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

    property ctrl_start_pulse;
        @(posedge clk_i) disable iff (!rst_ni)
            ctrl_i.start |=> !ctrl_i.start;
    endproperty : ctrl_start_pulse

    ctrl_start_known_a: assert property(ctrl_start_known);
    ctrl_known_a: assert property(ctrl_known);
    ctrl_start_pulse_a: assert property(ctrl_start_pulse);

endinterface : ita_mha8_if

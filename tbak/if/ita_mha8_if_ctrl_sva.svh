`ifndef ITA_MHA8_IF_CTRL_SVA_SVH
`define ITA_MHA8_IF_CTRL_SVA_SVH

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

ctrl_start_known_a: assert property(ctrl_start_known);
ctrl_known_a: assert property(ctrl_known);
ctrl_requant_known_a: assert property(ctrl_requant_known);
ctrl_tile_nonzero_a: assert property(ctrl_tile_nonzero);
ctrl_layer_legal_a: assert property(ctrl_layer_legal);
ctrl_activation_legal_a: assert property(ctrl_activation_legal);
ctrl_start_pulse_a: assert property(ctrl_start_pulse);
driver_owned_idle_during_reset_a: assert property(driver_owned_idle_during_reset);

`endif // ITA_MHA8_IF_CTRL_SVA_SVH
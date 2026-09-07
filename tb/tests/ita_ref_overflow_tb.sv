// Isolated documented boundary: PyITA clips; the RTL accumulator wraps at WO.
// This test confirms the discrepancy without modifying the DUT or the oracle.
module ita_ref_overflow_tb;
    import ita_package::*;
    import ita_mha8_scb_pkg::*;

    logic clk = 1'b0;
    logic rst = 1'b0;

    // Resolve virtual-interface types imported by UVM packages.
    ita_mha8_if vif(clk);

    oup_t  value;
    oup_t  result;
    bias_t bias_value;

    always #5 clk = ~clk;

    ita_accumulator dut (
        .clk_i         (clk),
        .rst_ni        (rst),
        .calc_en_i     (1'b1),
        .calc_en_q_i   (1'b1),
        .first_tile_i  (1'b1),
        .first_tile_q_i(1'b1),
        .last_tile_i   (1'b1),
        .last_tile_q_i (1'b1),
        .oup_i         (value),
        .inp_bias_i    (bias_value),
        .result_o      (result)
    );

    initial begin
        value      = '0;
        bias_value = '0;
        value[0]   = (64'sd1 << (WO - 1)) - 1;
        bias_value[0] = 1;

        #12;
        rst = 1'b1;
        @(negedge clk);

        if ($signed(result[0]) != -(64'sd1 << (WO - 1))) begin
            $fatal(1, "Unexpected RTL overflow result");
        end
        if (ita_mha8_ref_model::clip_acc(64'sd1 << (WO - 1)) !=
            ((64'sd1 << (WO - 1)) - 1)) begin
            $fatal(1, "Unexpected PyITA clip result");
        end

        $display(
            "ITA_OVERFLOW_DIFFERENCE_CONFIRMED RTL=%0d PYITA=%0d",
            $signed(result[0]),
            ita_mha8_ref_model::clip_acc(64'sd1 << (WO - 1))
        );
        $finish;
    end
endmodule : ita_ref_overflow_tb

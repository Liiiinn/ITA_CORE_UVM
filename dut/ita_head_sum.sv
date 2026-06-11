// Copyright 2026
// SPDX-License-Identifier: SHL-0.51

module ita_head_sum
    import ita_package::*;
#(
    parameter int unsigned NumHeads = 8
) (
    input  logic                                  clk_i,
    input  logic                                  rst_ni,
    input  logic                                  valid_i,
    output logic                                  ready_o,
    input  requant_oup_t                         head_oup_i [NumHeads],
    input  requant_const_t                       eps_mult_i,
    input  requant_const_t                       right_shift_i,
    input  requant_t                             add_i,
    output logic                                  valid_o,
    input  logic                                  ready_i,
    output requant_oup_t                          oup_o
);

    oup_t sum;
    requant_oup_t requant_oup;
    fifo_data_t fifo_data_in, fifo_data_out;
    logic calc_en, calc_en_q1, calc_en_q2;
    logic fifo_full, fifo_empty, fifo_push, fifo_pop;
    fifo_usage_t fifo_usage;
    int unsigned fifo_reserved;

    assign calc_en = valid_i && ready_o;
    assign fifo_reserved = int'(fifo_usage) + int'(calc_en_q1) + int'(calc_en_q2);
    assign ready_o = fifo_reserved < FifoDepth;
    assign fifo_push = calc_en_q2;
    assign fifo_pop = valid_o && ready_i;
    assign valid_o = !fifo_empty;
    assign oup_o = valid_o ? fifo_data_out : '0;
    assign fifo_data_in = {>>WI{requant_oup}};

    always_comb begin
        sum = '0;
        for (int lane = 0; lane < N; lane++) begin
            for (int head = 0; head < NumHeads; head++) begin
                sum[lane] += {{(WO-WI){head_oup_i[head][lane][WI-1]}}, head_oup_i[head][lane]};
            end
        end
    end

    ita_requantizer i_requantizer (
        .clk_i        (clk_i              ),
        .rst_ni       (rst_ni             ),
        .mode_i       (requant_mode_e'(Signed)),
        .eps_mult_i   (eps_mult_i         ),
        .right_shift_i(right_shift_i      ),
        .calc_en_i    (calc_en            ),
        .calc_en_q_i  (calc_en_q1         ),
        .result_i     (sum                ),
        .add_i        ({N {add_i}}        ),
        .requant_oup_o(requant_oup        )
    );

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            calc_en_q1 <= 1'b0;
            calc_en_q2 <= 1'b0;
        end else begin
            calc_en_q1 <= calc_en;
            calc_en_q2 <= calc_en_q1;
        end
    end

    fifo_v3 #(
        .FALL_THROUGH(1'b0     ),
        .DATA_WIDTH  (N*WI     ),
        .DEPTH       (FifoDepth)
    ) i_output_fifo (
        .clk_i     (clk_i            ),
        .rst_ni    (rst_ni           ),
        .flush_i   (1'b0             ),
        .testmode_i(1'b0             ),
        .full_o    (fifo_full        ),
        .empty_o   (fifo_empty       ),
        .usage_o   (fifo_usage       ),
        .data_i    (fifo_data_in     ),
        .push_i    (fifo_push        ),
        .data_o    (fifo_data_out    ),
        .pop_i     (fifo_pop         )
    );

endmodule

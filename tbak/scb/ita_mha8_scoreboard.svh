`ifndef ITA_MHA8_SCOREBOARD_SVH
`define ITA_MHA8_SCOREBOARD_SVH

class ita_mha8_scoreboard extends uvm_component;
    `uvm_component_utils(ita_mha8_scoreboard)

    uvm_tlm_analysis_fifo #(ita_stream_item) expected_fifo;
    uvm_tlm_analysis_fifo #(ita_stream_item) actual_fifo;

    int unsigned compare_count;
    int unsigned actual_count;
    int unsigned expected_count;

    function new(string name = "ita_mha8_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        expected_fifo = new("expected_fifo", this);
        actual_fifo = new("actual_fifo", this);
    endfunction : new

    task run_phase(uvm_phase phase);
        ita_stream_item expected;
        ita_stream_item actual;

        forever begin
            actual_fifo.get(actual);
            actual_count++;
            sanity_check_actual(actual);
            if (expected_fifo.try_get(expected)) begin
                expected_count++;
                compare_metadata(expected, actual);
            end
        end
    endtask : run_phase

    function void compare_metadata(ita_stream_item expected, ita_stream_item actual);
        compare_count++;

        if (expected.head_id != actual.head_id) begin
            `uvm_error("ITA_SCB_HEAD", $sformatf("Head mismatch expected=%0d actual=%0d", expected.head_id, actual.head_id))
        end

        if (expected.step != actual.step) begin
            `uvm_error("ITA_SCB_STEP", $sformatf("Step mismatch expected=%0d actual=%0d", expected.step, actual.step))
        end

        if (expected.beat_id != actual.beat_id) begin
            `uvm_info("ITA_SCB_BEAT", $sformatf(
                "Placeholder expected beat=%0d actual beat=%0d; numeric compare is not enabled in skeleton",
                expected.beat_id, actual.beat_id
            ), UVM_MEDIUM)
        end
    endfunction : compare_metadata

    function void sanity_check_actual(ita_stream_item actual);
        if (!(actual.kind inside {ITA_STREAM_HEAD_OUTPUT, ITA_STREAM_SUM_OUTPUT, ITA_STREAM_FF_OUTPUT})) begin
            `uvm_error("ITA_SCB_KIND", $sformatf("Unexpected actual stream kind=%0d", actual.kind))
        end

        if (actual.kind == ITA_STREAM_HEAD_OUTPUT && actual.head_id >= 8) begin
            `uvm_error("ITA_SCB_HEAD", $sformatf("Illegal head_id=%0d", actual.head_id))
        end

        if (!(actual.step inside {Q, K, V, QK, AV, OW, F1, F2, MatMul})) begin
            `uvm_error("ITA_SCB_STEP", $sformatf("Illegal output step=%0d", actual.step))
        end

        if ($isunknown(actual.oup)) begin
            `uvm_error("ITA_SCB_XZ", "Actual output contains X/Z")
        end
    endfunction : sanity_check_actual

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("ITA_SCB", $sformatf(
            "Skeleton scoreboard actual=%0d expected_used=%0d metadata_compares=%0d",
            actual_count, expected_count, compare_count
        ), UVM_LOW)
    endfunction : report_phase

endclass : ita_mha8_scoreboard

`endif // ITA_MHA8_SCOREBOARD_SVH

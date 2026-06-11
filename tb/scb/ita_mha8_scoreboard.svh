`ifndef ITA_MHA8_SCOREBOARD_SVH
`define ITA_MHA8_SCOREBOARD_SVH

class ita_mha8_scoreboard extends uvm_component;
    `uvm_component_utils(ita_mha8_scoreboard)

    uvm_tlm_analysis_fifo #(ita_stream_item) expected_fifo;
    uvm_tlm_analysis_fifo #(ita_stream_item) actual_fifo;

    int unsigned compare_count;

    function new(string name = "ita_mha8_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        expected_fifo = new("expected_fifo", this);
        actual_fifo = new("actual_fifo", this);
    endfunction : new

    task run_phase(uvm_phase phase);
        ita_stream_item expected;
        ita_stream_item actual;

        forever begin
            expected_fifo.get(expected);
            actual_fifo.get(actual);
            compare_items(expected, actual);
        end
    endtask : run_phase

    function void compare_items(ita_stream_item expected, ita_stream_item actual);
        compare_count++;

        if (expected.kind != actual.kind) begin
            `uvm_error("ITA_SCB_KIND", $sformatf("Kind mismatch expected=%0d actual=%0d", expected.kind, actual.kind))
        end

        if (expected.head_id != actual.head_id) begin
            `uvm_error("ITA_SCB_HEAD", $sformatf("Head mismatch expected=%0d actual=%0d", expected.head_id, actual.head_id))
        end

        if (expected.step != actual.step) begin
            `uvm_error("ITA_SCB_STEP", $sformatf("Step mismatch expected=%0d actual=%0d", expected.step, actual.step))
        end

        if (expected.oup !== actual.oup) begin
            `uvm_error("ITA_SCB_DATA", "Output data mismatch")
        end
    endfunction : compare_items

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("ITA_SCB", $sformatf("Compared %0d output transactions", compare_count), UVM_LOW)
    endfunction : report_phase

endclass : ita_mha8_scoreboard

`endif // ITA_MHA8_SCOREBOARD_SVH

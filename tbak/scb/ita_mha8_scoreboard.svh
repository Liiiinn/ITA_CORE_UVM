`ifndef ITA_MHA8_SCOREBOARD_SVH
`define ITA_MHA8_SCOREBOARD_SVH

class ita_mha8_scoreboard extends uvm_component;
    `uvm_component_utils(ita_mha8_scoreboard)

    uvm_tlm_analysis_fifo #(ita_stream_item) expected_fifo;
    uvm_tlm_analysis_fifo #(ita_stream_item) actual_fifo;
    // TODO Stage 8: decide whether smoke scoreboard needs expected_fifo or only actual monitor input.

    function new(string name = "ita_mha8_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        expected_fifo = new("expected_fifo", this);
        actual_fifo = new("actual_fifo", this);
    endfunction : new

    task run_phase(uvm_phase phase);
        // TODO Stage 8: implement smoke checks for count, X/Z, timeout, and valid-ready protocol.
        // TODO Stage 10: compare actual and expected output only after the Phase 2 path is connected.
    endtask : run_phase

endclass : ita_mha8_scoreboard

`endif // ITA_MHA8_SCOREBOARD_SVH

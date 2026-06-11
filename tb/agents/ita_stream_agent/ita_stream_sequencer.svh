`ifndef ITA_STREAM_SEQUENCER_SVH
`define ITA_STREAM_SEQUENCER_SVH

class ita_stream_sequencer extends uvm_sequencer #(ita_stream_item);
    `uvm_component_utils(ita_stream_sequencer)

    function new(string name = "ita_stream_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

endclass : ita_stream_sequencer

`endif // ITA_STREAM_SEQUENCER_SVH

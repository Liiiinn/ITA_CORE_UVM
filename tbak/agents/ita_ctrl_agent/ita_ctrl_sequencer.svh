`ifndef ITA_CTRL_SEQUENCER_SVH
`define ITA_CTRL_SEQUENCER_SVH

class ita_ctrl_sequencer extends uvm_sequencer #(ita_ctrl_item);
    `uvm_component_utils(ita_ctrl_sequencer)

    function new(string name = "ita_ctrl_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

endclass : ita_ctrl_sequencer

`endif // ITA_CTRL_SEQUENCER_SVH

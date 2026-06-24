`ifndef ITA_MHA8_VSEQUENCER_SVH
`define ITA_MHA8_VSEQUENCER_SVH

class ita_mha8_vsequencer extends uvm_sequencer;
    `uvm_component_utils(ita_mha8_vsequencer)

    ita_ctrl_sequencer ctrl_sqr;
    ita_stream_sequencer inp_sqr;
    ita_stream_sequencer weight_sqr;
    ita_stream_sequencer bias_sqr;
    
    function new(string name = "ita_mha8_vsequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

endclass : ita_mha8_vsequencer

`endif // ITA_MHA8_VSEQUENCER_SVH
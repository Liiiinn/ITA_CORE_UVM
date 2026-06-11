`ifndef ITA_CTRL_CONFIG_SVH
`define ITA_CTRL_CONFIG_SVH

class ita_ctrl_config extends uvm_object;
    `uvm_object_utils(ita_ctrl_config)

    virtual ita_mha8_if vif;
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    function new(string name = "ita_ctrl_config");
        super.new(name);
    endfunction : new

endclass : ita_ctrl_config

`endif // ITA_CTRL_CONFIG_SVH

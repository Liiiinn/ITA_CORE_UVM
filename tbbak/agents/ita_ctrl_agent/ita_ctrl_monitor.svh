`ifndef ITA_CTRL_MONITOR_SVH
`define ITA_CTRL_MONITOR_SVH

class ita_ctrl_monitor extends uvm_monitor;
    `uvm_component_utils(ita_ctrl_monitor)

    ita_ctrl_config cfg;
    uvm_analysis_port #(ita_ctrl_item) ap;

    function new(string name = "ita_ctrl_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ita_ctrl_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("CTRL_MON_CFG", "ita_ctrl_config was not set")
        end
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        ita_ctrl_item tr;

        forever begin
            @(posedge cfg.vif.clk_i);
            if (cfg.vif.rst_ni && cfg.vif.ctrl_i.start) begin
                tr = ita_ctrl_item::type_id::create("tr");
                tr.ctrl = cfg.vif.ctrl_i;
                for (int unsigned h = 0; h < 8; h++) begin
                    tr.head_eps_mult[h]    = cfg.vif.head_eps_mult_i[h];
                    tr.head_right_shift[h] = cfg.vif.head_right_shift_i[h];
                    tr.head_add[h]         = cfg.vif.head_add_i[h];
                end
                ap.write(tr);
            end
        end
    endtask : run_phase

endclass : ita_ctrl_monitor

`endif // ITA_CTRL_MONITOR_SVH

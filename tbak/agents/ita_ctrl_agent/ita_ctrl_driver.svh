`ifndef ITA_CTRL_DRIVER_SVH
`define ITA_CTRL_DRIVER_SVH

class ita_ctrl_driver extends uvm_driver #(ita_ctrl_item);
    `uvm_component_utils(ita_ctrl_driver)

    ita_ctrl_config cfg;

    function new(string name = "ita_ctrl_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ita_ctrl_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("CTRL_DRV_CFG", "ita_ctrl_config was not set")
        end
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        ita_ctrl_item tr;

        drive_idle();
        wait (cfg.vif.rst_ni === 1'b1);

        forever begin
            seq_item_port.get_next_item(tr);
            drive_item(tr);
            seq_item_port.item_done();
        end
    endtask : run_phase

    task drive_idle();
        cfg.vif.ctrl_i.start <= 1'b0;
        for (int unsigned h = 0; h < 8; h++) begin
            cfg.vif.head_eps_mult_i[h]    <= '0;
            cfg.vif.head_right_shift_i[h] <= '0;
            cfg.vif.head_add_i[h]         <= '0;
        end
    endtask : drive_idle

    task drive_item(ita_ctrl_item tr);
        @(posedge cfg.vif.clk_i);
        cfg.vif.ctrl_i <= tr.ctrl;
        for (int unsigned h = 0; h < 8; h++) begin
            cfg.vif.head_eps_mult_i[h]    <= tr.head_eps_mult[h];
            cfg.vif.head_right_shift_i[h] <= tr.head_right_shift[h];
            cfg.vif.head_add_i[h]         <= tr.head_add[h];
        end
        @(posedge cfg.vif.clk_i);
        cfg.vif.ctrl_i.start <= 1'b0;
    endtask : drive_item

endclass : ita_ctrl_driver

`endif // ITA_CTRL_DRIVER_SVH

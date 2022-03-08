/* Name: Raad Khan
   Student ID: 26751157
   Purpose: To verify the link io controller */

// format: step unit / resolution unit
`timescale 1ns/1ps

// opcode[8:5] encoding
`define app_activate    4'b1000 // input from app to activate the io controller
`define app_hibernate   4'b0100 // input from app to hibernate the io controller
`define timer_sleep     4'b0010 // input from sleep timer to sleep the io controller
`define charger_charge  4'b0001 // input from charger to charge the io controller
`define any_idle        4'b0000 // input from anything to idle the io controller

// opcode[4:0] encoding
`define io_ok           5'b10000 // input from io pipe for ok response to the io controller
`define afe_ok          5'b01000 // input from afe for ok response to the io controller
`define a2d_ok          5'b00100 // input from a2d for ok response to the io controller
`define dsp_ok          5'b00010 // input from dsp for ok response to the io controller
`define blem_ok         5'b00001 // input from blem for ok response to the io controller
`define any_notok       5'b00000 // input from io pipe for not ok response to the io controller
`define any_dontcare    5'b11111 // dont care about any inputs from io pipe to the io controller

module io_controller_tb import typedefs::*;();
    logic [7:0] error;
    logic [8:0] opcode;
    logic [9:0] io_pipe_req_o;

    // inputs of the io controller
    logic clk;
    logic wd_rst;
    logic app_activate, app_hibernate,
          timer_sleep,
          charger_charge,
          afe_ok, a2d_ok, dsp_ok, blem_ok;

    // outputs of the io controller
    logic idle_o, activate_o, hibernate_o, sleep_o, charge_o,
          stream_eeg_o, process_eeg_o, interpret_eeg_o,
          build_ble_cmd_o, publish_ble_cmd_o;

    // organize inputs and outputs into buses
    assign {app_activate, app_hibernate,
            timer_sleep,
            charger_charge} = opcode[8:5];

    assign {afe_ok, a2d_ok, dsp_ok, blem_ok} = {opcode[4] || opcode[3], opcode[4] || opcode[2], opcode[4] || opcode[1], opcode[4] || opcode[0]};

    assign io_pipe_req_o = {idle_o, activate_o, hibernate_o, sleep_o, charge_o,
                            stream_eeg_o, process_eeg_o, interpret_eeg_o,
                            build_ble_cmd_o, publish_ble_cmd_o};

    // instantiate the io controller
    io_controller_top dut(.*);

    // initialize inputs
    initial
    begin
        {error, opcode, clk, wd_rst} = {8'b0, 9'b0, 2'b01};
    end

    // initialize clock with T = step unit
    always
    begin
        #5 clk = ~clk;
    end

    // create task to verify the fsm
    task verifier;
        input state_t expected_state;
        input output_t exp_io_pipe_req;

        begin
            if (io_controller_tb.dut.ic.present_state !== expected_state)
            begin
                $error("state is %b, expected %b",
                       io_controller_tb.dut.ic.present_state, expected_state);
                error += 8'b1;
            end
            if(io_controller_tb.dut.ic.io_pipe_req !== exp_io_pipe_req)
            begin
                $error("output is %b, expected %b",
                       io_controller_tb.dut.ic.io_pipe_req, exp_io_pipe_req);
                error += 8'b1;
            end
        end
    endtask

    initial
    begin
        // watchdog timer releases reset after 10 steps on the io controller to start at Idle
        #10;
        wd_rst = 0;
        verifier(Idle, idle);

        // verify power modes

        // verify Hibernate
        opcode = {`app_hibernate, `any_dontcare};
        #10;
        verifier(Hibern, hibernate);

        // return to Idle
        opcode = {`any_idle, `any_dontcare};
        #10;
        verifier(Idle, idle);

        // verify Sleep
        opcode = {`timer_sleep, `any_dontcare};
        #10;
        verifier(Sleep, sleep);

        // return to Idle
        opcode = {`any_idle, `any_dontcare};
        #10;
        verifier(Idle, idle);

        // verify Charge
        opcode = {`charger_charge, `any_dontcare};
        #10;
        verifier(Charge, charge);

        // return to Idle
        opcode = {`any_idle, `any_dontcare};
        #10;
        verifier(Idle, idle);

        // verify complete io pipe process

        // verify Activate
        opcode = {`app_activate, `any_dontcare};
        #10;
        verifier(Activ, activate);

        // verify StreamEEG
        opcode = {`app_activate, `io_ok};
        #10;
        verifier(Stream, stream_eeg);

        // verify ProcessEEG
        opcode = {`app_activate, `afe_ok};
        #10;
        verifier(Proc, process_eeg);

        // verify InterpretEEG
        opcode = {`app_activate, `a2d_ok};
        #10;
        verifier(Interp, interpret_eeg);

        // verify BuildBLEcmd
        opcode = {`app_activate, `dsp_ok};
        #10;
        verifier(Build, build_ble_cmd);

        // verify PublishBLEcmd
        opcode = {`app_activate, `blem_ok};
        #10;
        verifier(Publ, publish_ble_cmd);

        // verify StreamEEG
        opcode = {`app_activate, `blem_ok};
        #10;
        verifier(Stream, stream_eeg);

        // verify interrupted io pipe process

        // verify ProcessEEG
        opcode = {`app_activate, `afe_ok};
        #10;
        verifier(Proc, process_eeg);

        // user stops app,
        // so watchdog timer detects this and resets back to Idle
        opcode = {`any_idle, `a2d_ok};
        wd_rst = 1;
        #10;
        verifier(Idle, idle);
    end
endmodule

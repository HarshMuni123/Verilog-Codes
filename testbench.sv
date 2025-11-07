
class transaction;
    rand bit din;
    bit out;

    function transaction copy();
        copy = new();
        copy.din = this.din;
        copy.out = this.out;
    endfunction

endclass

class generator;
    transaction trans;
    mailbox #(transaction) gen2drv;

    function new(mailbox #(transaction) gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task run();
        for(int i = 0; i < 5; i = i+1) begin
            trans = new();
            assert(trans.randomize()) else $error("Randomization Failed")
            $display("[%0t] [GEN] : \t din = %0b",$time,trans.din);
            gen2drv.put(trans);
            #10;
        end
    endtask

endclass

class driver;
    virtual dff_ff dif;
    mailbox #(transaction) gen2drv;
    transaction trans;

    function new(virtual dff_ff dif,mailbox #(transaction) gen2drv);
        this.dif = dif;
        this.gen2drv = gen2drv;
    endfunction

    task run();
        forever begin
            gen2drv.get(trans);
            @(posedge dif.clk);
            dif.din = trans.din;
            $display("[%0t] [DRV]: \t din = %0b",$time,dif.din);
        end
    endtask

endclass

// The monitor observes DUT signals (through the interface), captures them into a transaction, and sends them to the scoreboard via a mailbox.
class monitor;

    virtual dff_ff dif;
    mailbox #(transaction) mon2sco;
    transaction trans;

    function new(virtual dff_ff dif,mailbox #(transaction) mon2sco);
        this.dif = dif;
        this.mon2sco = mon2sco;
    endfunction

    task run();
        forever begin
            @(posedge dif.clk);
            if(!dif.rst) begin
                trans = new();
                trans.din = dif.din;
                trans.out = dif.out;
                $display("[%0t] [MON]: \t din = %0b out = %0b", $time, trans.din, trans.out);
                mon2sco.put(trans);
            end
        end
    endtask

endclass

// The scoreboard receives transactions from the monitor and performs checking/comparison.
class scoreboard;

    mailbox #(transaction) mon2sco;
    bit expected_out;
    transaction trans;

    function new(mailbox #(transaction) mon2sco);
        this.mon2sco = mon2sco;
        expected_out = 0;
    endfunction

    task run();
        forever begin
            mon2sco.get(trans);
            if (trans.out !== expected_out)
                $error("[%0t] [SCB]: Mismatch! Expected = %0b, Got = %0b", $time, expected_out, trans.out);
            else
                $display("[%0t] [SCB]: PASS ✓ Expected = %0b, Got = %0b", $time, expected_out, trans.out);

            expected_out = trans.din; // Update for next cycle
        end
    endtask

endclass

class environment;
    
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;

    mailbox #(transaction) gen2drv;
    mailbox #(transaction) mon2sco;

    virtual dff_ff dif;

    function  new(virtual dff_ff dif);
        this.dif = dif;
        gen2drv = new();
        mon2sco = new();
        gen = new(gen2drv);
        drv = new(dif,gen2drv);
        mon = new(dif,mon2sco);
        sco = new(mon2sco);
    endfunction

    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_none
    endtask

endclass

module tb;

    logic clk;
    logic rst;
    logic din;
    logic out;

    dff_ff dif();

    // Instantiate DUT with the interface handle
    dff dut(.dif(dif));

    environment env;

    // generator gen;
    // driver drv;
    // mailbox #(transaction) gen2drv;

    initial begin 
        clk = 0;
        forever #5 clk = ~clk;
    end

    assign dif.clk = clk;

    // connect and drive reset
    assign dif.rst = rst;

    initial begin
        rst = 1;
        #20 rst = 0;
    end

    initial begin
        // gen2drv = new();
        // gen = new(gen2drv);
        // drv = new(dif,gen2drv);

        // fork
        //     gen.run();
        //     drv.run();
        // join_none
        // #100 $finish;
        env = new(dif);
        env.run();
        #200 $finish;
    end

endmodule



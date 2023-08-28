// interface
interface inter();
bit [3:0]i;
bit [1:0]y;

modport WDR(output i);
modport WMN(input i);
modport RMN(input y,input i);
endinterface

//transaction class

class trans;
randc bit [3:0]i;
bit [1:0]y;

constraint c1{i < 16;}
endclass

//generator class

class generator;

 trans t1;
 
 //mailbox 
mailbox #(trans)gen2drv;

function new(mailbox #(trans)gen2drv);
 this.gen2drv=gen2drv;
  t1=new();
endfunction

task start;
 fork
   repeat(10)
      begin
      assert(t1.randomize());
      gen2drv.put(t1);
      #2;
      end
 join_none
endtask

endclass

//write_driver

class write_drv;
 trans t2;

 //mailbox and interfaces

 mailbox #(trans)gen2drv;
 virtual inter.WDR drv2duv;

 function new(virtual inter.WDR drv2duv,mailbox #(trans)gen2drv); 
    this.drv2duv=drv2duv;
    this.gen2drv=gen2drv;
    t2=new();
 endfunction

task start;
 fork
 forever
   begin
     gen2drv.get(t2);
     drv2duv.i<=t2.i;
     #2;
   end
 join_none
endtask

endclass

//write_monitor

class write_mon;

 mailbox #(trans)mon2ref;
 virtual inter.WMN duv2wmon;
 trans t3;
 function new(virtual inter.WMN duv2wmon,mailbox #(trans)mon2ref);
  this.mon2ref=mon2ref;
  this.duv2wmon=duv2wmon;
  t3=new();
 endfunction

 task start();
  fork
   forever
    begin
     #2;
     t3.i=duv2wmon.i;
     mon2ref.put(t3);
    end
   join_none
 endtask

endclass

//READ MONITOR 

class read_mon;
trans t4;
 mailbox #(trans)rmon2sb;
 virtual inter.RMN duv2rmon;
 
 function new(virtual inter.RMN duv2rmon,mailbox #(trans)rmon2sb);
  this.rmon2sb=rmon2sb;
  this.duv2rmon=duv2rmon;
  t4=new();
 endfunction

 task start;
  fork
   forever
      begin
       #2;
       t4.y=duv2rmon.y;
       t4.i=duv2rmon.i;
       rmon2sb.put(t4);
      end
  join_none
 endtask

endclass

//reference module

class referance;
 trans t5;
 mailbox #(trans)ref2sb;
 mailbox #(trans)mon2ref;
 
 function new(mailbox #(trans)ref2sb,mailbox #(trans)mon2ref);
   this.ref2sb=ref2sb;
   this.mon2ref=mon2ref;
   t5=new();
 endfunction

 task start();
  fork
   forever
        begin
          mon2ref.get(t5);
           if(t5.i>=8)
             t5.y='b11;
           else if(t5.i>=4)
             t5.y='b10;
           else if(t5.i>=2)
             t5.y='b01;
           else
             t5.y='b00;
          ref2sb.put(t5);
        end
  join_none
 endtask

endclass

//scoreboard

class scoreboard;
 trans t7,t8;
 mailbox #(trans)ref2sb;
 mailbox #(trans)rmon2sb;
 int no_of_transfer;
 event DONE;
 function new(mailbox #(trans)ref2sb,mailbox #(trans)rmon2sb);
   this.ref2sb=ref2sb;
   this.rmon2sb=rmon2sb;
   t7=new();
   t8=new();
 endfunction

 task start();
  fork
     forever
        begin
          ref2sb.get(t7);
          rmon2sb.get(t8);
          $display("---------------------------------------");
          check_data();
          $display("no_of_transfer= %d",no_of_transfer);
       end
  join_none
 endtask
 task check_data;
   if(t7.i==t8.i)
      begin
          $display("sucess in i ");
          $display("t7.i= %d",t7.i);
          $display("t8.i= %d",t8.i);
      end
   else
     begin
     $display("Failure in i ");
    $display("t7.i= %d",t7.i);
    $display("t8.i= %d",t8.i);
     end

  if(t7.y==t8.y)
    begin
        $display("sucess in y ");
          $display("t7.y= %d",t7.y);
          $display("t8.y= %d",t8.y);
   end
  else
    begin
          $display("Failure in y ");
          $display("t7.y= %d",t7.y);
          $display("t8.y= %d",t8.y);
    end
  no_of_transfer++;
  
   if(no_of_transfer>10)
      begin
        ->DONE;
      end
 endtask

endclass

//environment class

class evironment;
 
 mailbox #(trans)gen2drv;
 mailbox #(trans)mon2ref;
 mailbox #(trans)rmon2sb;
 mailbox #(trans)ref2sb;

 virtual inter.RMN duv2rmon;
 virtual inter.WMN duv2wmon;
 virtual inter.WDR drv2duv;

 generator gen_h;
 write_drv drv_h;
 write_mon wmon_h;
 read_mon rmon_h;
 referance ref_h;
 scoreboard sb_h;

 function new(virtual inter.RMN duv2rmon,
 virtual inter.WMN duv2wmon,
 virtual inter.WDR drv2duv);
  this.duv2rmon=duv2rmon;
  this.duv2wmon=duv2wmon;
  this.drv2duv=drv2duv;
  gen2drv=new();
  mon2ref=new();
  ref2sb=new();
  rmon2sb=new();
 endfunction

 
 task build;
  gen_h=new(gen2drv); 
  drv_h=new(drv2duv,gen2drv);
  wmon_h=new(duv2wmon,mon2ref);
  rmon_h=new(duv2rmon,rmon2sb);
  ref_h=new(ref2sb,mon2ref);
  sb_h=new(ref2sb,rmon2sb);
 endtask

 task start;
   gen_h.start();
   drv_h.start();
   wmon_h.start();
   rmon_h.start(); 
   ref_h.start();
   sb_h.start();
   stop();
 endtask

 task stop;
  wait(sb_h.DONE.triggered);
    $finish;
 endtask

 endclass

//test class

class test;

 evironment env_h;
 
 virtual inter.RMN duv2rmon;
 virtual inter.WMN duv2wmon;
 virtual inter.WDR drv2duv;

 function new(virtual inter.RMN duv2rmon,
 virtual inter.WMN duv2wmon,
 virtual inter.WDR drv2duv);
  this.duv2rmon=duv2rmon;
  this.duv2wmon=duv2wmon;
  this.drv2duv=drv2duv;
  env_h=new(duv2rmon,duv2wmon,drv2duv);
 endfunction


task build_run;
  env_h.build();
  env_h.start();
 endtask

endclass

//top module 
module priority_encoder_tb();
 inter ino();
 test test_h;
 
 priority_encoder DUV(.i(ino.i),.y(ino.y));

 initial
  begin
    test_h=new(ino,ino,ino);
    test_h.build_run();
  end
endmodule

module priority_encoder(i,y);
  input [3:0]i;
  output reg[1:0]y;

  always@(*)
   begin
     casex(i)
       4'b1xxx :y='b11;
       4'bx1xx :y='b10;
       4'bxx1x :y='b01;
       4'bxxx1 :y='b00;
       default: y='bz;
    endcase
  end
endmodule

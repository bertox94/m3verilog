`timescale 1ns / 1ps

//data bits 8, no parity, always lsb first (don't mention this last however)
module UART_Module(
    reset,
    clk_baud,
    clk_baud_ds,
    uart_rx,
    uart_tx,
    uart_tx_pkt,
    uart_rx_pkt,
    uart_h_tx_pkt,
    uart_h_rx_pkt,
    out_bit_tx,
    in_bit_rx,
    fixed_error,
    unfixable_error  
);
    
   
    input                   clk_baud;
    input                   clk_baud_ds;
    input                   uart_rx;
    input   reg             uart_tx;
    input                   reset;
            reg[8:1]        tmp_u;
            reg[13:1]       tmp_h;
    output  reg[8:1]        uart_tx_pkt;
    output  reg[8:1]        uart_rx_pkt;
    output  reg[13:1]       uart_h_tx_pkt;
    output  reg[13:1]       uart_h_rx_pkt;
            logic [1:0]     FIRST_u='d0, WORK_u='d1, LAST_u='d2; 
            logic [1:0]     ss_u, ss_u_next;
            logic [1:0]     FIRST_h='d0, WORK_h='d1, LAST_h='d2; 
            logic [1:0]     ss_h, ss_h_next;
            logic           valid_u;
            logic           valid_h;
            int             cnt_u;
            int             cnt_h;
    output  reg             out_bit_tx;
    input   reg             in_bit_rx;
            logic           valid_u_tmp;
            logic           valid_h_tmp;
    output  logic           unfixable_error;
    output  logic           fixed_error;
    
    logic valid_to_send_h = 0;
    int count_h = 0;
    logic valid_to_send_u = 0;
    int count_u = 0;    
    
    always @ (posedge reset) begin
		
		uart_tx = 1;
		
		tmp_u = 0;
		tmp_h = 0;
		
		uart_tx_pkt = 0;
		uart_rx_pkt = 0;
		
		uart_h_tx_pkt = 0;
		uart_h_rx_pkt = 0;
		
		ss_u = FIRST_u;
		ss_u_next = FIRST_u;
		ss_h = FIRST_h;
        ss_h_next = FIRST_h;
		
		valid_u = 0;
		valid_h = 0;
		
		cnt_u = 0;
		cnt_h = 0;
		
        out_bit_tx = 1;
        in_bit_rx = 1;
		
        valid_u_tmp = 0;
        valid_h_tmp = 0;
		
		unfixable_error = 0;
		fixed_error = 0;
		
    end 
    
    

    always @(posedge clk_baud, posedge reset) begin
        if(~reset) begin
			ss_u = ss_u_next;
			
			case(ss_u)
				FIRST_u: begin
					if(valid_u_tmp) begin
						uart_rx_pkt = tmp_u;
						valid_u = 1;
						valid_u_tmp = 0;
						$write("%c",uart_rx_pkt);
					end
					
					cnt_u = 1;
					tmp_u = 0;
					if(uart_rx == 1) begin
						ss_u_next = FIRST_u;
					end
					else begin
						ss_u_next = WORK_u;
					end
				end
				WORK_u: begin
					cnt_u++;
					tmp_u >>= 1;
					tmp_u |= (uart_rx << 7);
					if(cnt_u <= 8) begin
						ss_u_next = WORK_u;
					end
					else begin
						ss_u_next = LAST_u;
					end
				end
				LAST_u: begin
					cnt_u++;		         
					valid_u_tmp = 1;
					ss_u_next = FIRST_u;
				end
			endcase
        end
    end   
    
    always @(posedge valid_u, posedge reset) begin
        if(~reset) begin       

			automatic int j = 1;
			automatic int k = 1;
			automatic int counter = 0;
					
			for(int i = 1; i <= 12; i++)begin
				if(i != j) begin
					uart_h_tx_pkt[i] = uart_rx_pkt[k];
					k++;
				end else begin
					uart_h_tx_pkt[i] = 0;
					j <<= 1;
				end
			end
			
			for(int i = 1; i <= 12; i <<= 1) begin
				for(int j = i; j <= 12; j+=2*i) begin
					for(int k = 0; k < i && j+k <= 12; k++) begin
						counter += uart_h_tx_pkt[j+k];
					end
				end
	
				if(counter%2)
					uart_h_tx_pkt[i] = 1;
	
				counter = 0;
			end  
			
			counter = 0;
			for(int i = 1; i<=12; i++) begin
				counter += uart_h_tx_pkt[i];
			end
			
			if(counter%2)
				uart_h_tx_pkt[13] = 1;
			else 
				uart_h_tx_pkt[13] = 0;
			valid_to_send_h = 1;
	/*		out_bit_tx = 0;                                      
			for(int i = 1; i<=13; i++) begin
				@ (posedge clk_baud_ds) out_bit_tx = uart_h_tx_pkt[i];
			end
			@ (posedge clk_baud_ds) out_bit_tx = 1;
	*/		
		    valid_u = 0;
		end
    end
    
    always@(posedge clk_baud_ds) begin
        if(valid_to_send_h) begin
            if(count_h==0) begin
                out_bit_tx = 0;
                count_h ++;
            end else if(count_h < 14) begin
                out_bit_tx = uart_h_tx_pkt[count_h];
                count_h ++;
            end else begin
                out_bit_tx = 1;
                count_h = 0;
                valid_to_send_h = 0;
            end
        end      
    end
    
    
    

    always @(posedge clk_baud_ds, posedge reset) begin
        if(~reset) begin
			ss_h = ss_h_next;
			
			case(ss_h)
				FIRST_h: begin
					if(valid_h_tmp) begin
						uart_h_rx_pkt = tmp_h;
						valid_h = 1;
						valid_h_tmp = 0;
					end
					
					cnt_h = 1;
					tmp_h = 0;
					if(in_bit_rx == 1) begin
						ss_h_next = FIRST_h;
					end
					else begin
						ss_h_next = WORK_h;
					end
				end
				WORK_h: begin
					cnt_h++;
					tmp_h >>= 1;
					tmp_h |= (in_bit_rx << 12);
					if(cnt_h <= 13) begin
						ss_h_next = WORK_h;
					end
					else begin
						ss_h_next = LAST_h;
					end
				end
				LAST_h: begin
					cnt_h++;		         
					valid_h_tmp = 1;
					ss_h_next = FIRST_h;
				end
			endcase
        end
    end
      
   
    always @(posedge valid_h, posedge reset) begin
        if(~reset) begin       
			automatic int       j = 1;
			automatic int       k = 1;
			automatic int       counter = 0;
			automatic reg[12:1] mask = 0;
			automatic int       position = 0;
			automatic reg       parity = 0;
			
			fixed_error = 0;
			unfixable_error = 0;
	
			for(int i = 1; i <= 12; i <<= 1) begin
				for(int j = i; j <= 12; j+=2*i) begin
					for(int k = 0; k < i && j+k <= 12; k++) begin
						counter += uart_h_rx_pkt[j+k];
					end
				end
	
				if(counter%2)
					mask[i] = 1;
	
			     counter = 0;
			end  
			
			
			
			//detection of error       
			for(int i = 1; i<=12; i++) begin
				if(mask[i])
					position += i;
			end
			
			for(int i = 1; i<=13; i++) begin
			    counter += uart_h_rx_pkt[i];
			end	
			
			if(counter%2)
				parity = 1;



            //attempt to fix errors			
			if(position == 0) begin
				if(parity) begin
					//OK bit 13 is removed anyway
					fixed_error = 1;
				end
			end else begin
				if(parity) begin
					uart_h_rx_pkt[position] = ~ uart_h_rx_pkt[position];
					fixed_error = 1;
				end else begin
					unfixable_error = 1;
				end
			end

		
			j = 1;
			k = 1;
			for(int i = 1; i<=12; i++) begin
			if(i == j) begin
				j <<= 1;
			end else begin
				uart_tx_pkt[k]= uart_h_rx_pkt[i];
				k++;
				end
			end
/*		
			uart_tx = 0;                                      
			for(int i = 1; i<=8; i++) begin
				@ (posedge clk_baud) uart_tx = uart_tx_pkt[i];
			end

			@ (posedge clk_baud) uart_tx = 1;
*/		    
		    valid_to_send_u = 1;
		    valid_h = 0;
		end
    end
    
    always@(posedge clk_baud) begin
        if(valid_to_send_u) begin
            if(count_u==0) begin
                uart_tx = 0;
                count_u ++;
            end else if(count_u < 9) begin
                uart_tx = uart_tx_pkt[count_u];
                count_u ++;
            end else begin
                uart_tx = 1;
                count_u = 0;
                valid_to_send_u = 0;
            end
        end      
    end

endmodule

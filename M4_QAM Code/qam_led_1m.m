clear all;
close all;
clc;%clear all stored variables
Rb=1e3;
Fc=2*Rb;
nSamps = 32; %Sampling rate - 16
Fs = Rb * nSamps;
Ts=1/Fs; %Sampling period
Tb=1/Rb; %bit period
amplitude=0.5;%data pulse amplitude
amplitude_sq=1;%square pulse amplitude
mlevel = 4; % size of signal constellation
k = log2(mlevel); % number of bits per symbol 
N = 248; %248; 504;
Nt = 256; %256; 512;
Spulse=[0,0,0,1,1,1,1,0];
% signal generation in bit stream
Resamp_rate = (Nt*nSamps)/2;
%data = [1,0,0,1,1,0,0,0,1,0,1,1,1,0,0,0,1,0,1,1];
data = randn(1,N)>=0;
data = reshape(data,1,N);
data_i = [Spulse data];
data_i = reshape(data_i,Nt,1);
%data_i = rot90(data_i,3);
ber = [];


% convert the bit stream into symbol stream
Spulsesym = bi2de(reshape(Spulse,k,length(Spulse)/k).','left-msb');
datasym = bi2de(reshape(data,k,length(data)/k).','left-msb');
% modulation
datamod = qammod(datasym,mlevel);
i_datamod = real(datamod);
q_datamod = imag(datamod);
rpi_datamod = rectpulse(i_datamod,nSamps)*amplitude;
rpq_datamod = rectpulse(q_datamod,nSamps)*amplitude;

Spulsemod = qammod(Spulsesym,mlevel);
i_Spulsemod = real(Spulsemod);
q_Spulsemod = imag(Spulsemod);
rpi_Spulsemod = rectpulse(i_Spulsemod,nSamps)*amplitude_sq;
rpq_Spulsemod = rectpulse(q_Spulsemod,nSamps)*amplitude_sq;

i_tmpdata = vertcat(rpi_Spulsemod,rpi_datamod);
i_tmpdata = rot90(i_tmpdata);
q_tmpdata= vertcat(rpq_Spulsemod,rpq_datamod);
q_tmpdata = rot90(q_tmpdata);

evenTime=0:Ts:Tb*(length(i_Spulsemod)+length(i_datamod))-Ts;
oddTime=0:Ts:Tb*(length(q_Spulsemod)+length(q_datamod))-Ts;

inPhaseOsc = cos(2*pi*Fc*evenTime); 
quadPhaseOsc = sin(2*pi*Fc*oddTime); 

baseband = i_tmpdata.*inPhaseOsc-q_tmpdata.*quadPhaseOsc;
datastr = round(baseband*1000)/(1000*max(baseband));


generatorUploader(datastr);
for i=1:1:1
    receivedi = led_oscilloscopeDataReader;
    %figure(1)
    %subplot(3,1,1); plot(datastr)
    %subplot(3,1,2); 
    %plot(receivedi)
    keyboard
    tf = isempty(receivedi);
        if tf == false
            received = receivedi;
            received = received.*(1);
            %subplot(3,1,3); 
            plot(received)    
            thrs = min(received(1:5000))-0.4;
            thre = min(received(5001:end))-0.4;
            index_sqrs = find(received>thrs);
            index_sqre = find(received>thre);
                if ~isempty(index_sqrs) && ~isempty(index_sqre)
    
                    data_start = find(index_sqrs>300);
                    data_start = find(index_sqrs<3000);
            
                    % finding the end of data
                    data_end = find(index_sqre<8900);
                    data_end = find(index_sqre>7000);
                    
                  if numel(data_start)~=0 && numel(data_end)~=0
                    data_start = data_start(1);
                    data_start = index_sqrs(data_start)
                    data_end = data_end(1);
                    data_end = index_sqre(data_end)
         
                    r = received(data_start:data_end);
                    
                        if (length(r)>5500 && length(r)<7500)
                            l = length(r)
                            Resamp_rate
                            r_r = resample(r,Resamp_rate,l);

                            iSignal = r_r.*inPhaseOsc; 
                            qSignal = r_r.*quadPhaseOsc; 

                            ri_data = intdump(iSignal,nSamps);
                            rq_data = intdump(qSignal,nSamps);

                            Rx_x = complex((ri_data),(-rq_data))*max(baseband);
                            %demodulation
                            Rx_x_demod = qamdemod(Rx_x,mlevel,pi);
                            z = de2bi(Rx_x_demod,'left-msb'); % Convert integers to bits.
                            % Convert z from a matrix to a vector.
                            Rx_x_BitStream = reshape(z.',prod(size(z)),1);
                            %Calculate BER
                            %[number_of_errors,bit_error_rate] = biterr(data_i(9:end),Rx_x_BitStream(9:end))
                             ber = [ber biterr(data_i(9:end),Rx_x_BitStream(9:end))]
                        else
                                fprintf('Bad Triggering \n');
                            	ber = [ber 510];
                            end
                    else
                         fprintf('null matrix \n');
                         ber = [ber 509];
                        end
        else 
            fprintf('Bad Thresold \n');
            ber = [ber 511];
                end
    else
    fprintf('Bad Data Redaing \n');
    ber = [ber 512];
        end
 %csvwrite('LED_2QAM_SINGLE_BIT_STR_1m_32sps12_256kbps.dat',ber);
end
a=vertcat(Spulsemod,datamod);
figure(2)
subplot(2,1,1); plot(real(a),imag(a),'go','MarkerFaceColor',[0,1,0]);
                     axis([-mlevel/2 mlevel/2 -mlevel/2 mlevel/2]);title('Tx');
subplot(2,1,2); plot(real(Rx_x),imag(Rx_x),'go','MarkerFaceColor',[0,1,0]);
                     axis([-mlevel/10 mlevel/10 -mlevel/10 mlevel/10]);title('Rx');
grid;
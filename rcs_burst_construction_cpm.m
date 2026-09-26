function [segments, burst_info] = rcs_burst_construction_cpm(data_bits, params)
%cpm突发构造，比特域进行
%按照DVB-RCS标准sec7.3.6.2
%UW|DATA|尾符号|UW（中导码）|DATA|尾符号

data_bits = data_bits(:);
n_data_bits = length(data_bits);
n_midamble_bits = params.cpm_midamble_len;
n_data1 = params.cpm_data1_len

if n_data1 > n_data_bits
    n_data1 = n_data_bits;
end

n_data2 = n_data_bits - n_data1;

uw_hex = params.uw_hex;
uw_bits = hex_to_bits(uw_hex);

data1_bits = data_bits(1:n_data1);

if n_data2 > 0
    data2_bits = data_bits(n_data1+1:end);
else
    data2_bits = [];
end

segments = {uw_bits, data1_bits, uw_bits, data2_bits};

burst_info.n_preamble_bits = length(uw_bits);
burst_info.n_data1 = n_data1;
burst_info.n_data2 = n_data2;
burst_info.n_midamble_bits = n_midamble_bits;
burst_info.n_segments = length(segments);
burst_info.total_bits = length(uw_bits)+n_data1+n_data2;
end

function bits = hex_to_bits(hex_str)
n_hex = length(hex_str);
bits = zeros(n_hex * 4, 1);
for i = 1:n_hex
    val = sscanf(hex_str(i), '%x');
    bits((i-1)*4+1:i*4) = bitget(val, 4:-1:1);
end
end




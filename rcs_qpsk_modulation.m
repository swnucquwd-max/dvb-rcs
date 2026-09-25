function symbols = rcs_qpsk_modulation(bits)

%采用DVB-RCS标准 采用Gray编码的绝对映射QPSK调制
%比特x映射到I路，比特y映射到Q路
%星座点采用单位平均功率缩放

%星座映射规则 
%0 0 ->(+sqrt(2)/2 +sqrt(2)/2)
%0 1 ->(-sqrt(2)/2 +sqrt(2)/2)
%1 1 ->(-sqrt(2)/2 -sqrt(2)/2)
%1 0 ->(+sqrt(2)/2 -sqrt(2)/2)

bits = bits(:);

if mod(length(bits), 2) ~= 0
    bits = [bits ; 0];%补零对齐
    warning('crc_qpsk_modulation: 输入比特数据为奇数，已补零对齐');
end

n_symbols = length(bits)/2;

x_bits = bits(1:2:end);

y_bits = bits(2:2:end);

I = 1 - 2 * x_bits;
Q = 1 - 2 * y_bits;

symbols = (I + 1j*Q) / sqrt(2);%功率归一化

end


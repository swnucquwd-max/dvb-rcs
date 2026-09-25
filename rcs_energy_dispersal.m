function scrambled_data = rcs_energy_dispersal(data)
%DVB-RCS能量扩散

data = data(:);%确保列向量
data_len = length(data);

poly = [15 14 0];%生成多项式

init_state = [1 0 0 1 0 1 0 1 0 0 0 0 0 0 0];

%生成PRBS序列

prbs_seq = prbs_generator(data_len, poly, init_state);

%模二加

scrambled_data = mod(data + prbs_seq,2);

end
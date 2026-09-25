function [burst_signal, burst_info] = rcs_burst_construction(symbols, params)
%突发构造 插入导频 前导码

symbols = symbols(:);
n_data = length(symbols);

burst_type = params.burst_type;

n_preamble = params.preamble_len;

pilot_period = params.pilot_period;

pilot_block_len = 4;%导频符号数
m = params.mod_order;

preamble_bits = generate_pn_sequence(n_preamble*m);

preamble_symbols = rcs_modulation(preamble_bits, params);
preamble_symbols = preamble_symbols(1:n_preamble);

pilot_symbols = rcs_modulation(zeros(m,1), params);
pilot_symbols = pilot_symbols(1)*ones(pilot_block_len, 1);

n_pilot_blocks = floor(n_data / pilot_period);
if n_data >pilot_period * n_pilot_blocks
    n_pilot_blocks = n_pilot_blocks+1;
end

total_pilot_symbols = n_pilot_blocks *pilot_block_len;
total_data_plus_pilot = total_pilot_symbols + n_data;


burst_data = zeros(total_data_plus_pilot, 1);

pilot_indices = [];

data_indices = [];

data_idx = 1;

burst_idx = 1;

for block = 1:n_pilot_blocks
    chunk_len = min(pilot_period, n_data - data_idx+1);
    if chunk_len <= 0
        break;
    end

    burst_data(burst_idx:burst_idx + chunk_len-1) = symbols(data_idx:data_idx + chunk_len-1);

    data_indices = [data_indices; (burst_idx:burst_idx+chunk_len-1)'];

    burst_idx = burst_idx + chunk_len;
    data_idx = data_idx + chunk_len;

    burst_data(burst_idx:burst_idx +pilot_block_len-1) = pilot_symbols;

    pilot_indices = [pilot_indices; (burst_idx:burst_idx+pilot_block_len-1)'];

    burst_idx = burst_idx + pilot_block_len;

end

%处理剩余数据
if data_idx <= n_data
    remaining = n_data - data_idx +1;
    burst_data(burst_idx:burst_idx+remaining-1) = symbols(data_idx, n_data);
    data_indices = [data_indices; (burst_idx:burst_idx+remaining-1)'];
    burst_idx = burst_idx + remaining;
end

burst_data = burst_data(1:burst_idx-1);

%组装完整突发
burst_signal = [preamble_symbols; burst_data];

pilot_indices = pilot_indices + n_preamble;
data_indices = data_indices + n_preamble;

burst_info.preamble_idx = (1:n_preamble)';
burst_info.pilot_indices = pilot_indices;
burst_info.data_indices = data_indices;
burst_info.total_symbols = length(burst_signal);
burst_info.n_preamble = n_preamble;
burst_info.n_pilots = total_pilot_symbols;
burst_info.n_data = n_data;

end

function pn = generate_pn_sequence(n_bits)

poly = [8, 7, 0];

init_state = [0 0 0 0 0 0 0 1];

pn = prbs_generator(n_bits, poly, init_state);

end




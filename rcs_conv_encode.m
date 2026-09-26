function conv_out = rcs_conv_encode(data, conv_params)
%DVB-RCS2 CC-CPM 卷积编码

K = conv_params.K;
g = conv_params.g(:).';
rate = conv_params.target_rate;
data = data(:);
n_tail = K - 1;                      % K=3 -> 2, K=4 -> 3
data = [data; zeros(n_tail, 1)];


g_bin = cell(1, 2);
for i = 1:2
    g_bin{i} = oct2bin(g(i), K);
end

n_bits = numel(data);
reg = zeros(1, K - 1);
mother_out = zeros(2 * n_bits, 1);

for i = 1:n_bits
    for j = 1:2
        acc = data(i);
        for k = 1:(K - 1)
            if g_bin{j}(k + 1) == 1
                acc = mod(acc + reg(k), 2);
            end
        end
        mother_out(2 * i - 2 + j) = acc;
    end
    reg = [data(i), reg(1:end-1)];
end


pattern = select_puncture_pattern(K, rate);
if all(pattern == 1)
    conv_out = mother_out;                       % 1/2 码率：不穿刺
else
    conv_out = apply_puncture(mother_out, pattern);
end
conv_out = double(conv_out(:));

end


% ======================================================================
function pattern = select_puncture_pattern(K, rate)
table = { ...
    '1/2', [1 1],                       [1 1]; ...
    '2/3', [1 1 0 1],                   [1 1 1 0]; ...
    '3/4', [1 1 0 1 1 0],               [1 1 1 0 0 1]; ...
    '4/5', [1 1 0 1 1 0 1 0],           [1 1 0 1 1 0 1 0]; ...
    '6/7', [1 1 0 1 1 0 1 0 1 0 1 0],   [1 1 0 1 0 1 0 1 1 0 1 0]};
values = [1/2, 2/3, 3/4, 4/5, 6/7];

if ischar(rate) || isstring(rate)
    idx = find(strcmp(table(:, 1), strtrim(char(rate))), 1);   % 字符串码率
else
    idx = find(abs(values - double(rate)) < 1e-9, 1);          % 数值码率
end
if K == 3
    pattern = table{idx, 2};
else
    pattern = table{idx, 3};
end
pattern = double(pattern(:));
end


% ======================================================================
function punctured = apply_puncture(mother_bits, pattern)
mother_bits = mother_bits(:);
pattern = pattern(:);
P = numel(pattern);
n = numel(mother_bits);
keep = repmat(pattern, ceil(n / P), 1);
keep = keep(1:n);
punctured = mother_bits(keep == 1);
end


% ======================================================================
function bin = oct2bin(oct_val, n_bits)
str = num2str(oct_val);
dec_val = 0;
for i = 1:numel(str)
    dec_val = dec_val * 8 + str2double(str(i));
end
bin = zeros(1, n_bits);
for i = n_bits:-1:1
    bin(n_bits - i + 1) = mod(floor(dec_val / 2^(i - 1)), 2);
end
end

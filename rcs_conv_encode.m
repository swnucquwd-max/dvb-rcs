function conv_out = rcs_conv_encode(data, conv_params)
%DVB-RCS卷积编码

%母码码率 1/6
%约束长度 K=7（64种状态）
%生成多项式 G1 = 171（8进制） G2 = 133(8进制)
%通过打孔 实现码率 1/2 2/3 3/4 5/6

if nargin < 2
    conv_params.g1 = 171;
    conv_params.g2 = 133;
    conv_params.K = 7;
    conv_params.mother_rate = 1/6;
    conv_params.target_rate = 1/2;
end
g1_oct = conv_params.g1;
g2_oct = conv_params.g2;
K = conv_params.K;



target_rate = conv_params.target_rate;

data = data(:);
%根据约束长度添加尾比特
%K = 3添加2个0 K=4添加3个0
if K == 3
    data = [data;0;0];
else
    data = [data;0;0;0];
end

data_len = length(data);

g1_bin = oct2bin(g1_oct, K);
g2_bin = oct2bin(g2_oct, K);

reg = zeros(1, K-1);

mother_out = zeros(data_len*2, 1);

for i = 1:data_len
    %计算X输出：输入与G1的摸2卷积
    x_out = data(i);
    for j = 1:(K-1)
        if g1_bin(j+1) == 1
            x_out = mod(x_out + reg(j), 2);
        end
    end

    %计算Y输出：输入与G2的模2卷积
    y_out = data(i);
    for j = 1:(K-1)
        if g2_bin(j+1) == 1
            y_out = mod(y_out + reg(j), 2);
        end
    end
    %更新移位寄存器
    reg = [data(i), reg(1:end-1)];

    %输出X和Y
    mother_out(2*i-1) = x_out;
    mother_out(2*i) = y_out;
end

%打孔
if target_rate == 0.5
    conv_out = mother_out;
elseif target_rate == 2/3
    puncture_pattern = [1;1;1;0];
    conv_out = apply_puncture(mother_out, puncture_pattern, data_len);
elseif target_rate == 3/4
    puncture_pattern = [1;1;1;0;0;1];
    conv_out = apply_puncture(mother_out, puncture_pattern, data_len);  
elseif target_rate == 5/6
    puncture_pattern = [1;1;1;0;0;1;1;0;0;1];
    conv_out = apply_puncture(mother_out, puncture_pattern, data_len);  
else
    error('码率不支持');
end

conv_out = conv_out(:);

end

function bin = oct2bin(oct_val, n_bits)

dec_val = 0;
oct_str = num2str(oct_val);
for i = 1:length(oct_str)
    digit = str2double(oct_str(i));
    dec_val = dec_val*8+digit;
end
bin =  zeros(1, n_bits);

for i = n_bits:-1:1
    bin(n_bits-i+1) = mod(floor(dec_val/ 2^(i-1)), 2);
end

end

function punctured = apply_puncture(mother_bits, pattern, n_info_bits)

pattern_len = length(pattern);
mother_bits = mother_bits(:);
pattern = pattern(:);

n_blocks = ceil(length(mother_bits) / pattern_len);

total_out = sum(pattern)*n_blocks;%floor((length(mother_bits)/2)/target_rate);
punctured = zeros(total_out, 1);

out_idx = 1;

for i = 1:pattern_len:length(mother_bits)
    block_end = min(i+pattern_len-1,length(mother_bits));
    block = mother_bits(i:block_end);

    for j = 1:length(block)
        if j <= pattern_len && pattern(j) == 1
            punctured(out_idx) = block(j);
            out_idx = out_idx+1;
        end
    end

end

punctured = punctured(1:out_idx-1);

end



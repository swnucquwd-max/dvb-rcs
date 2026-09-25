function turbo_out = rcs_turbo_encode(data, turbo_params)
%按照标准 ETSI EN 301 545-2 SEC 7.3.5.1

%实现双二进制循环递归系统卷积turbo编码

%分量编码器：16状态
%反馈多项式：1+x^3+x^4 = 23(8进制)
%Y校验多项式：1+x+x^2+x^4 = 35(8进制)
%W校验多项式：1+x^2+x^3+x^4 = 27(8进制)
%双二进制：每次梳理2个比特
%两条支路，自然顺序编码+交织后编码
%通过打孔实现不同码率：1/3 2/5 1/2 2/3 3/4 4/5 6/7
poly_fb = cell2mat(turbo_params.poly(1));
poly_y = cell2mat(turbo_params.poly(2));
poly_w = cell2mat(turbo_params.poly(3));
n_states = turbo_params.n_states;
target_rate = turbo_params.target_rate;

data = data(:);
data_len = length(data);

if mod(data_len, 2)~= 0
    data = [data;0];
    data_len = data_len + 1;
end

N_pairs = data_len/2;%比特对数

fb_bin = oct2bin_vec(poly_fb, 5);
y_bin = oct2bin_vec(poly_y, 5);
w_bin = oct2bin_vec(poly_w, 5);

N_inner = N_pairs;

if ~isempty(turbo_params.N_inner)
    N_inner = turbo_params.N_inner;
end

[R_rows, C_cols] = select_interleaver_params(N_inner);

perm_table = build_dvbs_interleaver(N_inner, R_rows, C_cols);

[sys_nat, y_nat, w_nat] = crsc_encode(data, N_pairs, fb_bin, y_bin, w_bin);

data_int = interleave_data(data, perm_table, N_pairs);
[sys_int, y_int, w_int] = crsc_encode(data_int, N_pairs, fb_bin, y_bin, w_bin);

sys_bits = sys_nat(:);

y_nat_bits = y_nat(:);
w_nat_bits = w_nat(:);
y_int_bits = y_int(:);
w_int_bits = w_int(:);

mother_out = zeros(N_pairs * 6, 1);

for i = 1:N_pairs
    idx = (i-1)*6;
    mother_out(idx+1) = sys_bits(2*i-1);
    mother_out(idx+2) = sys_bits(2*i);
    mother_out(idx+3) = y_nat_bits(2*i-1);
    mother_out(idx+4) = w_nat_bits(2*i);
    mother_out(idx+5) = y_int_bits(2*i-1);
    mother_out(idx+6) = w_int_bits(2*i);
end

if target_rate == '1/3'
    conv_out = mother_out;
elseif target_rate == '2/5'
    %每5个母码比特保留2个系统比特+2个校验 打孔模式每6个一组
    puncture_pattern = [1; 1; 1; 0; 1; 0];
    conv_out = apply_turbo_puncture(mother_out, puncture_pattern, N_pairs);
elseif target_rate == '1/2'
    puncture_pattern = [1; 1; 1; 0; 0; 1];
    conv_out = apply_turbo_puncture(mother_out, puncture_pattern, N_pairs);
elseif target_rate == '2/3'
    puncture_pattern = [1; 1; 1; 0; 1; 0];
    conv_out = apply_turbo_puncture(mother_out, puncture_pattern, N_pairs);
elseif target_rate == '3/4'
    puncture_pattern = [1; 1; 1; 0; 0; 0];
    conv_out = apply_turbo_puncture(mother_out, puncture_pattern, N_pairs)
elseif target_rate == '4/5'
    puncture_pattern = [1; 1; 1; 0; 0; 0];
    conv_out = apply_turbo_puncture(mother_out, puncture_pattern, N_pairs);
elseif target_rate == '6/7'
    puncture_pattern = [1; 1; 1; 0; 0; 0];
    conv_out = apply_turbo_puncture(mother_out, puncture_pattern, N_pairs);
else
    error('target_rate error');
end

turbo_out = conv_out(:);

end


function [sys_out, y_out, w_out] = crsc_encode(data, N_pairs, fb_bin, y_bin, w_bin)
n_regs = 4;

sys_out = zeros(2 * N_pairs, 1);
y_out = zeros(2 * N_pairs, 1);
w_out = zeros(2 * N_pairs, 1);

state = zeros(1, n_regs);

for i = 1:N_pairs
    a = data(2*i-1);
    b = data(2*i);

    input_a = a;

    fb_val = input_a;

    for j = 1:n_regs
        if fb_bin(j+1) == 1
            fb_val = mod(fb_val + state(j), 2);
        end
    end

    y_val = fb_val;
    for j = 1:n_regs
        if y_bin(j+1) == 1
            y_val = mod(y_val + state(j), 2);
        end
    end
    w_val = fb_val;
    for j = 1:n_regs
        if w_bin(j+1) == 1
            w_val = mod(w_val + state(j), 2);
        end
    end

    state = [fb_val, state(1:n_regs-1)];

    sys_out(2*i-1) = a;
    y_out(2*i-1) = y_val;
    w_out(2*i-1) = w_val;

    input_b = mod(b+state(1) + state(3), 2);

    fb_val = input_b;

    for j = 1:n_regs
        if fb_bin(j+1) == 1
            fb_val = mod(fb_val + state(j), 2);
        end
    end

    y_val = fb_val;
    for j = 1:n_regs
        if y_bin(j+1) == 1
            y_val = mod(y_val + state(j), 2);
        end
    end
    w_val = fb_val;
    for j = 1:n_regs
        if w_bin(j+1) == 1
            w_val = mod(w_val + state(j), 2);
        end
    end
    state = [fb_val, state(1:n_regs-1)];

    sys_out(2*i) = b;
    y_out(2*i) = y_val;
    w_out(2*i) = w_val;

end
end

function data_int = interleave_data(data, perm_table, N_pairs)

data_int = zeros(2*N_pairs,1);
for i = 1:N_pairs
    new_idx = perm_table(i)+1;
    data_int(2*new_idx-1) = data(2*i-1);
    data_int(2*new_idx) = data(2*i);
end
end

function [R, C] = select_interleaver_params(N)

candidates = [18, 20, 22, 24, 26, 28, 30, 32, 36, 40, 44, 48, 52, 56, 60, 64, ...
    72, 80, 88, 96, 104, 112, 120, 128, 144, 160, 176, 192, 208, 224, 240, 256];

C = candidates(end);

for k = 1:length(candidates)
    if candidates(k) >= N
        C = candidates(k);
        break;
    end
end
R = ceil(N / C);
if R < 2
    R = 2;
end
end

function perm = build_dvbs_interleaver(N, R, C)
matrix = -1*ones(R, C);

idx = 0;

for r = 1:R
    for c = 1:C
        if idx < N
            matrix(r, c) = idx;
            idx = idx+1;
        end
    end
end

perm = zeros(1, N);
out_idx = 0;
for c = 1:C
    for r = 1:R
        if matrix(r, c)>=0
            perm(out_idx + 1) = matrix(r, c);
            out_idx = out_idx + 1;
        end
    end
end

end

function bin = oct2bin_vec(oct_val, n_bits)

dec_val = 0;
oct_str = num2str(oct_val);
for i = 1:length(oct_str)
    digit = str2double(oct_str(i));
    dec_val = dec_val * 8+ digit;
end

bin = zeros(1,n_bits);

for i = n_bits:-1:1
    bin(n_bits-i+1) = mod(floor(dec_val / 2^(i-1)), 2);
end

end

function punctured = apply_turbo_puncture(mother_bits, pattern, n_pairs)

pattern_len = length(pattern);
mother_bits = mother_bits(:);
pattern = pattern(:);

bit_per_pair = 6;
total_mother = n_pairs * bit_per_pair;

punctured = [];

for i = 1:pattern_len:total_mother
    block_end = min(i + pattern_len - 1, total_mother);
    block = mother_bits(i:block_end);
    for j = 1:length(block)
        if j <= pattern_len && pattern(j) == 1
            punctured = [punctured; block(j)];
        end
    end
end

punctured = punctured(:);

end








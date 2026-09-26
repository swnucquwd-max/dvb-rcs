function [symbols, cpm_info] = rcs_cpm_modulation(bits, params, terminate)
%RCS_CPM_MODULATION DVB-RCS2 CC-CPM 调制器（ETSI EN 301 545-2 §7.3.7.2）
%
%   s(t) = exp(j*phi(t)),  phi(t) = 2*pi*h*sum_i a_i*q(t - i*Ts)
%   q_AV(t) = aRC*q_RC(t) + (1-aRC)*q_REC(t)                （§7.3.7.2.1）
%   a_i ∈ {±1, ±3}（数据符号，M=4）；h = mh/ph
%
%   比特→符号（§7.3.7.2.2）
%     h  = 1/3  : 表 7-23  标签 0/1/2/3 -> -3 / -1 / +1 / +3
%     h ≠ 1/3  : 表 7-24  （Gray）标签 0/1/2/3 -> -3 / -1 / +3 / +1
%     若比特数不是 log2(M) 的整数倍，末尾补 0 比特后再映射。
%
%   相位网格终止（§7.3.7.2.3）
%     相位状态 Vn = mod(sum(a_i), ph)（数据符号之和，模 ph 加法器）。
%     依 ph 查表 7-25~7-28 得到尾符号 t0,t1(,t2)，这些值直接作为调制器输入
%     符号送入相位累加器，表的结构保证 mod(Vn + sum(t), ph) = 0，
%     即把调制器驱回全零状态（末位恒为 0，同时清零 L=2 的相关状态）。
%     ★ 尾符号与数据符号用【同一个】相位公式连续累加，相位在边界处连续。
%
% 输入
%   bits      信息比特（列向量，0/1）
%   params    需要字段：cpm_M cpm_L cpm_mod_index_h cpm_mh cpm_ph
%             cpm_alpha_rc cpm_samples_per_sym（缺省有默认值）
%   terminate true → 末尾追加尾符号；false → 只输出数据段（默认 false）
%
% 输出
%   symbols   复基带采样（列向量），每符号 cpm_samples_per_sym 个采样
%   cpm_info  结构体，主要字段：
%     n_symbols / n_term / n_symbols_total
%     data_labels      数据符号标签（0..3），terminate 时不含尾符号
%     term_values      尾符号调制器输入值（长度 n_term）
%     term_alpha       同 term_values（兼容旧字段名）
%     term_symbols     尾符号采样（长度 n_term*sps）
%     term_phase       尾符号相位（长度 n_term*sps）
%     phase_trace      全部采样相位
%     alpha_values     送入调制器的完整符号序列 [数据 a_i, 尾符号 t]
%     Vn               数据段结束时的相位状态
%     Vn_end           终止后的相位状态（正常应为 0）
%     mapping 'h=1/3: table 7-23' 或 'h~=1/3: table 7-24'
%     h M L samples_per_sym q_func g_func
%
% See also RCS_BURST_CONSTRUCTION_CPM, GET_RCS_PARAMS, DVB_RCS_MAIN.

%% ---------------- 参数与默认值 ----------------
if ~isfield(params, 'cpm_mod_index_h') || isempty(params.cpm_mod_index_h)
    params.cpm_mod_index_h = 1/3;
end
if ~isfield(params, 'cpm_mh') || isempty(params.cpm_mh), params.cpm_mh = 1; end
if ~isfield(params, 'cpm_ph') || isempty(params.cpm_ph), params.cpm_ph = 3; end
if ~isfield(params, 'cpm_M')  || isempty(params.cpm_M),  params.cpm_M  = 4; end
if ~isfield(params, 'cpm_L')  || isempty(params.cpm_L),  params.cpm_L  = 2; end
if ~isfield(params, 'cpm_alpha_rc') || isempty(params.cpm_alpha_rc)
    params.cpm_alpha_rc = 1;
end
if ~isfield(params, 'cpm_samples_per_sym') || isempty(params.cpm_samples_per_sym)
    params.cpm_samples_per_sym = 32;
end
if nargin < 3 || isempty(terminate)
    terminate = false;
end

M  = params.cpm_M;
L  = params.cpm_L;
h  = params.cpm_mod_index_h;
mh = params.cpm_mh;
ph = params.cpm_ph;
alpha_rc = params.cpm_alpha_rc;
sps = params.cpm_samples_per_sym;

bits = bits(:);
bits_per_symbol = log2(M);
n_bits = numel(bits);
n_symbols = ceil(n_bits / bits_per_symbol);
pad_len = n_symbols * bits_per_symbol - n_bits;
if pad_len > 0
    bits = [bits; zeros(pad_len, 1)];       % §7.3.7.2.2：末尾补 0 比特
end
bit_groups = reshape(bits, bits_per_symbol, n_symbols).';
label = bit_groups(:, 1) * 2 + bit_groups(:, 2);     % 2 bit 标签 0..3

%% ---------------- 标签 -> 符号值（表 7-23 / 7-24）----------------
if M ~= 4
    error('rcs_cpm_modulation:M', '仅实现 M = 4（CC-CPM）');
end
if abs(h - 1/3) < 1e-12
    tab = [-3, -1, 1, 3];                   % 表 7-23
    mapping = 'h=1/3: table 7-23';
else
    tab = [-3, -1, 3, 1];                   % 表 7-24（Gray）
    mapping = 'h~=1/3: table 7-24';
end
alpha_data = tab(label + 1).';
alpha_data = alpha_data(:).';

%% ---------------- 相位响应 ----------------
% q(t)：0 (t<0)；RC t/4 - sin(pi t)/(4pi)、REC t/4 (0<=t<=2Ts)；t>2Ts 时 0.5
q_rc_func  = @(t) (t/4 - sin(pi * t) / (4 * pi)) .* (t >= 0 & t <= 2) + 0.5 * (t > 2);
q_rec_func = @(t) (t/4)                          .* (t >= 0 & t <= 2) + 0.5 * (t > 2);
q_func     = @(t) alpha_rc * q_rc_func(t) + (1 - alpha_rc) * q_rec_func(t);
g_rc_func  = @(t) (1/4) * (1 - cos(pi * t)) .* (t > 0 & t < 2);
g_rec_func = @(t) (1/4) * (t > 0 & t < 2);
g_av_func  = @(t) alpha_rc * g_rc_func(t) + (1 - alpha_rc) * g_rec_func(t);

%% ---------------- 相位状态 → 尾符号（表 7-25~7-28）----------------
Vn = mod(sum(alpha_data), ph);
[term_values, n_term] = get_trellis_termination(Vn, ph, M);

use_term = terminate && (n_term > 0);
if use_term
    alpha_all = [alpha_data, term_values];
else
    alpha_all = alpha_data;
end
Vn_end = mod(sum(alpha_all), ph);

%% ---------------- 统一相位累加（数据 + 尾符号连续）----------------
phase_all = cpm_phase_trace(alpha_all, h, sps, q_func);
symbols   = exp(1j * phase_all);

if use_term
    term_phase   = phase_all(n_symbols * sps + 1:end);
    term_symbols = exp(1j * term_phase);
    n_term_used  = n_term;
    n_symbols_total = n_symbols + n_term;
else
    term_phase   = [];
    term_symbols = [];
    n_term_used  = 0;
    n_symbols_total = n_symbols;
end

%% ---------------- 输出 ----------------
cpm_info.n_symbols       = n_symbols;
cpm_info.n_symbols_total = n_symbols_total;
cpm_info.n_term          = n_term_used;
cpm_info.n_bits          = n_bits;
cpm_info.data_labels     = label(:).';
cpm_info.term_values     = term_values;      % 尾符号调制器输入值
cpm_info.term_alpha      = term_values;      % 兼容旧字段名
cpm_info.term_phase      = term_phase;
cpm_info.term_symbols    = term_symbols;     % 尾符号采样（旧拼写 terms_symbols 已修）
cpm_info.phase_trace     = phase_all;
cpm_info.alpha_values    = alpha_all;
cpm_info.Vn              = Vn;
cpm_info.Vn_end          = Vn_end;
cpm_info.mapping         = mapping;
cpm_info.h               = h;
cpm_info.M               = M;
cpm_info.L               = L;
cpm_info.mh              = mh;
cpm_info.ph              = ph;
cpm_info.alpha_rc        = alpha_rc;
cpm_info.samples_per_sym = sps;
cpm_info.q_func          = q_func;
cpm_info.g_func          = g_av_func;

if use_term && Vn_end ~= 0
    warning('rcs_cpm_modulation:term', ...
            '相位网格终止失败：Vn=%d, ph=%d, 尾符号=%s', Vn, ph, mat2str(term_values));
end
end


% ======================================================================
function phase = cpm_phase_trace(alpha, h, sps, q_func)
%CPM_PHASE_TRACE 标准 CPM 相位轨迹 phi(t) = 2*pi*h*sum_j alpha_j*q(t-(j-1))
%   alpha_j 是调制器输入符号（数据为 ±1/±3，尾符号为表 7-25~7-28 的值）。
%   t-(j-1) > 2 的“久远符号”其 q 恒为 0.5，用前缀和一次加上，
%   复杂度 ~O(n*sps*3)，与逐符号全量累加结果完全一致。
alpha = alpha(:).';
n = numel(alpha);
csum = [0, cumsum(alpha)];              % csum(m) = sum(alpha(1:m-1))
phase = zeros(n * sps, 1);
for s = 1:n
    for k = 1:sps
        t = (s - 1) + (k - 1) / sps;              % 绝对时间（单位：符号周期 Ts）
        j0 = max(1, ceil(t - 1));                 % t-(j-1) <= 2 的最早符号下标
        acc = 0;
        for j = j0:s
            acc = acc + alpha(j) * q_func(t - (j - 1));
        end
        acc = acc + 0.5 * csum(j0);               % j < j0 的符号：q = 0.5
        phase((s - 1) * sps + k) = 2 * pi * h * acc;
    end
end
end


% ======================================================================
function [term_values, n_term] = get_trellis_termination(Vn, ph, M)
%GET_TRELLIS_TERMINATION 表 7-25~7-28：相位状态 Vn 与 ph -> 尾符号
%   表项为调制器输入值，满足 mod(Vn + sum(t), ph) = 0（全零状态）。
if M ~= 4
    error('rcs_cpm_modulation:M', '表 7-25~7-28 仅定义 M = 4');
end
switch ph
    case 7
        table = [0 0 0; 3 3 0; 3 2 0; 3 1 0; 3 0 0; 2 0 0; 1 0 0];
    case 5
        table = [0 0 0; 3 1 0; 3 0 0; 2 0 0; 1 0 0];
    case 4
        table = [0 0; 3 0; 2 0; 1 0];
    case 3
        table = [0 0; 2 0; 1 0];
    otherwise
        error('rcs_cpm_modulation:ph', ...
              'ph = %d 无相位终止表（表 7-25~7-28 仅覆盖 7/5/4/3）', ph);
end
if Vn < 0 || Vn > size(table, 1) - 1
    error('rcs_cpm_modulation:Vn', 'Vn = %d 超出 ph = %d 的状态范围', Vn, ph);
end
term_values = table(Vn + 1, :);
n_term = numel(term_values);
end

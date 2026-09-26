function params = get_rcs_params(burst_type, coding_scheme, waveform_cfg)
%GET_RCS_PARAMS 汇总 DVB-RCS2（EN 301 545-2 V1.3.1）返回链路仿真参数
% 码率、调制方式/映射等全部直接取自内置参考波形表（RCS_WAVEFORM_TABLE）中
% waveform_id 对应的那一行，不读取外部文件，也不对参数做推断/适配。
%
% 输入
%   burst_type     'TRF' | 'ACQ' | 'SYNC' | 'CSC'
%   coding_scheme  'concatenated'(CC-CPM，表 A-3) | 'turbo'(TC-LM，表 A-1)
%   waveform_cfg   可选结构体：waveform_id（默认 1）；并可用同名字段覆盖
%                  preamble_len postamble_len pilot_period pilot_block_len
%                  pilot_sum payload_symbols uw_hex
%
% 输出（节选）
%   waveform_id code_rate code_rate_num code_rate_den code_rate_str   ——直接查表
%   mod_order mod_name                                               ——直接查表（A-1）
%   conv_params: g1 g2 K mother_rate(=1/2) target_rate；conv_tail_bits
%   cpm_*: M L mh ph cpm_mod_index_h alpha_rc data1_len data2_len term_symbols
%   突发构造参数：preamble_len postamble_len pilot_period pilot_block_len
%                 pilot_sum payload_symbols burst_symbol_length uw_hex
%
% See also RCS_WAVEFORM_TABLE, RCS_CONV_ENCODE, RCS_TURBO_ENCODE, CHECK_PARAMS_TABLE.

if nargin < 3 || isempty(waveform_cfg)
    waveform_cfg = struct();
end
if ~isfield(waveform_cfg, 'waveform_id') || isempty(waveform_cfg.waveform_id)
    waveform_cfg.waveform_id = 1;
end

%% ---------------- 编码方案 -> 参考波形表 ----------------
params.burst_type    = upper(burst_type);
params.coding_scheme = lower(coding_scheme);
switch params.coding_scheme
    case 'turbo'
        params.mod_type = 'linear';
        fmt = 'A1';
    case 'concatenated'
        params.mod_type = 'cpm';
        fmt = 'A3';
    otherwise
        error('get_rcs_params:scheme', 'coding_scheme 只能为 concatenated 或 turbo');
end

%% ---------------- 查内置参考波形表 ----------------
T   = rcs_waveform_table(fmt);
wid = waveform_cfg.waveform_id;
k   = find([T.id] == wid, 1);
if isempty(k)
    error('get_rcs_params:waveform', '表 %s 无 waveform_id = %d（可用: %s）', fmt, wid, mat2str([T.id]));
end
w = T(k);
params.waveform_id = wid;

%% ---------------- 码率：直接查表所得 ----------------
params.code_rate_str = w.code_rate;              % 表里的码率字符串原样使用
rp = sscanf(params.code_rate_str, '%d/%d');      % 仅把表里的 'n/m' 拆成分子/分母
params.code_rate_num = rp(1);
params.code_rate_den = rp(2);
params.code_rate     = rp(1) / rp(2);

%% ---------------- 逐表取参数 ----------------
if strcmp(params.mod_type, 'cpm')
    params.mod_order           = [];             % CC-CPM 无线性调制阶数
    params.mod_name            = 'CC-CPM (M=4)';
    params.mapping             = w.cc_type;
    params.cpm_M               = w.M;
    params.cpm_L               = w.L;
    params.cpm_mh              = w.mh;
    params.cpm_ph              = w.ph;
    params.cpm_mod_index_h     = w.h;
    params.cpm_alpha_rc        = w.alpha_rc;
    params.cpm_rolloff         = 0.4;
    params.cpm_samples_per_sym = 32;
    params.cpm_data1_len       = w.data1_bits;
    params.cpm_data2_len       = w.data2_bits;
    params.cpm_term_bits       = w.term_bits;
    params.cpm_term_symbols    = w.term_symbols;
    params.uw_hex              = w.uw_hex;
    params.preamble_len        = 64;
    params.cpm_midamble_len    = 64;
    params.pilot_period        = 0;
    params.pilot_block_len     = 0;
    params.pilot_sum           = 0;
    params.payload_symbols     = (w.data1_bits + w.data2_bits) / log2(w.M);
    params.burst_symbol_length = w.burst_symbols;
else
    params.mod_order           = w.mod_order;    % 直接查表
    params.mod_name            = w.mapping;
    params.mapping             = w.mapping;
    params.preamble_len        = w.preamble_len;
    params.postamble_len       = w.postamble_len;
    params.pilot_period        = w.pilot_period;
    params.pilot_block_len     = w.pilot_block;
    params.pilot_sum           = w.pilot_sum;
    params.payload_symbols     = w.payload_symbols;
    params.burst_symbol_length = w.burst_symbols;
    params.uw_hex              = w.uw_hex;
end

%% ---------------- 允许逐项覆盖（仅突发构造相关）----------------
ovr = {'preamble_len', 'postamble_len', 'pilot_period', 'pilot_block_len', ...
       'pilot_sum', 'payload_symbols', 'uw_hex'};
for i = 1:numel(ovr)
    f = ovr{i};
    if isfield(waveform_cfg, f) && ~isempty(waveform_cfg.(f))
        params.(f) = waveform_cfg.(f);
    end
end

%% ---------------- CRC 类型（§7.3.4）----------------
switch params.burst_type
    case 'TRF'
        params.crc_type = 'crc32';
    otherwise
        params.crc_type = 'crc16';
end

%% ---------------- 卷积码（CC-CPM，§7.3.5.2）----------------
% 母码率固定 1/2；K∈{3,4} 与生成多项式 (5,7)o / (15,17)o 一一绑定（查表）
params.conv_mother_rate = 1/2;
params.conv_K    = 3;
params.conv_g1   = 5;      % 1 + x^2（八进制字面值）
params.conv_g2   = 7;      % 1 + x + x^2
params.conv_cc_type = '(5,7)o';
if strcmp(params.mod_type, 'cpm') && w.K == 4
    params.conv_K  = 4;
    params.conv_g1 = 15;   % 1 + x + x^3
    params.conv_g2 = 17;   % 1 + x + x^2 + x^3
    params.conv_cc_type = '(15,17)o';
end
params.conv_tail_bits = params.conv_K - 1;     % 2 或 3（§7.3.5.2.2）
params.conv_params.g           = [params.conv_g1, params.conv_g2];
params.conv_params.g1          = params.conv_g1;
params.conv_params.g2          = params.conv_g2;
params.conv_params.K           = params.conv_K;
params.conv_params.mother_rate = 1/2;
params.conv_params.target_rate = params.code_rate_str;   % 直接来自参考波形表

%% ---------------- Turbo（TC-LM，§7.3.5.1）----------------
params.turbo_K        = 5;              % 4 级寄存器
params.turbo_n_states = 16;
params.turbo_polys    = {23 35 27};     % 反馈 23o、Y 35o、W 27o
params.turbo_params.poly        = params.turbo_polys;
params.turbo_params.n_states    = params.turbo_n_states;
params.turbo_params.target_rate = params.code_rate_str;  % 直接来自参考波形表
params.turbo_params.N_inner     = [];

%% ---------------- MODCOD 组合校验（§7.3.7.1.4）----------------
if ~isempty(params.mod_order) && params.mod_order == 3 && params.code_rate < 2/3
    error('get_rcs_params:modcod', '8PSK 要求码率 ≥ 2/3');
end
if ~isempty(params.mod_order) && params.mod_order == 4 && params.code_rate < 3/4
    error('get_rcs_params:modcod', '16QAM 要求码率 ≥ 3/4');
end
end

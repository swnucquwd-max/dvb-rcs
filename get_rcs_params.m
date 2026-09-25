function params = get_rcs_params(burst_type, code_rate, coding_scheme, mod_order, waveform_cfg)
% input
%params结构体包含以下字段
%burst_type 突发类型 'TRF' 'ACQ' 'SYNC' 'CSC'
%code_rate 码率 '1/2' '2/3' '3/4' '5/6' '1/3'
%coding_scheme 编码方案 'concatenated'或'turbo'
%mod_order 调制阶数 '1->pi/2 BPSK 2->QPSK 3->8PSK 4->16QAM' '8psk码率大于等于2/3' '16QAM码率大于等于3/4'

%waveform_cfg  波形配置结构体，字段可选
%waveform_id 参考波形ID号
%preamble_len 前导码长度
%pilot_period 导频周期
%pilot_block_len 导频块长度
%payload_symbols 数据符号数


%output:
%burst_type 突发类型
%code_rate 码率值
%code_rate_num 码率分子
%code_rate_den 码率分母
%coding_scheme  编码方案
%conv_g1 卷积编码生成多项式1 八进制
%conv_g2 卷积编码生成多项式2 八进制
%conv_k 卷积编码约束长度
%conv_mother_rate 母码码率
%preamble_len 前导码长度
%pilot_period 导频周期
%pilot_block_len 导频块长度
%payload_symbols 数据符号数
%mod_order 调制阶数
%mod_name  调制方式名称



rate_parts = sscanf(code_rate, '%d/%d');
if length(rate_parts) == 2
    params.code_rate_num = rate_parts(1);
    params.code_rate_den = rate_parts(2);
    params.code_rate = rate_parts(1)/rate_parts(2);
end
params.burst_type = upper(burst_type);
params.coding_scheme = lower(coding_scheme);

mod_name = {'pi/2-BPSK','QPSK','8PSK','16QAM'};
params.mod_order = mod_order;
params.mod_name = mod_name{mod_order};


switch lower(coding_scheme)
    case 'turbo'
        params.mod_type = 'linear';
    case 'concatenated'
        params.mod_type = 'cpm';
    otherwise
        params.mod_type = 'linear';
end

if strcmp(params.mod_type, 'cpm')
    %table A-3
    if isfield(waveform_cfg,'preamble_len') && ~isempty(waveform_cfg,preamble_len)
        params.preamble_len = waveform_cfg.preamble_len;
    else
        params.preamble_len = 64;
        waveform_cfg.waveform_id = 1;
        waveform_cfg.payload_symbols = 526;
        params.uw_hex = '7CD593ADF7818AC8';
    end
    params.pilot_period = 0;
    params.pilot_block_len = 0;
    params.payload_symbols = waveform_cfg.payload_symbols;
else
    %用waveform id 1尝试
    params.preamble_len = 155;
    params.postamble_len = 27;
    params.pilot_period = 18;
    params.pilot_block_len = 1;
    params.pilot_sum = 26;
    params.uw_hex = '3300FC0FF3C33CCFFF0300C0FCF300CCCCCF0CFFC3C3F00CFCC0F33FF0CC0F00F030F330CFFF00F030F330CFFF00';
   % [params.preamble_len, params.postamble_len, params.pilot_period, params.pilot_block_len, params.uw_hex, params.pilot_sum] = 
   % get_waveform_by_id(waveform_cfg.waveform_id);
   % params.waveform_id = waveform_cfg.waveform_id;
end
params.conv_g1 = 171;
params.conv_g2 = 133;
params.conv_K = 4;
params.conv_mother_rate = 1/6;


params.turbo_K = 5;%约束长度
params.turbo_n_states = 16;
params.turbo_polys = {23 35 27};

switch upper(burst_type)
    case 'TRF'
        params.crc_type = 'crc32';
    case {'ACQ','SYNC','CSC'}
        params.crc_type = 'crc16';
    otherwise
        params.crc_type = 'crc16';
end

params.cpm_M = 4; %4进制字母变
params.cpm_L = 2; %记忆长度
params.cpm_mod_index_h = 1/3; %调制指数h = mh/ph
params.cpm_mh = 1;
params.cpm_ph = 3;
params.cpm_alpha_rc = 1; %AV脉冲RC分量系数
params.cpm_rolloff = 0.4;% RC脉冲滚降系数


params.cpm_data1_len = 64;
params.cpm_midamble_len = 64;
params.cpm_samples_per_sym = 32;
params.conv_params.g1 = params.conv_g1;
params.conv_params.g2 = params.conv_g2;
params.conv_params.K = params.conv_K;
params.conv_params.mother_rate = params.conv_mother_rate;
params.conv_params.target_rate = params.code_rate;

params.turbo_params.poly = params.turbo_polys;
params.turbo_params.n_states = params.turbo_n_states;
params.turbo_params.target_rate = params.code_rate;
params.turbo_params.N_inner = [];


%码率验证
valid_rates_concatenated = {'1/2','2/3','3/4','5/6'};

valid_rates_turbo = {'1/3','2/5','1/2','2/3','3/4','5/6','6/7'};

switch params.coding_scheme
    case 'concatenated'
        if ~ismember(code_rate, valid_rates_concatenated);
            error('valid_rates_concatenated error');
        end
    case 'turbo'
        if ~ismember(code_rate, valid_rates_turbo);
            error('valid_rates_turbo error');
        end
end

%8PSK 码率大约2/3
%16QAM 码率大于等于3/4

switch params.mod_order
    case 3
        if params.code_rate < 2/3
            error ('8PSK Code_rate > 2/3');
        end
    case 4
        if params.code_rate < 3/4
            error ('16QAM Code_rate >= 3/4');
        end
end

end
%function [preamble_len, postamble_len, pilot_period, pilot_block_len, uw_hex, waveform_id, pilot_sum] = get_waveform_by_id(waveform_id)









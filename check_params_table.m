function check_params_table()
%CHECK_PARAMS_TABLE 校验 get_rcs_params 的参数（码率、调制方式…）是否全部直接来自参考波形表
%   get_rcs_params(burst_type, coding_scheme, waveform_cfg) —— 码率与调制方式不由入参给出
addpath('D:\于敏\DVB-RCS');
ok = true;

%% A-3（CC-CPM）20 行
T = rcs_waveform_table('A3');
bad = {};
for k = 1:numel(T)
    p = get_rcs_params('TRF', 'concatenated', struct('waveform_id', T(k).id));
    rp = sscanf(T(k).code_rate, '%d/%d');
    g = strcmp(p.code_rate_str, T(k).code_rate) && ...
        isequal(p.code_rate_num, rp(1)) && isequal(p.code_rate_den, rp(2)) && ...
        abs(p.code_rate - rp(1)/rp(2)) < 1e-12 && ...
        strcmp(p.conv_params.target_rate, T(k).code_rate) && ...
        isequal(p.waveform_id, T(k).id) && isequal(p.cpm_ph, T(k).ph) && ...
        isempty(p.mod_order) && isequal(p.conv_K, T(k).K);
    if ~g, bad{end+1} = sprintf('A3 id=%d', T(k).id); end
end
okA = isempty(bad);
if ~okA, fprintf('  A-3 mismatch: %s\n', strjoin(bad, ', ')); end
fprintf('A-3 %2d rows  rate/K/ph/waveform_id from table            %s\n', numel(T), pf(okA));
ok = ok && okA;

%% A-1（TC-LM）34 行
T1 = rcs_waveform_table('A1');
bad = {};
for k = 1:numel(T1)
    p = get_rcs_params('TRF', 'turbo', struct('waveform_id', T1(k).id));
    g = strcmp(p.code_rate_str, T1(k).code_rate) && ...
        strcmp(p.turbo_params.target_rate, T1(k).code_rate) && ...
        isequal(p.waveform_id, T1(k).id) && ...
        isequal(p.mod_order, T1(k).mod_order) && ...
        strcmp(p.mod_name, T1(k).mapping);
    if ~g, bad{end+1} = sprintf('A1 id=%d(%s/%s)', T1(k).id, T1(k).code_rate, p.code_rate_str); end
end
okB = isempty(bad);
if ~okB, fprintf('  A-1 mismatch: %s\n', strjoin(bad, ', ')); end
fprintf('A-1 %2d rows  rate/mod_order/mod_name from table          %s\n', numel(T1), pf(okB));
ok = ok && okB;

%% 突发符号长度自洽：burst = pre + post + pilot_sum*pilot_block + payload
bad = 0;
for k = 1:numel(T1)
    w = T1(k);
    p = get_rcs_params('TRF', 'turbo', struct('waveform_id', w.id));
    s = p.preamble_len + p.postamble_len + p.pilot_sum*p.pilot_block_len + p.payload_symbols;
    bad = bad + (s ~= p.burst_symbol_length);
end
okC = (bad == 0);
fprintf('A-1 突发符号长度构成自洽（34 行，不符 %d 行）              %s\n', bad, pf(okC));
ok = ok && okC;

%% 不存在的 waveform_id 必须报错
threw = false;
try
    get_rcs_params('TRF', 'concatenated', struct('waveform_id', 999));
catch ME
    threw = strcmp(ME.identifier, 'get_rcs_params:waveform');
end
fprintf('guard: 不存在的 waveform_id 报错                            %s\n', pf(threw));
ok = ok && threw;

fprintf('\nTOTAL: %s\n', pf(ok));
if ~ok, error('check_params_table:fail', 'parameter table check failed'); end
end

function s = pf(c)
if c, s = '[OK]'; else, s = '[FAIL]'; end
end

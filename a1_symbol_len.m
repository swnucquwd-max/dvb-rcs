function a1_symbol_len()
%A1_SYMBOL_LEN 核算表 A-1 的突发符号长度构成（以 waveform_id=1 为例，并逐行验证规律）
addpath('D:\于敏\DVB-RCS');
T = rcs_waveform_table('A1');
fprintf('id  pre post per blk psum  payload  burst   pre+post+psum*blk+payload  floor(pay/(per-blk))\n');
bad1 = 0; bad2 = 0;
for k = 1:numel(T)
    w = T(k);
    sum1 = w.preamble_len + w.postamble_len + w.pilot_sum*w.pilot_block + w.payload_symbols;
    if w.pilot_period > 0
        p2 = floor(w.payload_symbols / (w.pilot_period - w.pilot_block));
    else
        p2 = 0;
    end
    ok1 = (sum1 == w.burst_symbols);
    ok2 = (p2 == w.pilot_sum);
    bad1 = bad1 + ~ok1; bad2 = bad2 + ~ok2;
    if k <= 6 || ~ok1 || ~ok2
        fprintf('%2d  %3d %4d %3d %3d %4d  %7d %6d  %7d %s   %4d %s\n', ...
            w.id, w.preamble_len, w.postamble_len, w.pilot_period, w.pilot_block, ...
            w.pilot_sum, w.payload_symbols, w.burst_symbols, sum1, tf(ok1), p2, tf(ok2));
    end
end
fprintf('\n合计 %d 行：burst = pre+post+pilot_sum*pilot_block+payload 不符 %d 行；\n', numel(T), bad1);
fprintf('          pilot_sum = floor(payload/(pilot_period-pilot_block)) 不符 %d 行\n', bad2);

w = T(1);
fprintf('\n--- waveform_id = 1 (QPSK, rate 1/3) ---\n');
fprintf('burst_symbols = %d(前导) + %d(数据) + %d(后导) + %d(%d 个导频块 x %d 符号) = %d\n', ...
    w.preamble_len, w.payload_symbols, w.postamble_len, w.pilot_sum*w.pilot_block, ...
    w.pilot_sum, w.pilot_block, w.burst_symbols);
fprintf('导频块数 = floor(%d / (%d - %d)) = %d\n', w.payload_symbols, w.pilot_period, w.pilot_block, w.pilot_sum);
fprintf('数据段比特数 = %d 符号 x log2(%d) = %d bit\n', w.payload_symbols, 2^w.mod_order, w.payload_symbols*w.mod_order);
fprintf('净荷占比 = %d/%d = %.1f%%；开销 = %d 符号（前导+后导+导频）\n', ...
    w.payload_symbols, w.burst_symbols, 100*w.payload_symbols/w.burst_symbols, ...
    w.preamble_len + w.postamble_len + w.pilot_sum*w.pilot_block);
end

function s = tf(c)
if c, s = 'OK'; else, s = 'X'; end
end

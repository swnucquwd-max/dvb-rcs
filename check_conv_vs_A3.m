function report = check_conv_vs_A3()
%CHECK_CONV_VS_A3 用内置表 A-3 逐条校验 rcs_conv_encode 的位预算（不读外部文件）
%   对 20 条 CC-CPM 参考波形：以 fec_input_bits 长度的随机比特编码，
%   比较输出长度与表中 fec_output_bits；全部吻合返回 true。

T = rcs_waveform_table('A3');
rng(7);
fprintf('id  K  rate  in_bit   A-3 out   enc out   结果\n');
pass = 0;
for k = 1:numel(T)
    p = struct('K', T(k).K, 'target_rate', T(k).code_rate, 'mother_rate', 1/2);
    if p.K == 3
        p.g = [5 7];
    else
        p.g = [15 17];
    end
    out = rcs_conv_encode(randi([0 1], T(k).fec_input_bits, 1), p);
    ok = (numel(out) == T(k).fec_output_bits);
    pass = pass + ok;
    if ok
        flag = 'OK';
    else
        flag = 'FAIL';
    end
    fprintf('%2d  %d  %-4s  %6d  %8d  %8d  %s\n', T(k).id, p.K, p.target_rate, ...
        T(k).fec_input_bits, T(k).fec_output_bits, numel(out), flag);
end
fprintf('\n吻合 %d/%d 条\n', pass, numel(T));
report = (pass == numel(T));
end

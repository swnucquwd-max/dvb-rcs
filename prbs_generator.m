function seq = prbs_generator(len, poly, init_state)
% 基于线性反馈移位器生成PRBS序列，然后对数据进行模二加

reg_len = max(poly);
reg = init_state(:).';

if length(reg) < reg_len
    reg = [reg, zeros(1, reg_len - length(reg))];
elseif length(reg) > reg_len
    reg = reg(1:reg_len);
end

seq = zeros(len, 1);

taps = poly(2:end);

has_output_feedback = any(taps == 0)

taps = taps(taps > 0);

for i = 1:len
    seq(i) = reg(end);

    feed_back = 0;

    if has_output_feedback

        feed_back = reg(end);
    end

    for j = 1:length(taps)
        feed_back = xor(feed_back, reg(taps(j)));
    end

    reg = [feed_back, reg(1:end-1)];

end
end
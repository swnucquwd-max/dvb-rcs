function [I_mf, Q_mf, h_srrc] = rcs_matched_filter(I_in, Q_in, rolloff, sps)
span = 10;%滤波器跨度符号数
n_taps = span * sps + 1;%滤波器长度

t = (-(n_taps-1)/2):((n_tap-1)/2)/sps;

%SRRC脉冲响应

h_srrc = zeros(size(t));

for i = 1:length(t)
    if t(i) == 0
        h_srrc(i) = 1-rolloff + 4*rolloff/pi;
    elseif abs(abs(t(i)) - 1/(4*rolloff)) <1e-10
        h_srrc(i) = rolloff/sqrt(2) * ((1+2/pi)*sin(pi/(4*rolloff))+(1-2/pi)*cos(pi/(4*rolloff)));
    else
        num = sin(pi*t(i)*(1-rolloff)) +4*rolloff*t(i)*cos(pi*t(i)*(1+rolloff));
        den = pi*t(i)*(1-(4*rolloff*t(i))^2);
        h_srrc(i) = num/den;
    end
end
%能量归一化
h_srrc = h_srrc/sqrt(sum(h_srrc.^2));

%匹配滤波

I_in = I_in(:);
Q_in = Q_in(:);

I_mf = filter(h_srrc, 1, I_in);
Q_mf = filter(h_srrc, 1, Q_in);

delay = floor(n_taps/2);

I_mf = [I_mf(delay+1:end);zeros(delay,1)];
Q_mf = [Q_mf(delay+1:end);zeros(delay,1)];

end


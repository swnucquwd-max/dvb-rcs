function [I_shaped, Q_shaped, h_rrc] = baseband_shaping(I, Q, rolloff, sps)
%采用根升余弦SRRC滤波器对I/Q数据 进行脉冲成型

%滤波器参数
filter_span = 10;
n_taps = filter_span + sps + 1;

t = (-filter_span/2 : 1/sps: filter_span/2);

h_rrc = zeros(size(t));

alpha = rolloff;

for i = 1:length(t)

    tn = t(i);

    if abs(tn) < 1e-10 %t=0
        h_rrc(i) = 1 - alpha + 4*alpha/pi;
    elseif abs(abs(tn) - 1/(4*alpha)) < 1e-10 && alpha > 0%t = +-(t_S/alpha)
        h_rrc(i) = alpha/sqrt(2)*((1+2/pi)*sin(pi/(4*alpha))+(1-2/pi)*cos(pi/(4*alpha)));
    else
        num = sin(pi*tn*(1-alpha)) + 4*alpha*tn.*cos(pi*tn*(1+alpha));
        den = pi*tn.*(1-(4*alpha*tn).^2);
        h_rrc(i) = num./den;
    end
end

%归一化
h_rrc = h_rrc/sqrt(sum(h_rrc.^2));

%上采样
I_upsampled = upsample(I(:).', sps).';
Q_upsampled = upsample(Q(:).', sps).';

I_shaped = filter(h_rrc, 1, I_upsampled);
Q_shaped = filter(h_rrc, 1, Q_upsampled);

delay = floor(length(h_rrc) / 2);

I_shaped = [I_shaped(delay+1 : end); zeros(delay, 1)];
Q_shaped = [Q_shaped(delay+1 : end); zeros(delay, 1)];

end


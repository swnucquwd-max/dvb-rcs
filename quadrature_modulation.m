function rf_signal = quadrature_modulation(I, Q, fc, fs)

%将I/Q两路基带数据加到正交载波上，生成高频信号
%S(t) = I(t) * cos(2*pi*fc*t) - Q(t) * sin(2*pi*fc*t)

if fs <= 2 * fc
    warning('采样率 fs = %d 应大于 2*fc=%d 已满足Nyquist准则', fs, 2*fc);
end

N = length(I);

t = (0:N-1).' / fs;

rf_signal = I .* cos(2*pi*fc*t) - Q .* sin(2*pi*fc*t);

end
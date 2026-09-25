function [I_bb, Q_bb] = rcs_quadrature_demod(rf_signal, fc, fs)

rf_signal = rf_signal(:);
n_samples = length(rf_signal);

if fs<2*fc
    error('fs < 2*fc');
end
%正交下变频
t = (0:n_samples)'/fs;

cos_lo = cos(2*pi*fc*t);
sin_lo = sin(2*pi*fc*t);

I_mixed = rf_signal .* cos_lo;
Q_mixed = -rf_signal .* sin_lo;

%低通滤波器

f_cutoff = 1.5e6;
order = 6;
Wn = f_cutoff/(fs/2);

if Wn>=1
    Wn = 0.99;
end

[b, a] = butter(order, Wn);

%零相位滤波(消除相位延迟)
I_bb = filtfilt(b, a, I_mixed);
Q_bb = filtfilt(b, a, Q_mixed);

end
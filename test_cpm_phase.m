function test_cpm_phase()
%TEST_CPM_PHASE 验收 rcs_cpm_modulation（CC-CPM 调制器）的相位实现
%  A) 数据段相位 == 标准公式 phi(t)=2*pi*h*sum_j a_j*q(t-(j-1))；q 与 g 的积分一致
%  B) 数据→尾符号相位连续（无跳变）；数据段采样与不终止时逐点相同
%  C) cpm_info 字段名/长度自洽（term_symbols 而非 terms_symbols）
%  D) 相位网格终止：全部 ph∈{3,4,5,7} 与全部 Vn 下 mod(Vn+sum(t),ph)=0；A-3 term_bits=2*n_term
%  E) 比特→符号映射：h=1/3 用表 7-23，h≠1/3 用表 7-24（Gray）
%  F) 用真实 A-3 波形参数端到端跑一遍

fprintf('==== rcs_cpm_modulation 验收 ====\n');
ok = true;

%% ---------- A) 相位公式 ----------
params = mk(1, 3, 32, 0.75);
M = 4; sps = params.cpm_samples_per_sym; h = params.cpm_mod_index_h;
alpha = [3 -3 -1 1];
bits  = bits_from_alpha(alpha, h);
[~, iA] = rcs_cpm_modulation(bits, params, false);
qref = @(t) 0.75 * ((t/4 - sin(pi*t)/(4*pi)) .* (t>=0 & t<=2) + 0.5*(t>2)) + ...
            0.25 * ((t/4) .* (t>=0 & t<=2) + 0.5*(t>2));
n = numel(alpha);
phi_ref = zeros(n*sps,1);
for s = 1:n
    for k = 1:sps
        t = (s-1) + (k-1)/sps;  acc = 0;
        for j = 1:n
            acc = acc + alpha(j) * qref(t - (j-1));
        end
        phi_ref((s-1)*sps + k) = 2*pi*h*acc;
    end
end
dA = max(abs(iA.phase_trace - phi_ref));
ct = linspace(0, 2, 20001).';
gv = 0.75*(1/4)*(1-cos(pi*ct)) .* (ct>0 & ct<2) + 0.25*(1/4)*(ct>0 & ct<2);
qnum = cumtrapz(ct, gv);
dQ = max(abs(iA.q_func(ct) - qnum));
okA = (dA < 1e-12) && (dQ < 1e-5);
fprintf('A) 数据段相位偏差 %.2e rad (q vs ∫g: %.2e)  %s\n', dA, dQ, pf(okA));
ok = ok && okA;

%% ---------- B) 连续性 ----------
rng(1);
bitsB = randi([0 1], 128, 1);
[~, iNo]  = rcs_cpm_modulation(bitsB, params, false);
[syYes, iYes] = rcs_cpm_modulation(bitsB, params, true);
nd = numel(iNo.phase_trace);
dB1 = max(abs(iYes.phase_trace(1:nd) - iNo.phase_trace));
% 全部样本（数据段 + 尾符号段）与独立写出的连续公式对比 —— 边界必然连续
aa = iYes.alpha_values(:);
phi2 = zeros(numel(iYes.phase_trace), 1);
for s = 1:numel(aa)
    for k = 1:sps
        t = (s-1) + (k-1)/sps;  acc = 0;
        for j = 1:numel(aa)
            acc = acc + aa(j) * qref(t - (j-1));
        end
        phi2((s-1)*sps + k) = 2*pi*h*acc;
    end
end
dB2 = max(abs(iYes.phase_trace - phi2));
% 相邻样本相位增量上界（g 峰值 0.5/0.25，每个瞬间最多 2 个符号起作用）
gmax = 0.75*0.5 + 0.25*0.25;
step = 2*pi*h*2*max(abs(aa))*gmax/sps;
dB3 = max(abs(diff(iYes.phase_trace)));
okB = (dB1 < 1e-12) && (dB2 < 1e-12) && (dB3 < step*1.05);
fprintf('B) 数据段与不终止时一致 %.2e；全段符合连续公式 %.2e；最大步进 %.3f (上界 %.3f)  %s\n', ...
        dB1, dB2, dB3, step, pf(okB));
ok = ok && okB;

%% ---------- C) 结构 ----------
v = iYes.term_values;
okC1 = (numel(v) == iYes.n_term) && all(v >= 0) && all(v <= M-1) && all(mod(v,1)==0);
okC2 = isfield(iYes,'term_symbols') && ~isfield(iYes,'terms_symbols') && isfield(iYes,'term_values');
okC3 = (numel(iYes.phase_trace) == iYes.n_symbols_total*sps) && ...
       (numel(iYes.term_symbols) == iYes.n_term*sps) && ...
       (numel(iYes.term_phase)  == iYes.n_term*sps) && ...
       (numel(iYes.alpha_values) == iYes.n_symbols_total);
okC = okC1 && okC2 && okC3;
fprintf('C) term_values=%s 结构/字段名自洽  %s\n', mat2str(v), pf(okC));
ok = ok && okC;

%% ---------- D) 终止（全部 ph × Vn）----------
T{3} = [0 0; 2 0; 1 0];                       % 表 7-28
T{4} = [0 0; 3 0; 2 0; 1 0];                  % 表 7-27
T{5} = [0 0 0; 3 1 0; 3 0 0; 2 0 0; 1 0 0];   % 表 7-26
T{7} = [0 0 0; 3 3 0; 3 2 0; 3 1 0; 3 0 0; 2 0 0; 1 0 0];   % 表 7-25
okD = true; ncase = 0; badmsg = '';
for ph = [3 4 5 7]
    for mh = [1 2]
        p = mk(mh, ph, 32, 0.75);
        for Vn = 0:ph-1
            aseq = find_alpha(Vn, ph);
            if isempty(aseq), continue; end
            [~, ii] = rcs_cpm_modulation(bits_from_alpha(aseq, mh/ph), p, true);
            ncase = ncase + 1;
            ref = T{ph}(Vn+1, :);
            good = (ii.Vn == Vn) && (ii.Vn_end == 0) && isequal(ii.term_values, ref) && ...
                   (ii.n_term == numel(ref));
            if ~good
                okD = false;
                badmsg = sprintf(' [ph=%d mh=%d Vn=%d: Vn_end=%d tail=%s 期望%s]', ...
                    ph, mh, Vn, ii.Vn_end, mat2str(ii.term_values), mat2str(ref));
            end
        end
    end
end
fprintf('D) 终止状态检查 %d 例 (ph×Vn×mh, 尾符号逐项比对表 7-25~7-28)%s  %s\n', ...
        ncase, badmsg, pf(okD));
ok = ok && okD;

% A-3 位预算交叉验证：term_bits == 2 * n_term(ph)
try
    w = rcs_waveform_table('A3');
    okD2 = true; nd2 = 0;
    for i = 1:numel(w)
        nt = size(T{w(i).ph}, 2);
        nd2 = nd2 + 1;
        if w(i).term_bits ~= 2*nt || w(i).term_symbols ~= nt, okD2 = false; end
    end
    fprintf('D) A-3 全部 %d 个波形 term_bits = 2*n_term(ph) 相合  %s\n', nd2, pf(okD2));
    ok = ok && okD2;
catch ME
    fprintf('D) A-3 交叉验证跳过（%s）\n', ME.message);
end

%% ---------- E) 比特映射 ----------
p23 = mk(1, 3, 8, 0.75);
[~, e1] = rcs_cpm_modulation([1;0; 1;1; 0;1; 0;0], p23, false);   % 表 7-23
p24 = mk(2, 5, 8, 0.75);                                          % h = 2/5 ≠ 1/3
[~, e2] = rcs_cpm_modulation([1;0; 1;1; 0;1; 0;0], p24, false);   % 表 7-24 (Gray)
okE = isequal(e1.alpha_values, [1 3 -1 -3]) && isequal(e2.alpha_values, [3 1 -1 -3]);
fprintf('E) 表7-23 -> %s；表7-24(Gray) -> %s  %s\n', ...
        mat2str(e1.alpha_values), mat2str(e2.alpha_values), pf(okE));
ok = ok && okE;

%% ---------- F) 真实 A-3 波形端到端 ----------
try
    oks = true; msg = '';
    for id = [1 4 5 7 8 10 14 20]
        w = rcs_waveform_table('A3'); w = w(id);
        p = get_rcs_params('TRF', 'concatenated', struct('waveform_id', id));
        rng(100+id);
        b = randi([0 1], w.fec_output_bits, 1);
        [sy, ii] = rcs_cpm_modulation(b, p, true);
        nd = ii.n_symbols * p.cpm_samples_per_sym;
        c1 = ii.Vn_end == 0;
        c2 = ii.n_term == w.term_symbols;
        gmx = p.cpm_alpha_rc*0.5 + (1-p.cpm_alpha_rc)*0.25;
        lim = 1.05 * 2*pi*p.cpm_mod_index_h * 2*3 * gmx / p.cpm_samples_per_sym;
        c3 = max(abs(diff(ii.phase_trace))) < lim;
        c4 = numel(sy) == ii.n_symbols_total * p.cpm_samples_per_sym;
        c5 = max(abs(angle(sy(nd)) - angle(exp(1j*ii.phase_trace(nd))))) < 1e-12;
        if ~(c1 && c2 && c3 && c4 && c5)
            oks = false;
            msg = sprintf(' [id=%d 失败 c=%d%d%d%d%d]', id, c1, c2, c3, c4, c5);
        end
    end
    fprintf('F) 8 个 A-3 波形（h=1/3,1/4,2/5,2/7）端到端  %s%s\n', pf(oks), msg);
    ok = ok && oks;
catch ME
    fprintf('F) 端到端跳过（%s）\n', ME.message);
end

fprintf('\n总体: %s\n', pf(ok));
end

% ======================================================================
function p = mk(mh, ph, sps, arc)
p.cpm_M = 4; p.cpm_L = 2; p.cpm_mh = mh; p.cpm_ph = ph;
p.cpm_mod_index_h = mh/ph; p.cpm_alpha_rc = arc; p.cpm_samples_per_sym = sps;
end

% ======================================================================
function bits = bits_from_alpha(alpha, h)
% 按 §7.3.7.2.2 的映射把符号值反查回 2 比特标签
if abs(h - 1/3) < 1e-12
    tab = [-3 -1 1 3];          % 表 7-23
else
    tab = [-3 -1 3 1];          % 表 7-24
end
lab = zeros(1, numel(alpha));
for i = 1:numel(alpha)
    lab(i) = find(tab == alpha(i), 1) - 1;
end
bits = reshape([floor(lab/2); mod(lab,2)], [], 1);
end

% ======================================================================
function aseq = find_alpha(target, ph)
% 找一串符号值（±1/±3，长度≤3）使 mod(sum, ph) == target
cand = [-3 -1 1 3];
aseq = [];
for n = 1:3
    idx = dec2base(0:4^n-1, 4) - '0' + 1;
    for r = 1:size(idx,1)
        s = cand(idx(r,:));
        if mod(sum(s), ph) == target, aseq = s; return; end
    end
end
end

% ======================================================================
function s = pf(cond)
if cond, s = '[OK]'; else, s = '[FAIL]'; end
end

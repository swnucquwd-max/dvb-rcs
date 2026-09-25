function [symbols, cpm_info] = rcs_cpm_modulation(bits, params, terminate) 
%DVB-RCS CPM调制器
%按照 sec 7.3.7实现连续相位调制
%s(t) = exp(j*phi(t))
%phi(t) = 2*pi*h*sum(alphai)*q(t-Ts)
%脉冲成形 sec7.3.7.2.1
%qRC(t) = 1/(4TS)*[1-cos(pi*t/TS)]
%qREC(t) =  1/(4TS)
%qAV(t) = aRC*qRC(t)+(1-aRC)*qREC(t)

%相位响应步长 TS/32 附录C表C-1

%params 
      %cpm_mod_index_h  调制指数h = mh/ph(默认1/3)
      %cpm_mh           调制指数分子
      %cpm_ph           调制指数分母，也是相位状态数
      %cpm_M            字母表大小（默认4）
      %cpm_L            记忆长度
      %cpm_alpha_rc     AV脉冲RC分量系数（默认1）
      %cpm_samples_per_sym  每个符号采样点数（默认32）
%terminate   是否在末尾追加尾符号
%    参数默认值

if ~isfield(params, 'cpm_mod_index_h')||isempty(params.cpm_mod_index_h)
    params.cpm_mod_index_h = 1/3;
end

if ~isfield(params, 'cpm_mh')||isempty(params.cpm_mh)
    params.cpm_mh = 1;
end

if ~isfield(params, 'cpm_ph')||isempty(params.cpm_ph)
    params.cpm_ph = 3;
end

if ~isfield(params, 'cpm_M')||isempty(params.cpm_M)
    params.cpm_M = 4;
end

if ~isfield(params, 'cpm_L')||isempty(params.cpm_L)
    params.cpm_L = 2;
end

if ~isfield(params, 'cpm_alpha_rc')||isempty(params.cpm_alpha_rc)
    params.cpm_alpha_rc = 1;
end

if ~isfield(params, 'cpm_samples_per_sym')||isempty(params.cpm_samples_per_sym)
    params.cpm_samples_per_sym = 32;
end

M = params.cpm_M;
L = params.cpm_L;
h = params.cpm_mod_index_h;

alpha_rc = params.cpm_alpha_rc;
samples_per_sym = params.cpm_samples_per_sym;

bits = bits(:);

n_bits = length(bits);
bits_per_symbol = log2(M);
n_symbols = ceil(n_bits/bits_per_symbol);

pad_len = n_symbols*bits_per_symbol-n_bits;

if pad_len > 0
    bits = [bits;zeros(pad_len, 1)];
end

bit_pairs = reshape(bits, bits_per_symbol, n_symbols).';
symbol_indices = bit_pairs(:,1)*2+bit_pairs(:,2);
symbol_values = symbol_indices.';

alpha_values = 2*symbol_values - (M-1);

%脉冲形状函数
g_rc_func = @(t) (1/4)*(1-cos(pi*t)).*(t>0 & t<2);
g_rec_func = @(t) (1/4)*(t>0 & t<2);
g_av_func = @(t)alpha_rc * g_rc_func(t) + (1-alpha_rc)*g_rec_func;

%相位响应函数
q_rc_func = @(t)(t/4 - (1/(4*pi)) * sin(pi*t)).*(t>=0 & t<=2)+0.5*(t>2);
q_rec_func = @(t) (t/4).*(t>=0 & t<=2)+0.5*(t>2);
q_func = @(t)alpha_rc * q_rc_func(t) + (1-alpha_rc)*q_rec_func(t);

%每符号多采样点，步长 = ts/samples_per_sym(TS/32)
total_samples = n_symbols * samples_per_sym;
phase_trace = zeros(total_samples, 1);

t_offsets = (0:samples_per_sym - 1)/samples_per_sym;

for n = 1:n_symbols

    idx_start = (n-1)*samples_per_sym + 1;
    idx_end = n*samples_per_sym;

    for k = 1:samples_per_sym
        offset = t_offsets(k);
        phi = 0;
        for i = 0:(n-1)
            t_arg = (n-i-1)+offset;
            phi = phi+alpha_values(n-i)*q_func(t_arg);
        end
        phase_trace(idx_start + k -1) = 2*pi*h*phi;
    end
end

symbols = exp(1j*phase_trace);

ph = params.cpm_ph;

sum_alpha = sum(alpha_values);
%获取当前相位状态vn = (累计相位/(2*pi/ph))mod ph

Vn = mod(params.cpm_mh*sum_alpha, ph);

%获取尾符号
[term_alpha, n_term] = get_trellis_termination(Vn, ph, M);

%生成尾符号相位轨迹
if n_term > 0
    term_phase = zeros(n_term*samples_per_sym, 1);
    for n = 1:n_term
        idx_start = (n-1)*samples_per_sym+1;
        for k = 1:samples_per_sym
            offset = t_offsets(k);
            phi = 0;
            %数据符号
            for i = 1:(n_symbols-1)
                t_arg = (n-i-1)+offset;
                phi = phi+alpha_values(n_symbols -i)*q_func(t_arg);
            end
            %尾符号
            for i = 0:(n-1)
                t_arg = (n-i-1)+offset;
                phi = phi+term_alpha(n-i)*q_func(t_arg);
            end
            term_alpha(idx_start + k - 1) = 2*pi*h*phi;
        end
    end
    term_symbols = exp(1j*term_alpha);
    term_symbols = term_symbols(:);
    % 追加尾符号到输出
    if terminate 
        phase_trace = [phase_trace; term_phase];
        symbols = [symbols; term_symbols];
        symbol_values = [symbol_values, zeros(1,n_term)];
        alpha_values = [alpha_values, term_alpha];
        n_symbols_total = n_symbols + n_term;
    else
        n_symbols_total = n_symbols;

    end
    

    cpm_info.terms_symbols = term_symbols;
    cpm_info.term_alpha = term_alpha;
    cpm_info.n_term = n_term;

else
    n_symbols_total = n_symbols;
    cpm_info.term_symbols = [];
    cpm_info.term_alpha = [];
    cpm_info.n_term = 0;
end

cpm_info.phase_trace = phase_trace;
cpm_info.symbol_values = symbol_values;
cpm_info.alpha_values = alpha_values;
cpm_info.h = h;
cpm_info.M = M;
cpm_info.L = L;
cpm_info.n_symbols = n_symbols;
cpm_info.n_symbols_total = n_symbols_total;
cpm_info.samples_per_sym = samples_per_sym;
cpm_info.q_func = q_func;
cpm_info.g_func = g_av_func;
end

function [term_alpha, n_term] = get_trellis_termination(Vn, ph, M)
switch ph
    case 3
        n_term = 2;
        table = [
            0 0;
            2 0;
            1 0;
        ];
        term_sym = table(Vn+1, :);
    case 4
        n_term = 2;
        table = [
            0 0;
            3 0;
            2 0;
            1 0;
        ];
        term_sym = table(Vn+1, :);
    case 5
        n_term = 3;
        table = [
            0 0 0;
            3 1 0;
            3 0 0;
            2 0 0;
            1 0 0;
        ];
        term_sym = table(Vn+1, :);
    case 7
        n_term = 3;
        table = [
            0 0 0;
            3 3 0;
            3 2 0;
            3 1 0;
            3 0 0;
            2 0 0;
            1 0 0;
        ];
        term_sym = table(Vn+1, :);
otherwise
       error('ph error');
end
term_alpha = 2*term_sym - (M-1);
end








 






 
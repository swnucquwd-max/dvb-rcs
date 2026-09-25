function symbols = rcs_modulation(bits, params)
% TC-LM线性调制

bits = bits(:);
m = params.mod_order;
n_symbols = ceil(length(bits) / m);%编码输出比特数不是M的整数倍，尾部补0
pad_len = n_symbols * m - length(bits);

if pad_len > 0
    bits = [bits; zeros(pad_len, 1)];
end
bit_groups = reshape(bits, m, n_symbols).';

switch m
    case 1 %sec 7.3.7.1.4.1 BPSK映射 u = 0->+1 u = 1->-1
        %再施加pi/2相位旋转，s(n) = u(n)*exp(j*(n*pi/2+pi/4))
        u = 1-2*bit_groups(:,1);
        u = u/sqrt(2);
        n_idx = (0:n_symbols-1).';
        rotation = exp(1j*(n_idx * pi/2 + pi/4));
        symbols = u .* rotation;
    case 2
        I = 1-2*bit_groups(:,1);
        Q = 1-2*bit_groups(:,2);
        symbols = (I + 1j*Q)/sqrt(2);
    case 3
        gray_map = [0 0 0;
                    0 0 1;
                    0 1 1;
                    0 1 0;
                    1 1 0;
                    1 1 1;
                    1 0 1;
                    1 0 0];
        angles = (0:7).'*pi/4+pi/8;
        lut = exp(1j * angles);

        symbols = zeros(n_symbols, 1);
        for i = 1:n_symbols
            bits_i = bit_groups(i,:);
            idx = find(all(gray_map == bits_i, 2));
            symbols(i) = lut(idx);
        end
    case 4
        pam4_lut = [-1; 1; -3; 3]/sqrt(10);
        symbols = zeros(n_symbols, 1);
        for i = 1:n_symbols
            b = bit_groups(i, :);
            q_idx = b(1)*2+b(2)+1;
            Q_val = pam4_lut(q_idx);
            i_idx = b(3)*2+b(4)+1;
            I_val = pam4_lut(i_idx);
            symbols(i) = I_val + 1j * Q_val;
        end
    otherwise 
        error('modulation type error');
end
end


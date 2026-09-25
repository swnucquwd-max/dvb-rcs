function interleaved = rcs_bit_interleaving(data, params)
% rcs cc-cpm 比特交织器
%按照sec 7.3.5.2.3实现CC-CPM比特交织器
%初始向量[0,1,...,N-1]
%分为两组（N1和N-N1）分别应用子排列掩码M_A,M_B
%pi_3(i) = (s+p*I)modN pi_4(i) = pi_3(i)(pi_3(i)')
%分为四组（K1,K2,K3,K4） 分别应用子排列掩码

data = data(:);
N = length(data);

mask1 = [9 11 8 6 10 2 4 0 7 5 1 3];
mask2 = [8 11 6 4 0 7 3 10 1 5 9 2];
mask3 = [4 10 5 8 3 6 9 11 1 7 0 2];
mask4 = [5 8 10 2 6 4 7 1 3 9 11 0];
mask5 = [10 0 9 1 11 7 3 5 8 6 2 4];
mask6 = [9 7 2 4 10 8 3 6 11 1 5 0];
%不同N值对应参数，如果没有指定，报error
[s, p, N1, K1, K2, K3] = get_interleaver_params(N);


K4 = N-K1-K2-K3;

perm = 0:N-1;

intermediate1 = perm;
n_sub1 = floor(N1/12);

for j = 1:n_sub1
    base = (j-1)*12;
    for k = 1:12
        idx = base + k;
        if idx <= N1
            intermediate1(idx) = perm(base + mask1(k) + 1);
        end
    end
end

n_sub2 = floor((N-N1)/12);
for j = 1:n_sub2
    base = N1+(j-1)*12;
    for k = 1:12
        idx = base + k;
        if idx <= N
            intermediate1(idx) = perm(base + mask2(k) + 1);
        end
    end
end

intermediate2 = zeros(1,N);
for i = 0:N-1
    src_idx = mod(s+p*intermediate1(i+1),N);
    intermediate2(i+1) = intermediate1(src_idx + 1);
end

n_sub3 = floor(K1/12);
for j = 1:n_sub3
    base = (j-1)*12;
    for k = 1:12
        idx = base + k;
        if idx <= K1
            intermediate3(idx) = intermediate2(base + mask3(k) + 1);
        end
    end
end

n_sub4 = floor(K2/12);
for j = 1:n_sub4
    base = K1+(j-1)*12;
    for k = 1:12
        idx = base + k;
        if idx <= K1 + K2
            intermediate3(idx) = intermediate2(base + mask4(k) + 1);
        end
    end
end

n_sub5 = floor(K3/12);
for j = 1:n_sub5
    base = K2+K1+(j-1)*12;
    for k = 1:12
        idx = base + k;
        if idx <= K1 + K2 +K3
            intermediate3(idx) = intermediate2(base + mask5(k) + 1);
        end
    end
end
n_sub6 = floor(K4/12);
for j = 1:n_sub6
    base = K3+K2+K1+(j-1)*12;
    for k = 1:12
        idx = base + k;
        if idx <= N
            intermediate3(idx) = intermediate2(base + mask6(k) + 1);
        end
    end
end


perm_final = zeros(1,N);
for i = 0:N-1
    perm_final(i+1) = intermediate3(intermediate2(i+1) + 1);
end

interleaved = data(perm_final+1);
interleaved = interleaved(:);
end
function [s, p, N1, K1, K2, K3] = get_interleaver_params(N)
table = [
336, 28, 67, 168, 84, 84, 84; 
468, 15, 229, 252, 144, 132, 120; 
504, 2, 19, 252, 144, 132, 120; 
600, 8, 491, 480, 168, 144, 144; 
804, 8, 241, 480, 240, 216, 192; 
912, 4, 373, 456, 240, 228, 228; 
1200, 1, 227, 1080, 360, 336, 384; 
1284, 10, 251, 744, 360, 336, 312; 
1536, 12, 107, 768, 408, 384, 384; 
1752, 6, 433, 1716, 1200, 240, 192; 
1884, 22, 47, 960, 504, 480, 468; 
2052, 2, 317, 1200, 552, 528, 504; 
2256, 8, 653, 1200, 576, 576, 576; 
3012, 5, 241, 1440, 1152, 576, 576
];

idx = find(table(:,1) == N, 1);

if(isempty(idx))

    [~,idx] = min(abs(table(:,1)-N));%取最接近的值
    warning('N不在Table 7-15中');
end

row =  table(idx,:);
s = row(2);
p = row(3);
N1 = row(4);
K1  = row(5);
K2 = row(6);
K3 = row(7);
end

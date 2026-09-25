function [data_with_crc, crc_value] = rcs_crc32_encode(data)

data = data(:);%确保列向量
data_len = length(data);

crc_poly_taps = [26 23 22 16 12 11 10 8 7 5 4 2 1 0];

reg = ones(1,32);

for i = 1 : data_len
    feedback = mod(data(i) + reg(32),2);

    new_reg = zeros(1,32);
    new_reg(1) = feedback;

    for j = 2 : 32
        new_reg(j) = reg(j-1);
    end

    for k = 1 : length(crc_poly_taps)
        tap = crc_poly_taps(k);
        new_reg(tap+1) = mod(new_reg(tap+1)+feedback, 2);
    end

    reg = new_reg;
end

crc_value = mod(reg + 1,2);%对寄存器状态取反
crc_value = crc_value(:);

data_with_crc = [data; crc_value];

end
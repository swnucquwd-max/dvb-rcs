function [data_with_crc, crc_value] = rcs_crc16_encode(data)

data = data(:);%确保列向量
data_len = length(data);

crc_poly = [1 1 0 0 0 0 0 0 0 0 0 0 0 1 0 1];%x^15+x^14+x^2+x^0

reg = zeros(1, 16);

for i = 1:data_len

    feedback = mod(data(i) + reg(16), 2);

    new_reg = zeros(1, 16);
    new_reg(1) = feedback;

    for j = 2:16
        new_reg(j) = reg(j-1);
    end
    new_reg(15) = mod(new_reg(15) + feedback, 2);

    new_reg(2) = mod(new_reg(2) + feedback, 2);

    reg = new_reg;
end

crc_value = reg(:);

data_with_crc = [data; crc_value];

end

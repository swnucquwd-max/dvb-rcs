function [burst_frame, fmt_info] = rcs_burst_formatting(input_data,params)
%DVB-RCS突发成帧
%input_data--输入数据比特流0/1列向量
%params DVB-RCS参数结构体

%output burst_frame-成帧后的比特流0/1列向量 
%fmt_info --格式信息结构体
 %fmt_info.burst_type  --突发结构
 %fmt_info.data_len --原始数据长度
 %fmt_info.frame_len --成帧后长度
 %fmt_info.header_len --头部长度
input_data = input_data(:);%确保列向量
data_len = length(input_data);

burst_type = params.burst_type;

switch upper(burst_type)
    case 'TRF'
        %TRF 突发 头部：8比特突发类型+16比特长度指示
        type_field = [0 0 0 0 0 0 0 1].';%TRF类型标识
        header_len = 8 + 16;
    case 'ACQ'
        %ACQ 突发 
        type_field = [0 0 0 0 0 0 1 0].';%ACQ 类型标识
        header_len = 8 + 16;
    case 'SYNC'
        %SYNC 突发 
        type_field = [0 0 0 0 0 1 0 0].';%SYNC 类型标识
        header_len = 8 + 16;
    case 'CSC'
        %CSC 突发 
        type_field = [0 0 0 0 1 0 0 0].';%CSC 类型标识
        header_len = 8 + 16;
    otherwise
        warning('rcs_burst_formatting : 未知突发类型 "%s",使用TRF', burst_type);
        type_field = [0 0 0 0 0 0 0 1].';%TRF类型标识
        header_len = 8 + 16;
        burst_type = 'TRF';
end

%=========================长度指示字段=========================
len_val = min(data_len,65535);
len_field = zeros(16,1);
for i = 16:-1:1
    len_field(17-i) = mod(floor(len_val / 2^(i-1)),2);
end

%=========================保留字段===============================
reserved_field = zeros(8,1);

%突发结构：[类型字段 长度字段 保留字段 数据负载]

burst_frame = [type_field(:); len_field(:); reserved_field(:); input_data];

fmt_info.burst_type = burst_type;
fmt_info.data_len = data_len;
fmt_info.frame_len = length(burst_frame);
fmt_info.beader_len = header_len;

end


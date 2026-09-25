function coded_data = rcs_channel_coding(data, params)

data = data(:);

switch lower(params.coding_scheme)
    case 'concatenated'
        coded_data = rcs_conv_encode(data, params.conv_params);

    case 'turbo'
        coded_data = rcs_turbo_encode(data, params.turbo_params);

    otherwise

        error('不支持编码方案');
end
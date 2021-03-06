%% Private functions
function [progress_out, x] = track_progress(opt_prob, struct_obj, vis_layer, ...
                                        mode_sel, k, x, z, p, varargin)

    N = length(opt_prob);

    persistent progress

    if ~isempty(varargin)
        progress = varargin{1};
    end

    if k == 1  
        for i = 1 : N
            empty_cells{i} = [];
        end
        progress = struct(  'iters', [], ... 
                            'out_power', {empty_cells}, ...
                            'out_degrees', {empty_cells}, ...
                            'res_norm', [], ...
                            'struct_obj', []);
    end

    % Run verification layer to calculate relevant physical quantities
    if isempty(x)
        modes = verification_layer(opt_prob, z);
    else
        modes = verification_layer(opt_prob, z, x);
    end

%     if isstruct(progress)
%         if k < length(progress.iters) % Need to cut things down to size...
%             progress.iters = progress.iters(1:k);
%             progress.struct_obj = progress.struct_obj(1:k);
%             for i = 1 : N
%                 progress.out_power{i} = progress.out_power{i}(:,1:k);
%                 progress.out_angle{i} = progress.out_angle{i}(:,1:k);
%                 progress.res_norm{i} = progress.res_norm{i}(:,1:k);
%             end
%         end
%     end
    if isempty(k)
        if isempty(progress)
            k = 1;
        else
            k = length(progress.iters) + 1;
        end
    end

    progress.iters(k) = k;
    progress.struct_obj(k) = struct_obj.w(p);
    for i = 1 : N
        progress.out_power{i}(:,k) = modes(i).output_power(:,2);
        progress.out_angle{i}(:,k) = modes(i).output_angle;
        progress.out_degrees{i} = 180/pi*unwrap(progress.out_angle{i}, [], 2);
        progress.res_norm{i}(k) = modes(i).phys_res_norm;
    end

    % Visualize epsilon.
    % subplot 111; imagesc(modes(mode_sel(1)).epsilon{G}'); axis equal tight;
    num_vis_modes = length(mode_sel);
    subplot(2, num_vis_modes+1, 1); 
    title('epsilon');
    my_vis_slice(modes(mode_sel(1)).epsilon, vis_layer{1}, @real);

    % Visualize certain fields.
    for i = mode_sel
        subplot(2, num_vis_modes+1, i+1); 
        my_vis_slice(modes(i).E, vis_layer{i}, @abs);
        title(['Mode ', num2str(i)]);
    end

    
    % Field design objective (power).
    subplot(2, 6, 6+1);
    custom_lineplot(@plot, progress.iters, progress.out_power, mode_sel);
    title('Output powers');

    % Field design objective (angle).
    subplot(2, 6, 6+2);
    custom_lineplot(@plot, progress.iters, progress.out_degrees, mode_sel);
    title('Output angles');

    % Structure design objective.
    subplot(2, 6, 6+3);
    custom_lineplot(@semilogy, progress.iters, progress.res_norm, mode_sel);
    title('Physics residuals');

    % Physics residual.
    subplot(2, 6, 6+4);
    plot(progress.struct_obj, 'k.-');
    title('Structure objective');

    drawnow

    progress_out = progress;

    subplot (2, 6, 6+6);
end

function my_vis_slice(data, vis_layer, fun)
    data = data{vis_layer.component};

    switch vis_layer.slice_dir
        case 'x'
            data = data(vis_layer.slice_index, :, :);
        case 'y'
            data = data(:, vis_layer.slice_index, :);
        case 'z'
            data = data(:, :, vis_layer.slice_index);
    end

    data = squeeze(fun(data));

    if any(data(:) < 0) && any(data(:) > 0)
        cmax = max(abs(data(:)));
        imagesc(data');
    else
        imagesc(data');
    end
    axis equal tight;
    set(gca, 'Ydir', 'normal');
end

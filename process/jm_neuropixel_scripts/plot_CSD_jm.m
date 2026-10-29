function[fig] = plot_CSD_jm(CSD,y_steps_mm,t)

% 3. Convert the depth vector back to Micrometers (μm) for standard layout reporting
depth_um = y_steps_mm * 1000; 

% 4. Create the figure container
fig = figure('Color', 'k', 'Position', [100, 100, 750, 500]);

% 5. Render the CSD matrix as an image map
imagesc(t, depth_um, CSD);
hold on;

axis xy;

% color limits
max_val = max(abs(CSD(:)));
caxis([-max_val*0.95, max_val*0.95]);

colormap(jet(256)); 
cb = colorbar;
ylabel(cb, 'Current Source Density (nA / mm^3)', 'FontSize', 11, 'FontWeight', 'bold');

% 9. Draw a visual indicator line at stimulus onset (t = 0)
plot([0, 0], [min(depth_um), max(depth_um)], 'w--', 'LineWidth', 2);

% 10. Clean aesthetic formatting
set(gca, 'Box', 'off', 'TickDir', 'out', 'LineWidth', 1.2, 'FontSize', 11);
xlabel('Time Relative to Stimulus (ms)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Probe Depth / Shank Height (\mum)', 'FontSize', 12, 'FontWeight', 'bold');
title('Evoked 2D Kernel Current Source Density Profile', 'FontSize', 13, 'FontWeight', 'bold');

hold off;

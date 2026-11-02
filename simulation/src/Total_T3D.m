clear; clc;

% ===== 挡位最大扭矩 =====
Tmax_1 = 429378;   % 1挡
Tmax_2 = 180105;   % 2挡

% ===== 输入范围 =====
alpha = linspace(0,1,100);      % 油门开度
v1 = linspace(0,15,50);         % 车速 (km/h)
v2 = linspace(0,45,50);         % 车速 (m/s)

[Alpha, V1] = meshgrid(alpha, v1);
[Alpha2, V2] = meshgrid(alpha, v2);

alpha_dead = 0.03;

f_throttle1 = zeros(size(Alpha));

idx = Alpha > alpha_dead;

alpha_eff = (Alpha(idx) - alpha_dead) / (1 - alpha_dead);

f_throttle1(idx) = 0.92 * alpha_eff.^1.4 + 0.08;

f_throttle2 = zeros(size(Alpha2));

idx2 = Alpha2 > alpha_dead;

alpha_eff2 = (Alpha(idx2) - alpha_dead) / (1 - alpha_dead);

f_throttle2(idx2) = 0.92 * alpha_eff2.^1.4 + 0.08;

% 1挡：低速强，高速衰减快
f_speed_1 = 0.4 + 0.6*(1-exp(-V1/3.6/1.5));

% 2挡：衰减慢
f_speed_2 = 0.4 + 0.6*(1-exp(-V2/3.6/3));

T_total_1 = Tmax_1 .* f_throttle1 .* f_speed_1;
T_total_2 = Tmax_2 .* f_throttle2 .* f_speed_2;

figure;
step=3;
surf(Alpha(1:step:end,1:step:end), V1(1:step:end,1:step:end), T_total_1(1:step:end,1:step:end), 'EdgeColor', [0 0 0],'LineWidth', 1.5);
shading interp;        % 保持平滑
hold on;
% ===== 第二层：稀疏网格（只画线）=====
step = 3;

surf(Alpha(1:step:end,1:step:end), ...
     V1(1:step:end,1:step:end), ...
     T_total_1(1:step:end,1:step:end), ...
     'FaceColor','none', ...   % ❗只保留网格
     'EdgeColor','k', ...
     'LineWidth',1.5);

% ===== 蓝色渐变（重点）=====
colormap([linspace(0.7,0,64)', linspace(0.85,0.3,64)', ones(64,1)]);
colorbar;

xlabel('Throttle');
ylabel('Speed (km/h)');
zlabel('Torque (Nm)');
title('Gear 1 Torque Surface');
view(135,30);   % 更有立体感
grid on;
box on;

figure;
step=3;
surf(Alpha2(1:step:end,1:step:end), V2(1:step:end,1:step:end), T_total_2(1:step:end,1:step:end), 'EdgeColor', [0 0 0],'LineWidth', 1.5);
shading interp;        % 保持平滑
hold on;
% ===== 第二层：稀疏网格（只画线）=====
step = 3;

surf(Alpha2(1:step:end,1:step:end), ...
     V2(1:step:end,1:step:end), ...
     T_total_2(1:step:end,1:step:end), ...
     'FaceColor','none', ...   % ❗只保留网格
     'EdgeColor','k', ...
     'LineWidth',1.5);

% ===== 蓝色渐变（重点）=====
colormap([linspace(0.7,0,64)', linspace(0.85,0.3,64)', ones(64,1)]);
colorbar;
xlabel('Throttle');
ylabel('Speed (m/s)');
zlabel('Torque (Nm)');
title('Gear 2 Torque Surface');
view(135,30);   % 更有立体感
grid on;
box on;
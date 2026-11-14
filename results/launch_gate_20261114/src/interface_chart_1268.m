function U_optimal = mpc_torque_allocation_fcn(X_current, Fx, Mz, Fz_all, mu, last_U_in)
% 基于MPC的四轮驱动车辆扭矩分配。
% 本函数在每个计算步中构建并求解一个二次规划(QP)问题。

%#codegen

% -------------------------------------------------------------------------
% 1. 定义持久化变量和参数
% -------------------------------------------------------------------------
% persistent 关键字定义的变量只在第一次调用函数时初始化，之后会保持它们的值。
persistent vehicle_params mpc_params last_U

if isempty(vehicle_params)
    % --- 车辆参数 ---
    % !! 请根据您的拖拉机模型修改以下参数 !!
    vehicle_params.m = 18530;   % 质量 (kg)
    vehicle_params.Iz = 67536;  % 绕Z轴的转动惯量 (kg*m^2)
    vehicle_params.lf = 2.043;   % 质心到前轴的距离 (m)
    vehicle_params.lr = 1.362;   % 质心到后轴的距离 (m)
    vehicle_params.wf = 2.39;    % 前轮距 (m)
    vehicle_params.wr = 2.33;    % 后轮距 (m)

    % --- MPC 参数 ---
    mpc_params.Ts = 0.001;      % 采样时间 (s)，必须与Simulink的采样时间一致
    mpc_params.Np = 20;        % 预测时域 (Prediction Horizon)
    mpc_params.Nc = 10;         % 控制时域 (Control Horizon)
    
    % --- MPC 权重 ---
    % 对控制输入变化率 (delta U) 的惩罚矩阵R的对角线元素
    mpc_params.R_diag = ones(8, 1) * 0.01; 
    mpc_params.w_ax = 1.0;      % 纵向加速度权重
    mpc_params.w_ay = 1;      % 横向加速度权重
    
    % --- 轮胎附着多边形 ---
    % 使用一个八边形来线性化近似摩擦圆约束
    num_sides = 8;
    angles = (0:num_sides-1)' * (2*pi/num_sides);
    mpc_params.friction_polygon = [cos(angles), sin(angles)]; % [cos, sin] 列
    
    % 初始化上一次的控制输入
    last_U = zeros(8, 1);
end

% 从输入端口更新last_U，以保证时间步之间的一致性
if any(size(last_U_in) ~= size(last_U))
   last_U = zeros(8,1); % 如果是第一次运行或尺寸不匹配，则进行初始化
else
   last_U = last_U_in;
end


% -------------------------------------------------------------------------
% 2. 获取参数
% -------------------------------------------------------------------------
% 车辆参数
m = vehicle_params.m;
Iz = vehicle_params.Iz;
lf = vehicle_params.lf;
lr = vehicle_params.lr;
wf = vehicle_params.wf;
wr = vehicle_params.wr;
bf = wf / 2; % 半轮距
br = wr / 2;

% MPC参数
Ts = mpc_params.Ts;
Np = mpc_params.Np;
Nc = mpc_params.Nc;
R = diag(mpc_params.R_diag);

% 解析输入信号
u_k = X_current(1); % 当前的纵向车速 (m/s)
v_k = X_current(2); % 当前的横向车速 (m/s)
r_k = X_current(3); % 当前横摆角速度 (rad/s)

% -------------------------------------------------------------------------
% 3. 定义状态空间矩阵 
% -------------------------------------------------------------------------
% 连续时间的状态矩阵 A_c，它依赖于当前车速 u_k
A_c = [0, 0, 0;
       0, 0, u_k;
       0, 0, 0];

% 连续时间的输入矩阵 B_c  横摆方向逆时针为正;横向向左为正
B_c = [1/m,   0,   1/m,   0,   1/m,   0,   1/m,   0;
       0,   1/m,   0,   1/m,   0,   1/m,   0,   1/m;
       -bf/Iz, lf/Iz, bf/Iz, lf/Iz, -br/Iz, -lr/Iz, br/Iz, -lr/Iz];

% 使用前向欧拉法进行离散化
Ad = eye(3) + A_c * Ts;
Bd = B_c * Ts;

% -------------------------------------------------------------------------
% 4. 构建二次规划(QP)问题 
%    目标: min 0.5 * dU' * H * dU + f' * dU
% -------------------------------------------------------------------------
% 新代价函数: J = sum( (ax^2+ay^2) + dU'*R*dU )

% ---- 4.1 定义权重和矩阵 ----
% 从参数区获取加速度权重
w_ax = mpc_params.w_ax;
w_ay = mpc_params.w_ay;
Q_accel = diag([w_ax^2, w_ay^2]); % 单步的加速度权重矩阵

% 构建整个控制时域的权重矩阵
Q_bar = kron(eye(Nc), Q_accel);  % 加速度项的权重矩阵
R_bar = kron(eye(Nc), R);      % 控制增量项的权重矩阵

% ---- 4.2 将加速度表示为dU的函数 ----
% 定义一个矩阵，从控制向量U中提取与加速度相关的力
C_u = [1/m, 0, 1/m, 0, 1/m, 0, 1/m, 0;
       0, 1/m, 0, 1/m, 0, 1/m, 0, 1/m];
C_u_bar = kron(eye(Nc), C_u);

% 计算由当前状态(u_k, v_k, r_k)引起的加速度偏移量
% (在线性化过程中被视为常数)
d_accel_k = [-v_k * r_k; 2 * u_k * r_k];
d_accel_bar = repmat(d_accel_k, Nc, 1);

% ---- 4.3 构建QP矩阵 H 和 f ----
% 回忆: U_vec = M_sum * dU_vec + U_last_vec
% 预测的加速度 Accel_vec = C_u_bar * U_vec + d_accel_bar
%                        = C_u_bar * (M_sum * dU_vec + U_last_vec) + d_accel_bar
%                        = (C_u_bar * M_sum) * dU_vec + (C_u_bar * U_last_vec + d_accel_bar)
%
% 令 S = C_u_bar * M_sum
% 令 E = C_u_bar * U_last_vec + d_accel_bar
% 则 Accel_vec = S * dU_vec + E
%
% 加速度部分的代价 J_accel = (S*dU+E)' * Q_bar * (S*dU+E)
% 展开后与QP标准型对比，可以推导出H和f的构成

% 预先计算一个将 dU_vec 映射到 U_vec 的矩阵
% U_vec = M_sum * dU_vec + U_last_vec
M_sum = kron(tril(ones(Nc, Nc)), eye(8));
U_last_vec = repmat(last_U, Nc, 1);

S = C_u_bar * M_sum;
E = C_u_bar * U_last_vec + d_accel_bar;

% 构建 H 矩阵
H = 2 * (S' * Q_bar * S + R_bar);

% 构建 f 向量
f = 2 * (S' * Q_bar * E);

% ---- 4.2 构建约束矩阵 ----
% 优化变量是dU。所有约束都必须是关于dU的线性形式: A*dU <= b 或 Aeq*dU = beq
% 未来的控制量 U_k+i 与 增量 dU 的关系: U_k+i = U_{k-1} + dU_k + ... + dU_k+i



% --- 4.2.1 等式约束: Aeq * dU_vec = beq ---
% 在所有 Nc 控制步内，都满足 Fx_total = Fx_ref 和 Mz_total = Mz_ref
C_fx = [1, 0, 1, 0, 1, 0, 1, 0];
C_mz = [-bf, lf, bf, lf, -br, -lr, br, -lr]; % 注意: 此处未除以Iz，因为约束是针对力矩本身

Aeq_block = [C_fx; C_mz]; % (维度: 2 x 8)
Aeq = kron(eye(Nc), Aeq_block); % (维度: 2*Nc x 8*Nc)
Aeq = Aeq * M_sum;

% 构建等式约束右侧的beq向量
beq_fx = ones(Nc, 1) * Fx;
beq_mz = ones(Nc, 1) * Mz;
beq_block = [beq_fx'; beq_mz']; % (维度: 2 x Nc)
beq = beq_block(:); % (维度: 2*Nc x 1)
% 别忘了减去上个时刻控制量的影响
beq = beq - kron(eye(Nc), Aeq_block) * U_last_vec;

% --- 4.2.2 不等式约束: Aineq * dU_vec <= bineq ---
% 对所有4个轮胎、在所有Nc控制步内的轮胎附着多边形约束
% poly_sides = mpc_params.friction_polygon;
% num_sides = size(poly_sides, 1);
% num_tires = 4;
% 
% Aineq_block = zeros(num_sides * num_tires, 8);
% for i = 1:num_tires % 遍历: 左前, 右前, 左后, 右后
%     % 找到这个轮胎对应的Fx和Fy列的索引
%     idx_fx = 2*i - 1;
%     idx_fy = 2*i;
%     
%     % 获取这个轮胎对应约束的行索引范围
%     row_start = (i-1)*num_sides + 1;
%     row_end = i*num_sides;
%     
%     % 填充多边形约束系数
%     Aineq_block(row_start:row_end, idx_fx) = poly_sides(:, 1); % cos(theta)
%     Aineq_block(row_start:row_end, idx_fy) = poly_sides(:, 2); % sin(theta)
% end
% 
% Aineq = kron(eye(Nc), Aineq_block); % (维度: num_sides*num_tires*Nc x 8*Nc)
% Aineq = Aineq * M_sum;
% 
% % 构建不等式约束右侧的bineq向量
% mu_vec = ones(4,1) * mu; % 暂时假设所有轮胎的附着系数 mu 相同
% Fz_mu_vec = Fz_all .* mu_vec; % 计算每个轮胎的最大附着力
% bineq_block = repelem(Fz_mu_vec, num_sides, 1); % repelem for R2017a+, for older use kron
% bineq = repmat(bineq_block, Nc, 1);
% % 同样，减去上个时刻控制量的影响
% bineq = bineq - kron(eye(Nc), Aineq_block) * U_last_vec;

% -------------------------------------------------------------------------
% 5. 求解QP问题
% -------------------------------------------------------------------------
% 设置 quadprog 求解器选项
U_optimal = zeros(8,1);
options = optimoptions('quadprog', 'Display', 'none', 'Algorithm', 'active-set');

% 为求解器创建一个全零的初始猜测点 x0
% 它的维度必须与优化变量dU_vec一致 (8*Nc x 1)
x0 = zeros(8 * Nc, 1);

% --- 【新增代码】构建下界(lb)向量以保证驱动轮Fx >= 0 ---
% lb是直接作用于优化变量dU_vec的

% 首先，为单个时间步的dU创建一个下界向量
lb_step = -inf(8, 1);

% 假设所有4个轮子都只作为驱动轮，不能为负
% Fx的索引是 1, 3, 5, 7
drive_idx = [1, 3, 5, 7]; 
% Fx的增量的下界是上一时刻Fx的负值，以保证 Fx_k = Fx_{k-1} + dFx_k >= 0
lb_step(drive_idx) = -last_U(drive_idx);

% 然后，将单步的下界向量复制Nc次，以覆盖整个控制时域
lb = repmat(lb_step, Nc, 1);

% 【修改代码】调用求解器，将lb作为第7个参数传入
% [dU_vec_sol, ~, exitflag] = quadprog(H, f, Aineq, bineq, Aeq, beq, lb, [], x0, options);
[dU_vec_sol, ~, exitflag] = quadprog(H, f, [], [], Aeq, beq, lb, [], x0, options);
% -------------------------------------------------------------------------
% 6. 处理求解结果
% -------------------------------------------------------------------------
if exitflag == 1 % 返回1代表求解成功
    % 提取第一个控制增量 (Receding Horizon Control)
    dU_optimal = dU_vec_sol(1:8);
    % 计算当前时刻的最终控制输入
    U_optimal = last_U + dU_optimal;
else
    % 如果求解失败, 保持上一次的控制输入不变 (作为一种安全备用策略)
    U_optimal = last_U;
end

% 无需在此更新 last_U, 因为它会作为输出连接到Unit Delay模块，
% 并在下个采样时刻通过输入端口 last_U_in 传回。

end
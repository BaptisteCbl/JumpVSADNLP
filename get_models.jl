# function get_adnlp_model()

#     # parameters
#     n=2
#     m=1
#     t0=0.0
#     x0=[-1, 0]
#     xf=[0, 0]
#     γ = 1
#     N = 30

#     # adnlp model
#     obj_fun(xuv) = xuv[end] # objectiv
#     dim_v = (N+1)*(2+1) + 1 # dimension of vector xu+v
#     xuv0 = fill(0.1, dim_v)
#     l_var = -Inf*ones(dim_v)
#     u_var = Inf*ones(dim_v)
#     for i ∈ 1:dim_v # variable bounds
#         if i == dim_v
#             l_var[i] = 0
#             u_var[i] = Inf
#         elseif i > (N+1)*2
#             l_var[i] = -γ
#             u_var[i] = γ
#         end
#     end

#     lb = zeros((N)*2 + 4)
#     ub = zeros((N)*2 + 4)
#     lb[1:2] = x0
#     lb[3:4] = xf
#     ub[1:2] = x0
#     ub[3:4] = xf
#     function con_fun(c, xuv, t0::Float64 = t0, N::Int = N) 
#         h = (xuv[end]-t0)/N
#         #@views xi = [xuv[1], xuv[(N+1)+1]] # state at time 0
#         xi = view(xuv,1:(N+1):(N+1)+1)
#         ui = xuv[2*(N+1)+1] # control at time 0
#         offset = 4
#         for i = 1:N   
#             @views xip1 = [xuv[((i+1) + 1)], xuv[((N+1) + (i+1) + 1)]] # state at time i+1
#             uip1 = xuv[2*(N+1)+(i+1)] # control at time i+1
#             c[i+offset] = xip1[1] - (xi[1] + 0.5*h*(xi[2]^2 + xip1[2]^2))
#             c[(N)+i+offset] = xip1[2] - (xi[2] + 0.5*h*(ui^2 + uip1^2))
#             xi = xip1
#             ui = uip1
#         end
#         c[1:2] = [xuv[1], xuv[(N+1)+1]]
#         c[3:4] = [xuv[N+1], xuv[2*(N+1)]]
#         return(c)
#     end 
    
#     # Check that it doesn't allocate
#     cx = similar(lb)
#     con_fun(cx, xuv0)
#     a = @allocated con_fun(cx, xuv0)
#     #@assert a == 0

#     adnlp = ADNLPModel!(obj_fun, xuv0, l_var, u_var, con_fun, lb, ub)

#     λa = [ Float64(i) for i = 1:adnlp.meta.ncon] # ones(adnlp.meta.ncon) # Lagrange multipliers  
    
#     return adnlp, λa, xuv0
# end

function get_adnlp_model()

    # parameters
    n=2
    m=1
    t0=0.0
    x0=[-1, 0]
    xf=[0, 0]
    γ = 1
    N = 500

    # adnlp model
    obj_fun(xuv) = xuv[end] # objectiv
    dim_v = (N+1)*(2+1) + 1 # dimension of vector xu+v
    xuv0 = fill(0.1, dim_v)
    l_var = -Inf*ones(dim_v)
    u_var = Inf*ones(dim_v)
    for i ∈ 1:dim_v # variable bounds
        if i == dim_v
            l_var[i] = 0
            u_var[i] = Inf
        elseif i > (N+1)*2
            l_var[i] = -γ
            u_var[i] = γ
        end
    end
    l_var[1:2] = x0
    u_var[1:2] = x0
    l_var[(N+1)*2-1:(N+1)*2] = xf
    u_var[(N+1)*2-1:(N+1)*2] = xf
    lb = zeros((N+1)*2)
    ub = zeros((N+1)*2)
    lb[1:2] = x0
    lb[(N+1)*2-1:(N+1)*2] = xf
    ub[1:2] = x0
    ub[(N+1)*2-1:(N+1)*2] = xf
    function con_fun(c, xuv, t0::Float64 = t0, N::Int = N) 
        h = (xuv[end]-t0)/N
        xi = view(xuv, 1:2) # state at time 0
        ui = xuv[2*(N+1)+1] # control at time 0
        index = 1
        for i = 0:N   
            xip1 = view(xuv, ((i+1)*2+1):((i+1)*2+2)) # state at time i+1
            uip1 = xuv[2*(N+1)+(i+1)] # control at time i+1
            c[index] = xip1[1] - (xi[1] + 0.5*h*(xi[2] + xip1[2]))
            c[index+1] = xip1[2] - (xi[2] + 0.5*h*(ui + uip1))
            index = index + 2
            xi = xip1
            ui = uip1
        end
        return(c)
    end 
    # Check that it doesn't allocate
    cx = similar(lb)
    con_fun(cx, xuv0)
    a = @allocated con_fun(cx, xuv0)
    @assert a == 0

    adnlp = ADNLPModel!(obj_fun, xuv0, l_var, u_var, con_fun, lb, ub)

    λa = [Float64(i) for i = 1:adnlp.meta.ncon]#ones(adnlp.meta.ncon) # Lagrange multipliers  
    
    return adnlp, λa, xuv0
end

function get_jump_model()

    # parameters
    n=2
    m=1
    t0=0.0
    x0=[-1, 0]
    xf=[0, 0]
    γ = 1
    N = 500

    # jump model
    sys = JuMP.Model()

    JuMP.@variables(sys, begin
        x₁[1:N+1]
        x₂[1:N+1]
        -γ ≤ u[1:N+1] ≤ γ
        0 ≤ tf
    end)

    set_start_value(tf, 0.1)
    set_start_value(x₁[1], 0.1)
    set_start_value(x₂[1], 0.1)

    @objective(sys, Min, tf)
    
    JuMP.@NLexpressions(sys, begin
        # x₁' = x₂
        dx₁[i = 1:N+1], x₂[i]^2
        # x₂' = u
        dx₂[i = 1:N+1], u[i]^2
    end)

    JuMP.@NLconstraints(sys, begin
        con_x₁0, x₁[1] == x0[1]
        con_x₂0, x₂[1] == x0[2]
        con_x₁f, x₁[N+1] == xf[1]
        con_x₂f, x₂[N+1] == xf[2]
        con_dx₁[i = 1:N], x₁[i+1] == x₁[i] + (tf/N) * (dx₁[i] + dx₁[i+1])/2.0
        con_dx₂[i = 1:N], x₂[i+1] == x₂[i] + (tf/N) * (dx₂[i] + dx₂[i+1])/2.0
    end);

    jump_nlp = MathOptNLPModel(sys)
    λj = [ Float64(i) for i = 1:jump_nlp.meta.ncon]#ones(jump_nlp.meta.ncon) # Lagrange multipliers

    return jump_nlp, λj, nothing

end
#--------------------------------------------------------------------------------------------------------------
# Binary parameters

#K_list = (:Pb, :T0, :e0, :omega0, :x0)
#PK_list = (:k, :gamma, :Pbdot, :r, :s, :h3, :varsigma, :dtheta)
#X_list = (:m2, :q, :deltaN)

KObsType = NamedTuple{K_list, NTuple{length(K_list), Measurement{Float64}}}
PKObsType = NamedTuple{PK_list, NTuple{length(PK_list), Measurement{Float64}}}
XObsType = NamedTuple{X_list, NTuple{length(X_list), Measurement{Float64}}}

struct ObsParams
    K::KObsType
    PK::PKObsType
    X::XObsType
    masses_init::NamedTuple{(:m1, :m2), Tuple{Float64, Float64}}
end

ObsParams(;Pb = 0.0 ± 0.0, T0 = 0.0 ± 0.0, e0 = 0.0 ± 0.0, eps1 = 0.0 ± 0.0, eps2 = 0.0 ± 0.0, omega0 = 0.0 ± 0.0, x0 = 0.0 ± 0.0, k = 0.0 ± 0.0, omegadot = 0.0 ± 0.0, gamma = 0.0 ± 0.0, Pbdot = 0.0 ± 0.0, r = 0.0 ± 0.0, m2_shapiro = 0.0 ± 0.0, s = 0.0 ± 0.0, h3 = 0.0 ± 0.0, varsigma = 0.0 ± 0.0, dtheta = 0.0 ± 0.0, m2 = 0.0 ± 0.0, q = 0.0 ± 0.0, deltaN = 0.0 ± 0.0, m1_init = 1.0, m2_init = 1.0) = ObsParams(KObsType((Pb, T0, e0 == 0 ? sqrt(eps1^2 + eps2^2) : e0, omega0 == 0 ? 180/pi*atan(eps1/eps2) : omega0, x0)), PKObsType((k == 0 ? omegadot / 360 * Pb/365.25 : k, gamma, Pbdot, r == 0 ? m2_shapiro*G*M_sun/c^3 : r, s, h3, varsigma, dtheta)), XObsType((m2, q, deltaN)), (m1 = m1_init, m2 = m2_init))

function Base.show(io::IO, params::ObsParams)
    println(io, "Observed parameters:")
    println(io, "Observed Keplerian parameters:\n   ", params.K)
	println(io, "Observed Post-Keplerian parameters:\n   ", params.PK)
	print(io,   "Observed Extra parameters:\n   ", params.X)
	return nothing
end

#--------------------------------------------------------------------------------------------------------------
# Post-keplerian framework

#=
mutable struct PKFramework{T <: AbstractGravityTest}
    test::T
    obs_params::ObsParams
    gsets::GridSetttings
    grid::SimpleGrid
end

function Base.show(io::IO, pkf::PKFramework)
    println(io, "Post-Keplerian framework:")
    println(io, pkf.test)
    println(io, pkf.obs_params)
    print(io, pkf.gsets)
	return nothing
end


#PKFramework(;test::T, obs_params::ObsParams, gsets::GridSetttings) where {T <: AbstractGravityTest} = PKFramework{T}(test, obs_params, gsets, grid)

function PKFramework(test::GeneralTest, obs_params::ObsParams, gsets::GridSetttings)
    param1_grid = collect(LinRange(test.param1.min, test.param1.max, test.param1.N))
    param2_grid = collect(LinRange(test.param2.min, test.param2.max, test.param2.N))
    grid = SimpleGrid(Dict(), param1_grid, param2_grid)
    return PKFramework(test, obs_params, gsets, grid)
end

=#

#--------------------------------------------------------------------------------------------------------------
# Post-keplerian framework subroutines

function find_initial_masses(obs_params::ObsParams, pf::DEFPhysicalFramework)
    PK_first = :k
    PK_second = :gamma
    for PK in keys(obs_params.PK)
        if abs(obs_params.PK[PK].val / obs_params.PK[PK].err) > abs(obs_params.PK[PK_first].val / obs_params.PK[PK_first].err)
            PK_second = PK_first
            PK_first = PK
        elseif abs(obs_params.PK[PK].val / obs_params.PK[PK].err) > abs(obs_params.PK[PK_second].val / obs_params.PK[PK_second].err) && PK != PK_first
            PK_second = PK
        end
    end

#    println(PK_first, " ", PK_second)

    function find_intersection!(F, x)
        pf.bnsys.psr.mass = abs(x[1])
        pf.bnsys.comp.mass = abs(x[2])
        interpolate_bnsys!(pf)
        F[1] = (pf.bnsys.PK_params[PK_first] / obs_params.PK[PK_first].val) - 1.0 #/ ct.PK_params_sigma[PK_first]
        F[2] = (pf.bnsys.PK_params[PK_second] / obs_params.PK[PK_second].val) - 1.0 #/ ct.PK_params_sigma[PK_first]
    end
    solution = nlsolve(find_intersection!, [pf.bnsys.psr.mass; pf.bnsys.comp.mass])
#    println(solution)
    m1, m2 = abs.(solution.zero)
    pf.bnsys.psr.mass = m1
    pf.bnsys.comp.mass = m2
    return (m1 = m1, m2 = m2)
end

function get_chisqr(obs_params::ObsParams, pf::DEFPhysicalFramework)
    chisqr = 0.0
    for PK in keys(obs_params.PK)
        if obs_params.PK[PK].err != 0.0
            chisqr += ((pf.bnsys.PK_params[PK] - obs_params.PK[PK].val) / obs_params.PK[PK].err)^2
        end
    end
    for K in keys(obs_params.K)
        if obs_params.K[K].err != 0.0
            chisqr += ((pf.bnsys.K_params[K] - obs_params.K[K].val) / obs_params.K[K].err)^2
        end
    end
    for X in keys(obs_params.X)
        if obs_params.X[X].err != 0.0
            chisqr += ((pf.bnsys.X_params[X] - obs_params.X[X].val) / obs_params.X[X].err)^2
        end
    end
    chisqr = isnan(chisqr) ? Inf : chisqr
    return chisqr
end

function check_terms_in_chisqr(obs_params::ObsParams, pf::DEFPhysicalFramework)
    println("(theory - observation) / sigma")
    for PK in keys(obs_params.PK)
        if obs_params.PK[PK].err != 0.0
            println("$PK: ", ((pf.bnsys.PK_params[PK] - obs_params.PK[PK].val) / obs_params.PK[PK].err))
        end
    end
    for K in keys(obs_params.K)
        if obs_params.K[K].err != 0.0
            println("$K: ", ((pf.bnsys.K_params[K] - obs_params.K[K].val) / obs_params.K[K].err))
        end
    end
    for X in keys(obs_params.X)
        if obs_params.X[X].err != 0.0
            println("$X: ", ((pf.bnsys.X_params[X] - obs_params.X[X].val) / obs_params.X[X].err))
        end
    end
end

function get_terms_in_chisqr(obs_params::ObsParams, pf::DEFPhysicalFramework)

    for PK in keys(obs_params.PK)
        if obs_params.PK[PK].err != 0.0
            println("$PK: ", ((pf.bnsys.PK_params[PK] - obs_params.PK[PK].val) / obs_params.PK[PK].err))
        end
    end
    for K in keys(obs_params.K)
        if obs_params.K[K].err != 0.0
            println("$K: ", ((pf.bnsys.K_params[K] - obs_params.K[K].val) / obs_params.K[K].err))
        end
    end
    for X in keys(obs_params.X)
        if obs_params.X[X].err != 0.0
            println("$X: ", ((pf.bnsys.X_params[X] - obs_params.X[X].val) / obs_params.X[X].err))
        end
    end
end

function optimize_PK_method(obs_params::ObsParams, pf::DEFPhysicalFramework)
    function get_chisqr_local(x)
        pf.bnsys.psr.mass = abs(x[1])
        pf.bnsys.comp.mass = abs(x[2])
        Pb = x[3]
        e0 = x[4]
        x0 = x[5]
        pf.bnsys.K_params = (Pb = Pb, T0 = pf.bnsys.K_params.T0, e0 = e0, omega0 = pf.bnsys.K_params.omega0, x0 = x0)
        interpolate_bnsys!(pf)
        return sqrt(get_chisqr(obs_params, pf))
    end
    #find_initial_masses(obs_params, pf)
    sol = optimize(get_chisqr_local, [pf.bnsys.psr.mass, pf.bnsys.comp.mass, pf.bnsys.K_params.Pb, pf.bnsys.K_params.e0, pf.bnsys.K_params.x0])
    m1, m2, Pb, e0, x0 = Optim.minimizer(sol)
    m1 = abs(m1); m2 = abs(m2)
    pf.bnsys.psr.mass, pf.bnsys.comp.mass = m1, m2
    pf.bnsys.K_params = (Pb = Pb, T0 = pf.bnsys.K_params.T0, e0 = e0, omega0 = pf.bnsys.K_params.omega0, x0 = x0)
    interpolate_bnsys!(pf)
    return (m1 = m1, m2 = m2, Pb = Pb, e0 = e0,  x0 = x0)
end

function find_best_masses(obs_params::ObsParams, pf::DEFPhysicalFramework)
    function get_chisqr_local(x)
        pf.bnsys.psr.mass = abs(x[1])
        pf.bnsys.comp.mass = abs(x[2])
        interpolate_bnsys!(pf)
        return sqrt(get_chisqr(obs_params, pf))
    end
    #find_initial_masses(obs_params, pf)
    sol = optimize(get_chisqr_local, [pf.bnsys.psr.mass, pf.bnsys.comp.mass])
    m1, m2 = abs.(Optim.minimizer(sol))
    pf.bnsys.psr.mass, pf.bnsys.comp.mass = m1, m2
    interpolate_bnsys!(pf)
    return (m1 = m1, m2 = m2)
end

#function get_chisqr(fixed_params::Dict, pf::DEFPhysicalFramework)
#    chisqr = 0.0
#    for name in keys(fixed_params)
#        if name ∈ keys(pf.bnsys.PK_params)
#            chisqr += ((pf.bnsys.PK_params[name] - fixed_params[name].val) / fixed_params[name].err)^2
#        elseif name ∈ keys(pf.bnsys.X_params)
#            chisqr += ((pf.bnsys.X_params[name] - fixed_params[name].val) / fixed_params[name].err)^2
#        elseif name == :m1
#            chisqr += ((pf.bnsys.psr.mass -  - fixed_params[name].val) / fixed_params[name].err)^2
#        elseif name == :m2
#            chisqr += ((pf.bnsys.comp.mass -  - fixed_params[name].val) / fixed_params[name].err)^2
#        end
#    end
#    return chisqr
#end
#
#function find_best_fit(fixed_params::Dict, pf::DEFPhysicalFramework)
#    function get_chisqr_local(x)
#        pf.bnsys.psr.mass = abs(x[1])
#        pf.bnsys.comp.mass = abs(x[2])
#        interpolate_bnsys!(pf)
#        chisqr = get_chisqr(fixed_params, pf)
#        return sqrt(chisqr)
#    end
#    sol = optimize(get_chisqr_local, [pf.bnsys.psr.mass, pf.bnsys.comp.mass])
#    println(sol)
#    m1, m2 = abs.(Optim.minimizer(sol))
#    pf.bnsys.psr.mass, pf.bnsys.comp.mass = m1, m2
#    interpolate_bnsys!(pf)
#    return (m1 = m1, m2 = m2)
#end

function find_masses(params, obs_params, pf::DEFPhysicalFramework)
    name1, name2 = keys(params)
    function get_value(name)
        if name == "m1"
            value = pf.bnsys.psr.mass
        elseif name == "m2"
            value = pf.bnsys.comp.mass
        elseif haskey(pf.bnsys.PK_params, Symbol(name))
            value = pf.bnsys.PK_params[Symbol(name)]
        elseif haskey(pf.bnsys.X_params, Symbol(name))
            value = pf.bnsys.X_params[Symbol(name)]
        elseif name == "cosi"
            s = pf.bnsys.PK_params[:s]
            value = sqrt(1 - s^2 >= 0 ? 1 - s^2 : NaN)
        end
    end

    function get_residuals!(F, x)
        pf.bnsys.psr.mass = abs(x[1])
        pf.bnsys.comp.mass = abs(x[2])
        interpolate_bnsys!(pf)
        F[1] = (get_value(name1) - params[name1]) / (params[name1] == 0 ? 1 : params[name1])
        F[2] = (get_value(name2) - params[name2]) / (params[name2] == 0 ? 1 : params[name2])
    end
    sol = nlsolve(get_residuals!, [obs_params.masses_init.m1, obs_params.masses_init.m2])
    m1, m2 = abs.(sol.zero)
    if !converged(sol)
        m1, m2 = NaN, NaN
    end
    pf.bnsys.psr.mass, pf.bnsys.comp.mass = m1, m2
    interpolate_bnsys!(pf)
    return (m1 = m1, m2 = m2)
end

function get_value(name, pf)
    if name == "m1"
        value = pf.bnsys.psr.mass
    elseif name == "m2" || name == "M2"
        value = pf.bnsys.comp.mass
    elseif haskey(pf.bnsys.PK_params, Symbol(name))
        value = pf.bnsys.PK_params[Symbol(name)]
    elseif haskey(pf.bnsys.X_params, Symbol(name))
        value = pf.bnsys.X_params[Symbol(name)]
    elseif name == "cosi" || name == "COSI"
        s = pf.bnsys.PK_params[:s]
        value = sqrt(1 - s^2 >= 0 ? 1 - s^2 : 1.0)
    elseif name == "PBDOT"
        s = pf.bnsys.PK_params[:Pbdot]
    elseif name == "GAMMA"
        s = pf.bnsys.PK_params[:gamma]
    end
end

function adjust_m1(params, pf::DEFPhysicalFramework)
    name1, name2 = keys(params)
    pf.bnsys.comp.mass = params["m2"]
    name = name1 == "m2" ? name2 : name1
    function get_residuals!(F, x)
        pf.bnsys.psr.mass = abs(x[1])
        interpolate_bnsys!(pf)
        F[1] = (get_value(name, pf) - params[name]) / (params[name] == 0 ? 1 : params[name])
    end
    sol = nlsolve(get_residuals!, [pf.bnsys.psr.mass])
    m1 = abs.(sol.zero)[1]
    if !converged(sol)
        m1 = NaN
    end
    pf.bnsys.psr.mass = m1
    interpolate_bnsys!(pf)
    return pf
end

function adjust_m1m2(params, pf::DEFPhysicalFramework)
    name1, name2 = keys(params)
    function get_residuals!(F, x)
        pf.bnsys.psr.mass = abs(x[1])
        pf.bnsys.comp.mass = abs(x[2])
        interpolate_bnsys!(pf)
        F[1] = (get_value(name1, pf) - params[name1]) / (params[name1] == 0 ? 1 : params[name1])
        F[2] = (get_value(name2, pf) - params[name2]) / (params[name2] == 0 ? 1 : params[name2])
    end
    sol = nlsolve(get_residuals!, [pf.bnsys.psr.mass, pf.bnsys.comp.mass])
    m1, m2 = abs.(sol.zero)
    if !converged(sol)
        m1, m2 = NaN, NaN
    end
    pf.bnsys.psr.mass, pf.bnsys.comp.mass = m1, m2
    interpolate_bnsys!(pf)
    return pf
end

function adjust_masses(params, pf::DEFPhysicalFramework)
    name1, name2 = keys(params)

    if haskey(params, "m1") && haskey(params, "m2")
        pf.bnsys.psr.mass = params["m1"]
        pf.bnsys.comp.mass = params["m2"]
        interpolate_bnsys!(pf)
    elseif haskey(params, "m1")
        pf.bnsys.psr.mass = params["m1"]
        name = name1 == "m1" ? name2 : name1
        function get_residuals!(F, x)
            pf.bnsys.comp.mass = abs(x[1])
            interpolate_bnsys!(pf)
            F[1] = (get_value(name, pf) - params[name]) / (params[name] == 0 ? 1 : params[name])
        end
        sol = nlsolve(get_residuals!, [pf.bnsys.comp.mass])
        m2 = abs.(sol.zero)[1]
        if !converged(sol)
            m2 = NaN
        end
        pf.bnsys.comp.mass = m2
        interpolate_bnsys!(pf)
    elseif haskey(params, "m2")
        adjust_m1(params, pf)
    else
        adjust_m1m2(params, pf)
    end

    return pf
end


#=
function calculate!(pkf::PKFramework, pf::DEFPhysicalFramework; add_refinement=0)

    pf.theory.alpha0 = 0.0
    pf.theory.beta0  = 0.0
    m1_GR, m2_GR = find_best_masses(pkf.obs_params, pf)
    pkf.grid.params[:chisqr_gr] = get_chisqr(pkf.obs_params, pf)



    if typeof(pkf.test.alpha0) == Float64
        pf.theory.alpha0 = pkf.test.alpha0
    end
    if typeof(pkf.test.beta0) == Float64
        pf.theory.beta0 = pkf.test.beta0
    end
    interpolate_mgrid!(pf)

    key_change_gravity = pkf.test.param1.name == "log10alpha0" || pkf.test.param1.name == "alpha0" || pkf.test.param1.name == "beta0"

    if !haskey(pkf.grid.params, :chisqr_min)
        pkf.grid.params[:chisqr_min] = pkf.gsets.gr_in_chisqr ? pkf.grid.params[:chisqr_gr] : Inf
    end


    params = Dict(pkf.test.param1.name => pkf.test.param1.min, pkf.test.param2.name => pkf.test.param2.min)

    function get_chisqr_local(param1::Float64, param2::Float64)
        name1, name2 = pkf.test.param1.name, pkf.test.param2.name
        params[name1] = param1
        params[name2] = param2
        key_fit_masses = false
        if key_change_gravity == true
            key_fit_masses = true
            if name1 == "log10alpha0"
                pf.theory.alpha0 = -exp10(param1)
            elseif  name1 == "alpha0"
                pf.theory.alpha0 = param1
            elseif name1 == "beta0"
                pf.theory.beta0  = param1
            end
            if name2 == "log10alpha0"
                pf.theory.alpha0 = -exp10(param2)
            elseif  name2 == "alpha0"
                pf.theory.alpha0 = param2
            elseif name2 == "beta0"
                pf.theory.beta0  = param2
            end
            interpolate_mgrid!(pf)
        end
        pf.bnsys.psr.mass = m1_GR
        pf.bnsys.comp.mass = m2_GR
        if key_fit_masses == true
            interpolate_mgrid!(pf)
            find_best_masses(pkf.obs_params, pf)
        else
            adjust_masses(params, pf)
        end
        chisqr = get_chisqr(pkf.obs_params, pf)
        pkf.grid.params[:chisqr_min] = pkf.grid.params[:chisqr_min] < chisqr ? pkf.grid.params[:chisqr_min] : chisqr
        @printf "run %s = %10.6f, %s = %10.6f, χ2 = %10.3f\n" pkf.test.param1.name param1 pkf.test.param2.name param2 chisqr
        return ((:chisqr, :m1, :m2, :k, :gamma, :Pbdot, :r, :s, :h3, :varsigma, :dtheta,  :alphaA, :betaA, :kA),  (chisqr, pf.bnsys.psr.mass, pf.bnsys.comp.mass, pf.bnsys.PK_params.k, pf.bnsys.PK_params.gamma, pf.bnsys.PK_params.Pbdot, pf.bnsys.PK_params.r, pf.bnsys.PK_params.s, pf.bnsys.PK_params.h3, pf.bnsys.PK_params.varsigma, pf.bnsys.PK_params.dtheta, pf.bnsys.psr.alphaA, pf.bnsys.psr.betaA, pf.bnsys.psr.kA) )
    end


    chisqr_contours = pkf.gsets.contours
    delta_chisqr_max = pkf.gsets.delta_chisqr_max
    delta_chisqr_diff = pkf.gsets.delta_chisqr_diff

    function niceplot_cell_selector(i_cell::Int64, j_cell::Int64, grid::SimpleGrid)
        chisqr_min = grid.params[:chisqr_min]
        chisqr_cell = @view grid.value[:chisqr][i_cell:i_cell+1,j_cell:j_cell+1]
        chisqr_cell_min = minimum(chisqr_cell)
        chisqr_cell_max = maximum(chisqr_cell)
        max_chisqr_case = (chisqr_cell_min < chisqr_min + delta_chisqr_max)
        diff_chisqr_case = (chisqr_cell_max - chisqr_cell_min > delta_chisqr_diff)
        contour_chisqr_case = any(chisqr_cell_min .< chisqr_min .+ chisqr_contours .< chisqr_cell_max)
        return max_chisqr_case && diff_chisqr_case || contour_chisqr_case
    end

    function contour_cell_selector(i_cell::Int64, j_cell::Int64, grid::SimpleGrid)
        chisqr_min = grid.params[:chisqr_min]
        chisqr_cell = @view grid.value[:chisqr][i_cell:i_cell+1,j_cell:j_cell+1]
        chisqr_cell_min = minimum(chisqr_cell)
        chisqr_cell_max = maximum(chisqr_cell)
#        min_chisqr_case = chisqr_cell_min <= chisqr_min < chisqr_cell_max
        contour_chisqr_case = any(chisqr_cell_min .< chisqr_min .+ chisqr_contours .< chisqr_cell_max)
        return contour_chisqr_case
    end

    function contour_min_cell_selector(i_cell::Int64, j_cell::Int64, grid::SimpleGrid)
        chisqr_min = grid.params[:chisqr_min]
        chisqr_cell = @view grid.value[:chisqr][i_cell:i_cell+1,j_cell:j_cell+1]
        chisqr_cell_min = minimum(chisqr_cell)
        chisqr_cell_max = maximum(chisqr_cell)
        min_chisqr_case = chisqr_cell_min <= chisqr_min < chisqr_cell_max
        contour_chisqr_case = any(chisqr_cell_min .< chisqr_min .+ chisqr_contours .< chisqr_cell_max)
        return contour_chisqr_case || min_chisqr_case
    end

    function massmass_cell_selector(i_cell::Int64, j_cell::Int64, grid::SimpleGrid)
        PK_contour_case = false
        for PK in keys(pkf.obs_params.PK)
            if pkf.obs_params.PK[PK].err != 0.0
                PK_cell = @view grid.value[PK][i_cell:i_cell+1,j_cell:j_cell+1]
                PK_values = [pkf.obs_params.PK[PK].val - pkf.obs_params.PK[PK].err, pkf.obs_params.PK[PK].val, pkf.obs_params.PK[PK].val + pkf.obs_params.PK[PK].err]
                PK_cell_min = minimum(x -> isnan(x) ? +Inf : x, PK_cell)
                PK_cell_max = maximum(x -> isnan(x) ? -Inf : x, PK_cell)
                PK_contour_case = PK_contour_case || any(x -> PK_cell_min < x < PK_cell_max, PK_values)
                if any(isnan, PK_cell)
                    PK_contour_case = PK_contour_case || any(x -> PK_cell_min < x, PK_values) || any(x -> x < PK_cell_max, PK_values)
                end
                #println("$PK $(PK_contour_case) $(PK_cell_min) $(pkf.obs_params.PK[PK].val) $(PK_cell_max)")
            end
        end
        return PK_contour_case || contour_cell_selector(i_cell, j_cell, grid)
    end

    if pkf.gsets.refinement_type == "nice"
        sell_selector = niceplot_cell_selector
    elseif pkf.gsets.refinement_type == "contour"
        sell_selector = contour_cell_selector
    elseif pkf.gsets.refinement_type == "contour+min"
        sell_selector = contour_min_cell_selector
    elseif pkf.gsets.refinement_type == "massmass"
        sell_selector = massmass_cell_selector
    end

    function calculate_params!(grid::SimpleGrid)
        if haskey(grid.params, :chisqr_min)
            grid.params[:chisqr_min] = min(minimum(grid.value[:chisqr]), grid.params[:chisqr_min])
        else
            grid.params[:chisqr_min] = minimum(grid.value[:chisqr])
        end
        for PK in keys(pkf.obs_params.PK)
            if pkf.obs_params.PK[PK].err != 0.0
                grid.params[PK] = minimum(abs.(grid.value[PK] .- pkf.obs_params.PK[PK].val))
            end
        end
        return nothing
    end

    if add_refinement == 0
        precalculate_Grid(pkf.grid, get_chisqr_local, calculate_params!)
        for i in 1:pkf.gsets.N_refinement
            pkf.grid = refine_Grid(pkf.grid, get_chisqr_local, sell_selector, calculate_params!)
        end
    else
        for i in 1:add_refinement
            pkf.grid = refine_Grid(pkf.grid, get_chisqr_local, sell_selector, calculate_params!)
        end
        pkf.gsets = GridSetttings(pkf.gsets.N_refinement + add_refinement, pkf.gsets.CL, pkf.gsets.contours, pkf.gsets.refinement_type, pkf.gsets.delta_chisqr_max, pkf.gsets.delta_chisqr_diff, pkf.gsets.gr_in_chisqr)
    end

    return pkf, pf
end
=#

#--------------------------------------------------------------------------------------------------------------
# PK kernel

struct PKKernel <: AbstractKernel
    physics::DEFPhysicalFramework
    obs_params::ObsParams

end

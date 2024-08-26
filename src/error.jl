struct BayesPrecision{M<:Mixture}
    mix::M
    normalized::Bool
end

function (bp::BayesPrecision)(x)
    d, w = distributions(bp.mix), weights(bp.mix)
    p, t = 0.0, 0.0
    for i in eachindex(w, d)
        l = w[i] * densityof(d[i], x)
        p = max(p, l)
        t += l
    end
    if bp.normalized
        return p / t
    else
        return p
    end
end

function error_montecarlo(rng::AbstractRNG, mix::Mixture; nb_samples)
    bp = BayesPrecision(mix, true)
    precision_samples = fill(NaN, nb_samples)
    for s in 1:nb_samples
        x = rand(rng, mix)
        precision_samples[s] = bp(x)
    end
    return MonteCarloValue(1 .- precision_samples)
end

function error_quadrature_1d(mix::Mixture; rtol, bound=100, kwargs...)
    bp = BayesPrecision(mix, false)
    precision, quad_error = QuadGK.quadgk(bp, -bound, bound; kwargs...)
    return IntervalValue(1 - precision, quad_error)
end

function error_quadrature_nd(mix::Mixture; rtol, bound=100, kwargs...)
    bp = BayesPrecision(mix, false)
    precision, cub_error = HCubature.hcubature(
        bp, -fill(bound, length(mix)), +fill(bound, length(mix)); kwargs...
    )
    return IntervalValue(1 - precision, cub_error)
end

function error_quadrature(mix::Mixture; rtol, kwargs...)
    if length(mix) == 1
        return error_quadrature_1d(mix; rtol, kwargs...)
    else
        return error_quadrature_nd(mix; rtol, kwargs...)
    end
end

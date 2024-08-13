degree_matrix(A::SparseMatrixCSC) = Diagonal(length.(nzrange.(Ref(A), axes(A, 2))))

function random_walk(A)
    D = degree_matrix(A)
    return inv(D + I) * (A + I)
end

sumdropdims(f, x; dims) = dropdims(sum(f, x; dims); dims)
sumdropdims(x; dims) = dropdims(sum(x; dims); dims)

function community_walk_probabilities(rng::AbstractRNG, sbm::SBM; nb_layers, nb_graphs)
    (; sizes) = sbm
    inds(c) = community_range(sbm, c)
    G = nb_graphs
    C = nb_communities(sbm)
    L = nb_layers
    N = sum(sizes)

    s = [fill(NaN, G, community_size(sbm, c0)) for l in 1:L, c0 in 1:C, c1 in 1:C]
    t = [fill(NaN, G, community_size(sbm, c0)) for l in 1:L, c0 in 1:C, c1 in 1:C]

    R = Matrix{Float64}(undef, N, N)
    R_scratch = similar(R)

    for g in 1:G
        A = rand(rng, sbm)
        W = random_walk(A)
        R .= I(N)
        for l in 1:L
            mul!(R_scratch, R, W)
            copyto!(R, R_scratch)
            R_summed_by_blocks = [sumdropdims(view(R, :, inds(c1)); dims=2) for c1 in 1:C]
            R2_summed_by_blocks = [
                sumdropdims(abs2, view(R, :, inds(c1)); dims=2) for c1 in 1:C
            ]
            for c0 in 1:C, c1 in 1:C
                s[l, c0, c1][g, :] .= view(R_summed_by_blocks[c1], inds(c0))
                t[l, c0, c1][g, :] .= view(R2_summed_by_blocks[c1], inds(c0))
            end
        end
    end
    return s, t
end

function random_walk_mixtures(rng::AbstractRNG, csbm::CSBM; nb_layers, nb_graphs)
    (; sbm, features) = csbm
    L = nb_layers
    C = nb_communities(sbm)
    μ0, Σ0 = mean.(features), cov.(features)
    s, t = community_walk_probabilities(rng, sbm; nb_layers, nb_graphs)

    mixtures = Matrix{Mixture}(undef, L + 1, C)
    for c0 in 1:C
        mixtures[1, c0] = Mixture([features[c0]], [1.0])
        for l in 1:L
            μ = sum(vec(s[l, c0, c1]) .* Ref(μ0[c1]) for c1 in 1:C)
            Σ = sum(vec(t[l, c0, c1]) .* Ref(Σ0[c1]) for c1 in 1:C)
            mixtures[l + 1, c0] = Mixture(MultivariateNormal.(μ, Σ))
        end
    end
    return mixtures
end

function random_walk_errors(
    rng::AbstractRNG, csbm::CSBM; nb_layers, nb_trajectories, nb_graphs, nb_samples
)
    (; sbm) = csbm
    (; sizes) = sbm
    errors_mat = fill(NaN, nb_layers + 1, nb_trajectories)
    tforeach(1:nb_trajectories) do t
        mixtures = random_walk_mixtures(rng, csbm; nb_layers, nb_graphs)
        for l in 0:nb_layers
            to_classify = Mixture(mixtures[l + 1, :], sizes ./ sum(sizes))
            errors_mat[l + 1, t] = pmean(error_montecarlo(rng, to_classify; nb_samples))
        end
    end
    return Particles.(Vector.(eachrow(errors_mat)))
end

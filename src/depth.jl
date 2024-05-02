function misclassification_probability_evolution(
    rng::AbstractRNG,
    graph::AbstractRandomGraph,
    features::Vector{<:MultivariateDistribution};
    max_layers::Integer,
    resample_graph::Bool,
)
    dataset = tmap(1:2) do _
        embeddings(rng, graph, features; layers=max_layers, resample_graph, return_history=true)
    end
    _, history_train = dataset[1]
    _, history_test = dataset[2]

    probas = Vector{Float64}(undef, length(history_train))
    tforeach(eachindex(history_train, history_test)) do l
        H_split_train = split_by_community(history_train[l], graph)
        H_split_test = split_by_community(history_test[l], graph)
        probas[l] = misclassification_probability(H_split_train, H_split_test)
    end

    return probas
end